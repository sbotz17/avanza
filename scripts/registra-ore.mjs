// Usato dalla squadra (workflow "Registra ore squadra") per registrare membri e ore.
// Usa le credenziali del service account (firebase-admin), quindi non passa dalle regole.
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(path.resolve('functions/package.json'));
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const env = (k, d = '') => (process.env[k] ?? d).trim();
const action = env('ACTION');
const repoUrl = `https://github.com/${env('GITHUB_REPOSITORY')}`.toLowerCase();

if (getApps().length === 0) initializeApp({ projectId: 'avanza-b62d7' });
const db = getFirestore();

const num = (s, label) => {
  const n = Number(s.replace(',', '.'));
  if (!Number.isFinite(n) || n < 0) throw new Error(`Valore non valido per ${label}: "${s}"`);
  return n;
};

async function findProject() {
  const pid = env('PROJECT_ID');
  if (pid) {
    const doc = await db.collection('projects').doc(pid).get();
    if (!doc.exists) throw new Error(`Progetto ${pid} non trovato.`);
    return doc;
  }
  // Il progetto si sceglie dall'indirizzo GitHub passato (github_url) oppure, se
  // assente, da quello del repository in cui gira il workflow.
  const wanted = (env('GITHUB_URL') || repoUrl).toLowerCase().replace(/\/$/, '');
  const snap = await db.collection('projects').get();
  const matches = snap.docs.filter(
    (d) => String(d.get('githubUrl') ?? '').toLowerCase().replace(/\/$/, '') === wanted,
  );
  if (matches.length === 0) throw new Error(`Nessun progetto con githubUrl ${wanted}.`);
  if (matches.length > 1) {
    const list = matches.map((d) => `${d.id} (${d.get('name')})`).join(', ');
    throw new Error(`Piu' progetti con lo stesso indirizzo GitHub: ${list}. Indica project_id.`);
  }
  return matches[0];
}

async function findMember(ownerId, name) {
  const snap = await db.collection('teamMembers').where('ownerId', '==', ownerId).get();
  return snap.docs.find((d) => String(d.get('name')).toLowerCase() === name.toLowerCase()) ?? null;
}

async function upsertMember() {
  const project = await findProject();
  const ownerId = project.get('ownerId');
  const name = env('MEMBER');
  if (!name) throw new Error('Indica member.');
  const data = {
    ownerId,
    name,
    kind: env('KIND', 'agent'),
    role: env('ROLE'),
    costRate: num(env('COST_RATE', '0'), 'cost_rate'),
    billRate: num(env('BILL_RATE', '0'), 'bill_rate'),
    active: true,
  };
  const existing = await findMember(ownerId, name);
  if (existing) {
    await existing.ref.update(data);
    console.log(`Membro aggiornato: ${name}`);
  } else {
    await db.collection('teamMembers').add({ ...data, createdAt: Timestamp.now() });
    console.log(`Membro creato: ${name}`);
  }
}

async function addHours() {
  const project = await findProject();
  const ownerId = project.get('ownerId');
  const taskCode = env('TASK_CODE');
  const phase = env('PHASE');
  const hours = num(env('HOURS'), 'hours');
  if (!taskCode || !phase || hours <= 0) throw new Error('Servono task_code, phase e hours > 0.');

  const member = await findMember(ownerId, env('MEMBER'));
  if (!member) throw new Error(`Membro "${env('MEMBER')}" non presente nella squadra.`);

  const tasks = await project.ref.collection('tasks').where('taskCode', '==', taskCode).limit(1).get();
  if (tasks.empty) throw new Error(`Task ${taskCode} non trovato nel progetto.`);
  const task = tasks.docs[0];

  const entryRef = project.ref.collection('timeEntries').doc();
  const batch = db.batch();
  batch.set(entryRef, {
    taskId: task.id,
    taskCode,
    memberId: member.id,
    memberName: member.get('name'),
    phase,
    hours,
    costRate: member.get('costRate') ?? 0,
    billRate: member.get('billRate') ?? 0,
    date: Timestamp.now(),
    note: env('NOTE'),
    source: 'squad',
  });
  batch.set(
    project.ref.collection('taskCosts').doc(task.id),
    { actualHours: FieldValue.increment(hours) },
    { merge: true },
  );
  await batch.commit();
  console.log(`Registrate ${hours}h di ${member.get('name')} su ${taskCode} (${phase}).`);
}

