// Test end-to-end del webhook GitHub -> Cloud Function -> Firestore.
// Lavora sul progetto reale del repository con un task TEMPORANEO (codice T-9xxx),
// che viene cancellato alla fine insieme al branch di prova. Non tocca i task veri.
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(path.resolve('functions/package.json'));
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const REPO = process.env.GITHUB_REPOSITORY;
const TASK_CODE = process.env.TASK_CODE || 'T-9001';
const REPO_URL = `https://github.com/${REPO}`.toLowerCase();
const BRANCH = `test/${TASK_CODE}-e2e-${process.env.GITHUB_RUN_ID || Date.now()}`;

for (const k of ['GITHUB_TOKEN', 'GITHUB_REPOSITORY', 'GITHUB_SHA']) {
  if (!process.env[k]) {
    console.error(`Variabile mancante: ${k}`);
    process.exit(2);
  }
}
if (!/^T-9\d{3}$/.test(TASK_CODE)) {
  console.error('Il codice del task di prova deve essere del tipo T-9xxx, per non toccare i task veri.');
  process.exit(2);
}

if (getApps().length === 0) initializeApp({ projectId: 'avanza-b62d7' });
const db = getFirestore();

const gh = (p, init = {}) =>
  fetch(`https://api.github.com/repos/${REPO}${p}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${process.env.GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
    },
  });

let taskRef = null;
let branchCreated = false;

async function main() {
  const snap = await db.collection('projects').get();
  const matches = snap.docs.filter(
    (d) => String(d.get('githubUrl') ?? '').toLowerCase().replace(/\/$/, '') === REPO_URL,
  );
  if (matches.length === 0) throw new Error(`Nessun progetto con githubUrl ${REPO_URL}: crealo prima.`);
  if (matches.length > 1) {
    throw new Error(`Piu' progetti con lo stesso indirizzo GitHub (${matches.length}): il webhook non saprebbe quale usare.`);
  }
  const project = matches[0];
  console.log(`Progetto: ${project.get('name')}`);

  const used = await project.ref.collection('tasks').where('taskCode', '==', TASK_CODE).limit(1).get();
  if (!used.empty) throw new Error(`Il codice ${TASK_CODE} e' gia' usato nel progetto: scegline un altro.`);

  const now = Timestamp.now();
  taskRef = project.ref.collection('tasks').doc();
  await taskRef.set({
    title: 'Test automatico E2E (temporaneo)',
    description: 'Creato dal test del webhook e cancellato al termine.',
    clientRequest: '',
    status: 'backlog',
    phases: ['Analisi', 'Database', 'Backend', 'Design', 'Frontend', 'Test', 'Validazione'].map((name) => ({
      name,
      status: 'pending',
      label: 'In attesa',
    })),
    notes: [],
    order: 9999,
    taskCode: TASK_CODE,
    taskNumber: 9999,
    createdAt: now,
    updatedAt: now,
  });
  console.log(`Task temporaneo ${TASK_CODE} creato`);

  const created = await gh('/git/refs', {
    method: 'POST',
    body: JSON.stringify({ ref: `refs/heads/${BRANCH}`, sha: process.env.GITHUB_SHA }),
  });
  if (!created.ok) throw new Error(`Creazione branch fallita (${created.status}): ${await created.text()}`);
  branchCreated = true;
  console.log(`Branch di prova creato: ${BRANCH}`);

  const expectedNote = `[gh] Branch ${BRANCH} creato`;
  let last = null;
  for (let i = 0; i < 18; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    last = (await taskRef.get()).data();
    const notes = (last?.notes ?? []).map((n) => n.text);
    if (notes.includes(expectedNote) && last.githubBranch === BRANCH) {
      console.log(`OK: nota "${expectedNote}" presente, stato task = ${last.status}`);
      return;
    }
  }
  throw new Error(
    `Il task non e' stato aggiornato entro 90 secondi (stato: ${last?.status}). Controlla Recent Deliveries del webhook.`,
  );
}

let failed = false;
try {
  await main();
} catch (e) {
  failed = true;
  console.error(`FALLITO: ${e.message}`);
} finally {
  if (branchCreated) {
    const del = await gh(`/git/refs/heads/${BRANCH}`, { method: 'DELETE' });
    console.log(`Pulizia branch di prova: ${del.status === 204 ? 'fatta' : `stato ${del.status}`}`);
  }
  if (taskRef) {
    await taskRef.delete();
    console.log('Pulizia task temporaneo: fatta');
  }
}
process.exit(failed ? 1 : 0);
