// Usato dalla squadra (workflow "Registra ore squadra") per registrare membri e ore.
// Usa le credenziali del service account (firebase-admin), quindi non passa dalle regole.
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(path.resolve('functions/package.json'));
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

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
  const snap = await db.collection('projects').get();
  const matches = snap.docs.filter(
    (d) => String(d.get('githubUrl') ?? '').toLowerCase().replace(/\/$/, '') === repoUrl,
  );
  if (matches.length === 0) throw new Error(`Nessun progetto con githubUrl ${repoUrl}.`);
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
  batch.update(task.ref, {
    actualHours: FieldValue.increment(hours),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log(`Registrate ${hours}h di ${member.get('name')} su ${taskCode} (${phase}).`);
}

try {
  if (action === 'membro') await upsertMember();
  else if (action === 'ore') await addHours();
  else throw new Error(`Azione sconosciuta: "${action}" (usa "membro" o "ore").`);
} catch (e) {
  console.error(`FALLITO: ${e.message}`);
  process.exit(1);
}
