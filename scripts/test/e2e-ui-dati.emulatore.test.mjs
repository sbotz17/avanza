// Prova del modulo dati della prova UI (creazione e PULIZIA) contro gli EMULATORI Firestore e Auth: mai il progetto vero.
// Senza emulatori questo file non fa nulla (il test e' saltato), cosi' `node --test scripts/test/*.test.mjs` resta senza rete.
// Per lanciarlo davvero (serve Java; dalla radice del repository, dopo `npm ci --prefix functions`):
//   firebase emulators:exec --only firestore,auth --project demo-avanza "node --test scripts/test/e2e-ui-dati.emulatore.test.mjs"
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { generaRunId, generaPassword } from '../lib/e2e-ui-logica.mjs';
import * as D from '../lib/e2e-ui-dati.mjs';

const conEmulatori = Boolean(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST);

test('creazione e pulizia dei dati di prova sugli emulatori', { skip: conEmulatori ? false : 'emulatori Firestore/Auth non attivi' }, async () => {
  const radice = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
  const req = createRequire(path.join(radice, 'functions', 'package.json'));
  const { initializeApp } = req('firebase-admin/app');
  const { getFirestore, Timestamp } = req('firebase-admin/firestore');
  const { getAuth } = req('firebase-admin/auth');
  initializeApp({ projectId: 'demo-avanza' });
  const db = getFirestore();
  const auth = getAuth();
  const dep = { db, auth, Timestamp };

  // dati "veri" che la pulizia NON deve toccare, e un altro giro della prova
  await db.doc('projects/progetto-vero').set({ name: 'Vero', ownerId: 'utente-vero' });
  await db.doc('projects/progetto-vero/tasks/t1').set({ title: 'x' });
  await db.doc('teamMembers/membro-vero').set({ ownerId: 'utente-vero', name: 'Vero' });
  await db.doc('users/utente-vero').set({ role: 'admin' });
  const altroRun = 'e2e-ui-1761650000999-beef';
  await db.doc(`projects/${altroRun}`).set({ name: 'altro giro', ownerId: altroRun });
  await db.doc(`teamMembers/${altroRun}-m1`).set({ ownerId: altroRun });

  const run = generaRunId();
  const dati = await D.creaDatiDiProva(dep, { runId: run, password: generaPassword() });
  assert.equal((await db.doc(`users/${run}`).get()).get('role'), 'admin');
  assert.equal((await db.doc(`projects/${run}`).get()).get('ownerId'), run);
  assert.equal((await db.collection(`projects/${run}/tasks`).get()).size, 2);
  assert.equal((await db.collection(`projects/${run}/taskCosts`).get()).size, 2);
  assert.equal((await db.doc(`projects/${run}/tasks/${dati.ids.task[0]}`).get()).get('status'), 'active');
  assert.equal((await db.doc(`projects/${run}/tasks/${dati.ids.task[1]}`).get()).get('status'), 'released');
  assert.equal(await D.contaMembriDelRun(dep, run), 2);
  assert.equal((await auth.getUser(run)).email, dati.email);

  // chat come la scriverebbe l'app, e documenti "creati dall'app" con ID casuale ma ownerId = run
  await db.collection(`projects/${run}/tasks/${dati.ids.task[0]}/chat`).add({ from: 'admin', kind: 'domanda', text: 'prova e2e', authorUid: run, authorName: dati.email, createdAt: Timestamp.now() });
  assert.ok(await D.trovaMessaggioChat(dep, run, 0, 'prova e2e'));
  assert.equal(await D.trovaMessaggioChat(dep, run, 0, 'altro testo'), null);
  assert.equal(await D.trovaMessaggioChat(dep, run, 1, 'prova e2e'), null);
  await db.doc('teamMembers/casuale-1').set({ ownerId: run, name: 'Nuovo' });
  assert.equal(await D.contaMembriDelRun(dep, run), 3);
  await db.doc('projects/casuale-2').set({ ownerId: run, name: 'creato dall\'app' });
  await db.doc('projects/casuale-2/tasks/x').set({ title: 'x' });

  const esito = await D.pulisciDatiDiProva(dep, run);
  assert.deepEqual(esito.errori, []);
  assert.equal(esito.verificata, true);
  for (const percorso of [`projects/${run}`, 'projects/casuale-2', 'projects/casuale-2/tasks/x', 'teamMembers/casuale-1', `users/${run}`]) {
    assert.equal((await db.doc(percorso).get()).exists, false, percorso);
  }
  assert.equal((await db.collection(`projects/${run}/tasks/${dati.ids.task[0]}/chat`).get()).size, 0);
  await assert.rejects(auth.getUser(run));

  // il resto e' intatto
  for (const percorso of ['projects/progetto-vero', 'projects/progetto-vero/tasks/t1', 'teamMembers/membro-vero', 'users/utente-vero', `projects/${altroRun}`, `teamMembers/${altroRun}-m1`]) {
    assert.equal((await db.doc(percorso).get()).exists, true, `${percorso} non va toccato`);
  }

  // idempotente; run non valido o password corta rifiutati
  const di_nuovo = await D.pulisciDatiDiProva(dep, run);
  assert.deepEqual(di_nuovo.errori, []);
  assert.equal(di_nuovo.verificata, true);
  await assert.rejects(D.pulisciDatiDiProva(dep, 'projects'), /non valido/);
  await assert.rejects(D.pulisciDatiDiProva(dep, ''), /non valido/);
  await assert.rejects(D.creaDatiDiProva(dep, { runId: generaRunId(), password: 'corta' }), /corta/);
});