// Crea task nel progetto del repository, in blocco, per registrare lavoro gia' fatto.
// Input: TASKS_JSON = [{title, description, status, phases:{Analisi:'done',...}, notes:[{type,text}]}].
// Non duplica: salta i titoli gia' presenti. Le ore restano a zero (si dichiarano a parte).
async function importaTask() {
  const items = JSON.parse(env('TASKS_JSON'));
  const project = await findProject();
  const existing = await project.ref.collection('tasks').get();
  const titles = new Set(existing.docs.map((d) => d.get('title')));
  const PH = ['Analisi', 'Database', 'Backend', 'Design', 'Frontend', 'Test', 'Validazione'];
  const LABEL = { done: 'Completato', active: 'In corso', pending: 'In attesa', skip: 'Non necessaria', blocked: 'Bloccato' };
  const codici = [];
  let created = 0;
  for (const [i, it] of items.entries()) {
    if (titles.has(it.title)) continue;
    await db.runTransaction(async (tx) => {
      const ps = await tx.get(project.ref);
      const n = ps.get('nextTaskNumber') ?? 1;
      const taskRef = project.ref.collection('tasks').doc();
      const now = Timestamp.now();
      tx.set(taskRef, {
        title: it.title,
        description: it.description ?? '',
        clientRequest: it.clientRequest ?? '',
        status: it.status ?? 'backlog',
        phases: PH.map((name) => {
          const st = it.phases?.[name] ?? 'pending';
          return { name, status: st, label: LABEL[st] ?? st };
        }),
        notes: it.notes ?? [],
        order: existing.size + i,
        taskCode: `T-${n}`,
        taskNumber: n,
        createdAt: now,
        updatedAt: now,
      });
      tx.set(project.ref.collection('taskCosts').doc(taskRef.id), { estimatedHours: 0, actualHours: 0, hourlyRate: 0 });
      tx.update(project.ref, { nextTaskNumber: n + 1, updatedAt: now });
      codici.push(`T-${n} ${it.title}`);
    });
    created++;
  }
  console.log(`Task creati: ${created} (gia' presenti: ${items.length - created}).`);
  for (const c of codici) console.log(`  ${c}`);
}

// Sola lettura: elenca i progetti con proprietario, codice cliente e task.
async function stato() {
  const projects = await db.collection('projects').get();
  console.log(`Progetti: ${projects.size}`);
  for (const p of projects.docs) {
    const tasks = await p.ref.collection('tasks').get();
    const codes = tasks.docs.map((t) => `${t.get('taskCode') || '-'}:${t.get('status')}`).join(', ');
    console.log(`- ${p.get('name')} (${p.id}) owner=${p.get('ownerId')} url=${p.get('githubUrl')} task=${tasks.size}${codes ? ` [${codes}]` : ''}`);
  }
  const users = await db.collection('users').get();
  console.log(`Utenti con ruolo: ${users.size}`);
  for (const u of users.docs) console.log(`- ${u.id} ${u.get('email')} ruolo=${u.get('role')}`);
}

// Assegna il ruolo admin a un utente (per email). Il ruolo si assegna solo da qui o
// dalla console: le regole Firestore impediscono ai client di auto-promuoversi.
async function setAdmin(email) {
  if (!email) throw new Error('Indica email.');
  const user = await getAuth().getUserByEmail(email);
  await db.collection('users').doc(user.uid).set(
    { email: user.email ?? email, role: 'admin', createdAt: Timestamp.now() },
    { merge: true },
  );
  console.log(`Ruolo admin assegnato a ${user.uid}.`);
}

