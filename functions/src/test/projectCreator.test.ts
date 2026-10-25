import { createProjectForRepo } from '../lib/projectCreator';
import { extractRepoInfo } from '../lib/repoInfo';
import { autoProjectId, dayKey } from '../lib/linkStore';
import { CONFIG_ON, OWNER_UID, repoPayload, seedAdmin } from './helpers/fixtures';
import { makeTestDb } from './helpers/testDb';

// Contro l'emulatore le transazioni concorrenti (ripetute da Firestore in caso di conflitto) possono superare i 5 secondi predefiniti.
jest.setTimeout(30_000);

const t = makeTestDb();
const { db } = t;
const NOW = new Date('2026-10-25T10:00:00Z');
const info = (over: Record<string, unknown> = {}) => extractRepoInfo({ repository: repoPayload(over) })!;

beforeEach(async () => {
  await t.reset();
  await seedAdmin(db);
});

describe(`createProjectForRepo (${t.kind})`, () => {
  it('creates the project with the same fields as crea-progetto, the client access entry, the registry entry and the counter', async () => {
    const r = await createProjectForRepo(db, info(), CONFIG_ON, 'github-app', NOW);
    expect(r.result).toBe('creato');
    if (r.result !== 'creato') return;

    const project = (await db.collection('projects').doc(r.projectId).get()).data()!;
    expect(r.projectId).toBe(autoProjectId(1001));
    expect(project).toMatchObject({
      name: 'prova-x',
      description: 'Repository di prova',
      githubUrl: 'https://github.com/sbotz17/prova-x',
      clientCode: r.clientCode,
      ownerId: OWNER_UID,
      nextTaskNumber: 1,
      githubRepoId: 1001,
      autoCreated: true,
      autoCreatedSource: 'github-app',
    });
    expect(project['createdAt']).toBeDefined();
    expect(project['updatedAt']).toBeDefined();
    expect(r.clientCode).toMatch(/^[A-HJ-NP-Z2-9]{6}$/);

    const access = (await db.collection('clientAccess').doc(r.clientCode).get()).data()!;
    expect(access).toMatchObject({ projectId: r.projectId, ownerId: OWNER_UID });

    const registry = (await db.collection('githubRepos').doc('1001').get()).data()!;
    expect(registry).toMatchObject({ repoId: 1001, projectId: r.projectId, state: 'tracked', source: 'auto' });

    const counter = (await db.collection('githubCollegamento').doc(`giorno-${dayKey(NOW)}`).get()).data()!;
    expect(counter['progettiCreati']).toBe(1);
  });

  it('is idempotent: the same event twice creates ONE project and ONE client code', async () => {
    const a = await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW);
    const b = await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW);
    expect(a.result).toBe('creato');
    expect(b).toEqual({ result: 'esistente', projectId: autoProjectId(1001) });
    expect((await db.collection('projects').get()).size).toBe(1);
    expect((await db.collection('clientAccess').get()).size).toBe(1);
    const counter = (await db.collection('githubCollegamento').doc(`giorno-${dayKey(NOW)}`).get()).data()!;
    expect(counter['progettiCreati']).toBe(1);
  });

  it('concurrent events for the same new repository create exactly one project', async () => {
    const results = await Promise.all(Array.from({ length: 8 }, () => createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW)));
    expect(results.filter((r) => r.result === 'creato')).toHaveLength(1);
    expect(results.filter((r) => r.result === 'esistente')).toHaveLength(7);
    expect((await db.collection('projects').get()).size).toBe(1);
    expect((await db.collection('clientAccess').get()).size).toBe(1);
    const counter = (await db.collection('githubCollegamento').doc(`giorno-${dayKey(NOW)}`).get()).data()!;
    expect(counter['progettiCreati']).toBe(1);
  });

  it('does not resurrect a deleted project: the registry turns the repository into "excluded"', async () => {
    const first = await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW);
    if (first.result !== 'creato') throw new Error('atteso creato');
    // L'app elimina il progetto (e la voce di accesso cliente).
    await db.collection('projects').doc(first.projectId).delete();
    await db.collection('clientAccess').doc(first.clientCode).delete();

    const again = await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW);
    expect(again).toEqual({ result: 'escluso', reason: 'progetto_eliminato' });
    const third = await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW);
    expect(third).toEqual({ result: 'escluso', reason: 'progetto_eliminato' });
    expect((await db.collection('projects').get()).size).toBe(0);
    expect((await db.collection('githubRepos').doc('1001').get()).get('state')).toBe('excluded');
  });

  it('an administrator-excluded repository is never created, with its own reason', async () => {
    await db.collection('githubRepos').doc('1001').set({ repoId: 1001, state: 'excluded', reason: 'esclusione_manuale' });
    expect(await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW)).toEqual({ result: 'escluso', reason: 'repository_escluso' });
    expect((await db.collection('projects').get()).size).toBe(0);
  });

  it('an unrecognised registry state is treated as excluded (corrupted data never creates a project)', async () => {
    await db.collection('githubRepos').doc('1001').set({ repoId: 1001, state: 'boh' });
    expect(await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW)).toEqual({ result: 'escluso', reason: 'repository_escluso' });
    await db.collection('githubRepos').doc('1001').set({ repoId: 1001 });
    expect(await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW)).toEqual({ result: 'escluso', reason: 'repository_escluso' });
    expect((await db.collection('projects').get()).size).toBe(0);
  });

  it('a readmitted repository is created again and becomes tracked', async () => {
    await db.collection('githubRepos').doc('1001').set({ repoId: 1001, state: 'readmitted', createdAt: 'x' });
    const r = await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW);
    expect(r.result).toBe('creato');
    const registry = (await db.collection('githubRepos').doc('1001').get()).data()!;
    expect(registry['state']).toBe('tracked');
    expect(registry['createdAt']).toBe('x'); // non riscritto
  });

  it('stops at the daily cap, counts per Italian day, and resumes the next day', async () => {
    const cfg = { ...CONFIG_ON, maxNewProjectsPerDay: 2 };
    expect((await createProjectForRepo(db, info({ id: 1 }), cfg, 'webhook', NOW)).result).toBe('creato');
    expect((await createProjectForRepo(db, info({ id: 2 }), cfg, 'webhook', NOW)).result).toBe('creato');
    expect(await createProjectForRepo(db, info({ id: 3 }), cfg, 'webhook', NOW)).toEqual({ result: 'limite_giornaliero' });
    expect((await db.collection('projects').get()).size).toBe(2);
    // un attimo prima della mezzanotte italiana e' ancora lo stesso giorno
    expect(await createProjectForRepo(db, info({ id: 3 }), cfg, 'webhook', new Date('2026-10-25T21:30:00Z'))).toEqual({ result: 'limite_giornaliero' });
    // il giorno dopo (ora italiana) si riparte
    expect((await createProjectForRepo(db, info({ id: 3 }), cfg, 'webhook', new Date('2026-10-25T23:30:00Z'))).result).toBe('creato');
  });

  it('the daily cap holds under concurrency', async () => {
    const cfg = { ...CONFIG_ON, maxNewProjectsPerDay: 3 };
    const results = await Promise.all(Array.from({ length: 10 }, (_, i) => createProjectForRepo(db, info({ id: 100 + i }), cfg, 'webhook', NOW)));
    expect(results.filter((r) => r.result === 'creato')).toHaveLength(3);
    expect(results.filter((r) => r.result === 'limite_giornaliero')).toHaveLength(7);
    expect((await db.collection('projects').get()).size).toBe(3);
  });

  it('treats a corrupted counter as "cap reached" (fail closed)', async () => {
    await db.collection('githubCollegamento').doc(`giorno-${dayKey(NOW)}`).set({ progettiCreati: 'molti' });
    expect(await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW)).toEqual({ result: 'limite_giornaliero' });
    expect((await db.collection('projects').get()).size).toBe(0);
  });

  it('does not create anything when the configured owner is not an admin or does not exist', async () => {
    await db.collection('users').doc('uid-cliente').set({ email: 'c@example.com', role: 'client' });
    expect(await createProjectForRepo(db, info(), { ...CONFIG_ON, ownerUid: 'uid-cliente' }, 'webhook', NOW)).toEqual({ result: 'proprietario_config_non_valido' });
    expect(await createProjectForRepo(db, info(), { ...CONFIG_ON, ownerUid: 'uid-inesistente' }, 'webhook', NOW)).toEqual({ result: 'proprietario_config_non_valido' });
    expect((await db.collection('projects').get()).size).toBe(0);
    expect((await db.collection('clientAccess').get()).size).toBe(0);
  });

  it('picks a free client code when the first candidates are already taken', async () => {
    // Il generatore restituisce 5 codici: 'AAAAAA', 'BBBBBB', ...; i primi due sono gia' usati.
    let call = 0;
    const pick = () => Math.floor(call++ / 6); // 6 estrazioni per codice -> codice i-esimo = lettera i
    await db.collection('clientAccess').doc('AAAAAA').set({ projectId: 'altro' });
    await db.collection('clientAccess').doc('BBBBBB').set({ projectId: 'altro' });
    const r = await createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW, pick);
    expect(r).toMatchObject({ result: 'creato', clientCode: 'CCCCCC' });
    // le voci di accesso degli altri progetti non sono state toccate
    expect((await db.collection('clientAccess').doc('AAAAAA').get()).get('projectId')).toBe('altro');
  });

  it('never overwrites an existing client access entry (all candidates taken -> error, nothing written)', async () => {
    const pick = () => 0; // tutti i codici candidati sono 'AAAAAA'
    await db.collection('clientAccess').doc('AAAAAA').set({ projectId: 'altro' });
    await expect(createProjectForRepo(db, info(), CONFIG_ON, 'webhook', NOW, pick)).rejects.toThrow();
    expect((await db.collection('projects').get()).size).toBe(0);
    expect((await db.collection('clientAccess').doc('AAAAAA').get()).get('projectId')).toBe('altro');
  });
});
