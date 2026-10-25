/**
 * Firestore "finto", in memoria, per i test che girano ovunque (anche in CI, senza emulatore).
 * Implementa solo cio' che usa il codice del collegamento: collection/doc/get/set(merge)/update/delete,
 * select().get(), where(campo,'==',valore).limit().get(), runTransaction con get/getAll/set/update/create.
 *
 * Le transazioni hanno concorrenza ottimistica con ripetizione (come Firestore): se un documento letto cambia prima
 * del commit, la funzione della transazione viene rieseguita. Cosi' i test di concorrenza (due eventi insieme) sono significativi.
 * Gli stessi test girano anche contro l'emulatore vero (vedi testDb.ts).
 */
type Data = Record<string, unknown>;

interface Stored {
  data: Data;
  version: number;
}

function resolveSentinels(existing: Data, incoming: Data): Data {
  const out: Data = {};
  for (const [k, v] of Object.entries(incoming)) {
    const name = (v as { constructor?: { name?: string } } | null)?.constructor?.name ?? '';
    if (v && typeof v === 'object' && name === 'ServerTimestampTransform') out[k] = new Date();
    else if (v && typeof v === 'object' && name === 'ArrayUnionTransform') {
      const current = Array.isArray(existing[k]) ? (existing[k] as unknown[]) : [];
      const toAdd = (v as unknown as { elements: unknown[] }).elements;
      const merged = [...current];
      for (const el of toAdd) if (!merged.some((m) => JSON.stringify(m) === JSON.stringify(el))) merged.push(el);
      out[k] = merged;
    } else if (v && typeof v === 'object' && name === 'NumericIncrementTransform') {
      const base = typeof existing[k] === 'number' ? (existing[k] as number) : 0;
      out[k] = base + (v as unknown as { operand: number }).operand;
    } else out[k] = v;
  }
  return out;
}

export class FakeSnapshot {
  constructor(
    readonly ref: FakeDocRef,
    private readonly stored: Stored | undefined
  ) {}
  get exists(): boolean {
    return this.stored !== undefined;
  }
  get id(): string {
    return this.ref.id;
  }
  data(): Data | undefined {
    return this.stored ? structuredCloneSafe(this.stored.data) : undefined;
  }
  get(field: string): unknown {
    return this.stored ? structuredCloneSafe(this.stored.data)[field] : undefined;
  }
}

/** Copia profonda che conserva Date e oggetti non semplici (es. Timestamp) senza romperli. */
function structuredCloneSafe(data: Data): Data {
  const out: Data = {};
  for (const [k, v] of Object.entries(data)) {
    if (Array.isArray(v)) out[k] = v.map((x) => (x && typeof x === 'object' && x.constructor === Object ? structuredCloneSafe(x as Data) : x));
    else if (v && typeof v === 'object' && v.constructor === Object) out[k] = structuredCloneSafe(v as Data);
    else out[k] = v;
  }
  return out;
}

export class FakeDocRef {
  constructor(
    private readonly db: FakeFirestore,
    readonly path: string
  ) {}
  get id(): string {
    return this.path.split('/').pop() as string;
  }
  collection(name: string): FakeCollectionRef {
    return new FakeCollectionRef(this.db, `${this.path}/${name}`);
  }
  async get(): Promise<FakeSnapshot> {
    await Promise.resolve();
    return this.db.snapshot(this);
  }
  async set(data: Data, options?: { merge?: boolean }): Promise<void> {
    this.db.applySet(this.path, data, options);
  }
  async update(data: Data): Promise<void> {
    this.db.applyUpdate(this.path, data);
  }
  async delete(): Promise<void> {
    this.db.applyDelete(this.path);
  }
}

class FakeQuery {
  constructor(
    protected readonly db: FakeFirestore,
    protected readonly collectionPath: string,
    private readonly filters: Array<[string, unknown]> = [],
    private readonly max: number | null = null
  ) {}
  select(..._fields: string[]): FakeQuery {
    return this;
  }
  where(field: string, op: string, value: unknown): FakeQuery {
    if (op !== '==') throw new Error('fake: solo ==');
    return new FakeQuery(this.db, this.collectionPath, [...this.filters, [field, value]], this.max);
  }
  limit(n: number): FakeQuery {
    return new FakeQuery(this.db, this.collectionPath, this.filters, n);
  }
  async get(): Promise<{ docs: FakeSnapshot[]; empty: boolean; size: number }> {
    await Promise.resolve();
    let docs = this.db
      .childPaths(this.collectionPath)
      .map((p) => this.db.snapshot(new FakeDocRef(this.db, p)))
      .filter((s) => this.filters.every(([f, v]) => s.get(f) === v));
    if (this.max !== null) docs = docs.slice(0, this.max);
    return { docs, empty: docs.length === 0, size: docs.length };
  }
}