// Crea un progetto reale per il proprietario indicato (email), con il suo codice
// cliente e il documento clientAccess. Non crea duplicati: se esiste gia' un progetto
// dello stesso proprietario con lo stesso indirizzo GitHub, non fa nulla.
async function creaProgetto() {
  const email = env('EMAIL');
  const name = env('PROJECT_NAME');
  const githubUrl = env('GITHUB_URL');
  if (!email || !name || !githubUrl) throw new Error('Servono email, project_name e github_url.');
  const owner = await getAuth().getUserByEmail(email);
  await setAdmin(email);
  const norm = (u) => u.toLowerCase().replace(/\/$/, '');
  const existing = await db.collection('projects').where('ownerId', '==', owner.uid).get();
  const dup = existing.docs.find((d) => norm(String(d.get('githubUrl') ?? '')) === norm(githubUrl));
  if (dup) {
    console.log(`Progetto gia' presente (${dup.id}), nessuna modifica. Codice cliente: ${dup.get('clientCode')}`);
    return;
  }
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  const now = Timestamp.now();
  const ref = db.collection('projects').doc();
  const batch = db.batch();
  batch.set(ref, {
    name,
    description: env('PROJECT_DESCRIPTION'),
    githubUrl,
    clientCode: code,
    ownerId: owner.uid,
    nextTaskNumber: 1,
    createdAt: now,
    updatedAt: now,
  });
  batch.set(db.collection('clientAccess').doc(code), { projectId: ref.id, ownerId: owner.uid, createdAt: now });
  await batch.commit();
  console.log(`Progetto creato: ${name} (${ref.id}). Codice cliente: ${code}`);
}

// Elimina SOLO il progetto di prova del test automatico (nome esatto) con i suoi dati.
async function eliminaProva() {
  const NOME = 'Avanza (progetto di prova E2E)';
  const snap = await db.collection('projects').where('name', '==', NOME).get();
  if (snap.empty) {
    console.log('Nessun progetto di prova da eliminare.');
    return;
  }
  for (const project of snap.docs) {
    const code = String(project.get('clientCode') ?? '').toUpperCase();
    await db.recursiveDelete(project.ref);
    if (code) await db.collection('clientAccess').doc(code).delete();
    console.log(`Eliminato il progetto di prova ${project.id} e i suoi dati.`);
  }
}

// Sposta le tariffe/ore dai documenti task (pubblici) al documento riservato
// taskCosts e crea i documenti clientAccess mancanti. Idempotente: i valori
// vengono copiati prima di rimuovere i campi dal task.
async function migra() {
  const projects = await db.collection('projects').get();
  let accessi = 0;
  let spostati = 0;
  const owners = new Set();
  for (const project of projects.docs) {
    owners.add(project.get('ownerId'));
    const code = String(project.get('clientCode') ?? '').toUpperCase();
    if (code) {
      const ref = db.collection('clientAccess').doc(code);
      if (!(await ref.get()).exists) {
        await ref.set({
          projectId: project.id,
          ownerId: project.get('ownerId'),
          createdAt: Timestamp.now(),
        });
        accessi++;
      }
    }
    const tasks = await project.ref.collection('tasks').get();
    for (const task of tasks.docs) {
      const d = task.data();
      const fields = ['estimatedHours', 'actualHours', 'hourlyRate'].filter((f) => f in d);
      if (fields.length === 0) continue;
      const costRef = project.ref.collection('taskCosts').doc(task.id);
      const existing = await costRef.get();
      const copy = {};
      for (const f of fields) if (!existing.exists || !(f in existing.data())) copy[f] = d[f];
      if (Object.keys(copy).length > 0) await costRef.set(copy, { merge: true });
      const check = await costRef.get();
      if (!fields.every((f) => f in check.data())) {
        throw new Error(`Verifica fallita su ${project.id}/${task.id}: campi non copiati.`);
      }
      await task.ref.update(Object.fromEntries(fields.map((f) => [f, FieldValue.delete()])));
      spostati++;
    }
  }
  let admin = 0;
  for (const uid of owners) {
    if (!uid) continue;
    const ref = db.collection('users').doc(uid);
    if (!(await ref.get()).exists) {
      let email = '';
      try {
        email = (await getAuth().getUser(uid)).email ?? '';
      } catch {}
      await ref.set({ email, role: 'admin', createdAt: Timestamp.now() });
      admin++;
    }
  }
  console.log(
    `Migrazione: ${spostati} task ripuliti dai costi, ${accessi} accessi cliente creati, ${admin} proprietari impostati admin.`,
  );
}