export class FakeCollectionRef extends FakeQuery {
  doc(id?: string): FakeDocRef {
    return new FakeDocRef(this.db, `${this.collectionPath}/${id ?? this.db.autoId()}`);
  }
}

class FakeTransaction {
  readonly reads = new Map<string, number>();
  readonly writes: Array<() => void> = [];
  constructor(private readonly db: FakeFirestore) {}

  private async readOne(ref: FakeDocRef): Promise<FakeSnapshot> {
    await Promise.resolve();
    await Promise.resolve();
    this.reads.set(ref.path, this.db.versionOf(ref.path));
    return this.db.snapshot(ref);
  }
  async get(ref: FakeDocRef): Promise<FakeSnapshot> {
    return this.readOne(ref);
  }
  async getAll(...refs: FakeDocRef[]): Promise<FakeSnapshot[]> {
    return Promise.all(refs.map((r) => this.readOne(r)));
  }
  set(ref: FakeDocRef, data: Data, options?: { merge?: boolean }): this {
    this.writes.push(() => this.db.applySet(ref.path, data, options));
    return this;
  }
  update(ref: FakeDocRef, data: Data): this {
    this.writes.push(() => this.db.applyUpdate(ref.path, data));
    return this;
  }
  create(ref: FakeDocRef, data: Data): this {
    this.writes.push(() => {
      if (this.db.snapshot(ref).exists) throw new Error('ALREADY_EXISTS');
      this.db.applySet(ref.path, data);
    });
    return this;
  }
}

export class FakeFirestore {
  private readonly docs = new Map<string, Stored>();
  private counter = 0;

  autoId(): string {
    this.counter += 1;
    return `auto${this.counter}`;
  }
  collection(name: string): FakeCollectionRef {
    return new FakeCollectionRef(this, name);
  }
  doc(path: string): FakeDocRef {
    return new FakeDocRef(this, path);
  }
  snapshot(ref: FakeDocRef): FakeSnapshot {
    return new FakeSnapshot(ref, this.docs.get(ref.path));
  }
  versionOf(path: string): number {
    return this.docs.get(path)?.version ?? this.tombstones.get(path) ?? 0;
  }
  childPaths(collectionPath: string): string[] {
    const depth = collectionPath.split('/').length + 1;
    return [...this.docs.keys()].filter((p) => p.startsWith(`${collectionPath}/`) && p.split('/').length === depth);
  }
  applySet(path: string, data: Data, options?: { merge?: boolean }): void {
    const prev = this.docs.get(path);
    const base = options?.merge && prev ? prev.data : {};
    const next = { ...base, ...resolveSentinels(base, data) };
    this.docs.set(path, { data: next, version: ++this.clock });
  }
  applyUpdate(path: string, data: Data): void {
    const prev = this.docs.get(path);
    if (!prev) throw new Error('NOT_FOUND');
    this.docs.set(path, { data: { ...prev.data, ...resolveSentinels(prev.data, data) }, version: ++this.clock });
  }
  applyDelete(path: string): void {
    this.docs.delete(path);
    // Un documento cancellato ha una versione propria: chi lo aveva letto deve accorgersene (concorrenza ottimistica).
    this.tombstones.set(path, ++this.clock);
  }
  private clock = 0;
  private readonly tombstones = new Map<string, number>();

  async runTransaction<T>(fn: (tx: FakeTransaction) => Promise<T>): Promise<T> {
    for (let attempt = 0; attempt < 10; attempt++) {
      const tx = new FakeTransaction(this);
      const result = await fn(tx);
      // Commit atomico (sincrono): se qualcosa di letto e' cambiato, si riprova.
      const changed = [...tx.reads.entries()].some(([path, v]) => this.versionOf(path) !== v);
      if (changed) continue;
      for (const w of tx.writes) w();
      return result;
    }
    throw new Error('fake: troppi tentativi di transazione');
  }

  /** Solo test: svuota tutto. */
  clear(): void {
    this.docs.clear();
    this.tombstones.clear();
  }

  /** Solo test: contenuto di una collezione (percorso -> dati). */
  dump(collectionPath: string): Record<string, Data> {
    const out: Record<string, Data> = {};
    for (const p of this.childPaths(collectionPath)) out[p.split('/').pop() as string] = this.docs.get(p)!.data;
    return out;
  }
}