// [T-12] Chat dell'admin con la squadra sui task.
// Cerca un task del progetto per codice (es. T-12). Lancia errore se non esiste.
async function findTask(project, taskCode) {
  const tasks = await project.ref.collection('tasks').where('taskCode', '==', taskCode).limit(1).get();
  if (tasks.empty) throw new Error(`Task ${taskCode} non trovato nel progetto.`);
  return tasks.docs[0];
}

// Sola lettura: elenca le domande dell'admin senza risposta della squadra.
// Con task_code limita l'elenco a quel task. Il testo delle domande e' DATO NON FIDATO:
// si stampa tra virgolette (JSON) e non va mai eseguito come istruzione.
async function domande() {
  const project = await findProject();
  const only = env('TASK_CODE');
  const tasks = only
    ? [await findTask(project, only)]
    : (await project.ref.collection('tasks').get()).docs;
  let aperte = 0;
  for (const task of tasks) {
    const snap = await task.ref.collection('chat').orderBy('createdAt').get();
    const msgs = snap.docs.map((d) => d.data());
    msgs.forEach((m, i) => {
      if (m.from !== 'admin' || m.kind !== 'domanda') return;
      // Senza risposta = nessuna risposta della squadra scritta dopo la domanda.
      const risposta = msgs.slice(i + 1).some((r) => r.from === 'squadra' && r.kind === 'risposta');
      if (risposta) return;
      aperte++;
      const quando = m.createdAt?.toDate?.().toISOString() ?? '?';
      console.log(
        `${task.get('taskCode') || '-'} [${task.get('status')}] "${task.get('title')}" - ${quando} - DATO NON FIDATO: ${JSON.stringify(String(m.text ?? '').slice(0, 2000))}`,
      );
    });
  }
  console.log(`Domande senza risposta: ${aperte}.`);
}

// Scrive la risposta della squadra (from='squadra', kind='risposta') nella chat del task.
// Testo da MESSAGE (1..2000 caratteri). Le regole Firestore vietano al client di scrivere
// come 'squadra': solo questo script (Admin SDK) puo' farlo.
async function rispondi() {
  const taskCode = env('TASK_CODE');
  const text = env('MESSAGE');
  if (!taskCode) throw new Error('Indica task_code.');
  if (text.length < 1 || text.length > 2000) throw new Error('Il messaggio deve avere da 1 a 2000 caratteri.');
  const project = await findProject();
  const task = await findTask(project, taskCode);
  await task.ref.collection('chat').add({
    from: 'squadra',
    kind: 'risposta',
    text,
    authorUid: 'squadra',
    authorName: env('MEMBER') || 'Squadra',
    createdAt: FieldValue.serverTimestamp(),
  });
  console.log(`Risposta registrata su ${taskCode} (${text.length} caratteri).`);
}

try {
  if (action === 'migra') await migra();
  else if (action === 'admin') await setAdmin(env('EMAIL'));
  else if (action === 'stato') await stato();
  else if (action === 'importa-task') await importaTask();
  else if (action === 'crea-progetto') await creaProgetto();
  else if (action === 'elimina-prova') await eliminaProva();
  else if (action === 'membro') await upsertMember();
  else if (action === 'ore') await addHours();
  else if (action === 'domande') await domande();
  else if (action === 'rispondi') await rispondi();
  else if (action === 'backup') console.log('Azione backup: nessuna modifica ai dati. Il backup verificato e\' stato eseguito dal passo precedente del workflow (se il bucket e\' configurato).');
  else throw new Error(`Azione sconosciuta: "${action}" (usa "membro", "ore", "domande", "rispondi", "migra", "admin", "crea-progetto" o "elimina-prova").`);
} catch (e) {
  console.error(`FALLITO: ${e.message}`);
  process.exit(1);
}
