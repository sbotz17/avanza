// Dati di prova della prova UI (scripts/e2e-ui-test.mjs): creazione e PULIZIA nel progetto di TEST.
// Le dipendenze (Firestore, Auth, Timestamp dell'Admin SDK) sono PASSATE da fuori: cosi' il modulo si prova su un emulatore
// senza dover aggirare le guardie dello script principale. Questo modulo non decide MAI su quale progetto lavora:
// lo decide chi lo chiama, dopo le guardie (controllaGuardie).
import { assertRunId, emailDiProva, idDellaProva, puoEliminare } from './e2e-ui-logica.mjs';

/** Testi dei dati di prova (la prova li cerca a schermo). */
export function nomiDellaProva(runId) {
  assertRunId(runId);
  return {
    progetto: `E2E UI ${runId}`,
    taskInCorso: 'E2E task in corso',
    taskRilasciato: 'E2E task rilasciato',
    membri: ['E2E Alfa', 'E2E Beta'],
    ruoloMembro: 'ruolo e2e di prova',
  };
}

const FASI = ['Analisi', 'Database', 'Backend', 'Design', 'Frontend', 'Test', 'Validazione'];

/**
 * Crea l'utente di prova (Auth, con UID = run), il suo profilo admin, un progetto con 2 task (uno 'active', uno 'released')
 * e 2 membri della squadra, tutti con ID derivati dal run e con il campo `e2eRun`. Solo aggiunte, solo nel progetto di test.
 */
export async function creaDatiDiProva({ db, auth, Timestamp }, { runId, password, ora = new Date() }) {
  assertRunId(runId);
  if (typeof password !== 'string' || password.length < 12) throw new Error('Password di prova troppo corta.');
  const ids = idDellaProva(runId);
  const email = emailDiProva(runId);
  const nomi = nomiDellaProva(runId);
  const t = Timestamp.fromDate(ora);

  await auth.createUser({ uid: ids.uid, email, password, emailVerified: true });

  const batch = db.batch();
  batch.set(db.doc(`users/${ids.uid}`), { email, role: 'admin', createdAt: t, e2eRun: runId });

  const progetto = db.doc(`projects/${ids.progetto}`);
  batch.set(progetto, {
    name: nomi.progetto,
    description: 'Progetto creato dalla prova automatica UI: viene eliminato a fine prova.',
    githubUrl: '', // vuoto: il webhook non lo collega mai a un repository
    clientCode: `E2E-${runId.slice(-4).toUpperCase()}`,
    ownerId: ids.uid,
    nextTaskNumber: 3,
    createdAt: t,
    updatedAt: t,
    e2eRun: runId,
  });

  const task = (idx, titolo, status, fasiFatte) => {
    const rif = progetto.collection('tasks').doc(ids.task[idx]);
    batch.set(rif, {
      title: titolo,
      description: 'Task di prova (prova automatica UI).',
      clientRequest: '',
      status,
      phases: FASI.map((name, i) => ({ name, status: i < fasiFatte ? 'done' : 'pending', label: i < fasiFatte ? 'Fatto' : 'In attesa' })),
      notes: [],
      order: idx,
      taskCode: `T-${idx + 1}`,
      taskNumber: idx + 1,
      createdAt: t,
      updatedAt: t,
      e2eRun: runId,
    });
    batch.set(progetto.collection('taskCosts').doc(ids.task[idx]), { estimatedHours: 2, actualHours: 0, hourlyRate: 10, e2eRun: runId });
  };
  task(0, nomi.taskInCorso, 'active', 2);
  task(1, nomi.taskRilasciato, 'released', FASI.length);

  ids.membri.forEach((id, i) => {
    batch.set(db.doc(`teamMembers/${id}`), {
      ownerId: ids.uid,
      name: nomi.membri[i],
      kind: i === 0 ? 'agent' : 'person',
      role: nomi.ruoloMembro,
      costRate: 10,
      billRate: 20,
      active: true,
      createdAt: t,
      e2eRun: runId,
    });
  });

  await batch.commit();
  return { ids, email, nomi };
}

/** Messaggio di chat scritto dall'utente di prova sul task indicato (o null). */
export async function trovaMessaggioChat({ db }, runId, indiceTask, testo) {
  const ids = idDellaProva(runId);
  const snap = await db.collection(`projects/${ids.progetto}/tasks/${ids.task[indiceTask]}/chat`).where('text', '==', testo).get();
  const doc = snap.docs.find((d) => d.get('authorUid') === ids.uid && d.get('from') === 'admin');
  return doc ? doc.data() : null;
}

/** Quanti membri della squadra appartengono all'utente di prova (devono restare 2). */
export async function contaMembriDelRun({ db }, runId) {
  assertRunId(runId);
  const snap = await db.collection('teamMembers').where('ownerId', '==', runId).get();
  return snap.size;
}

/**
 * Elimina SOLO ci' che appartiene al run (vedi puoEliminare): progetto di prova con task/chat/costi/ore, membri, profilo e utente Auth.
 * Idempotente: se non c'e' piu' nulla non fa nulla. Poi VERIFICA che sia sparito tutto.
 * Ritorna { eliminati[], saltati[], errori[], verificata }.
 */
export async function pulisciDatiDiProva({ db, auth }, runId) {
  assertRunId(runId);
  const ids = idDellaProva(runId);
  const esito = { eliminati: [], saltati: [], errori: [], verificata: false };
  const daEliminare = new Map();
  const considera = (ref, dati) => {
    if (puoEliminare(ref.path, dati, runId)) daEliminare.set(ref.path, ref);
    else esito.saltati.push(ref.path);
  };

  // 1) per ID derivato dal run
  considera(db.doc(`projects/${ids.progetto}`), null);
  considera(db.doc(`users/${ids.uid}`), null);
  for (const m of ids.membri) considera(db.doc(`teamMembers/${m}`), null);
  // 2) documenti creati dall'utente di prova dall'app (ID casuali, ma ownerId = run)
  for (const col of ['projects', 'teamMembers', 'clientAccess']) {
    try {
      const snap = await db.collection(col).where('ownerId', '==', runId).get();
      for (const d of snap.docs) considera(d.ref, d.data());
    } catch (e) {
      esito.errori.push(`ricerca in ${col}: ${e.message}`);
    }
  }

  for (const [percorso, ref] of daEliminare) {
    try {
      // recursiveDelete solo su documenti gia' riconosciuti come del run (progetto di prova: task, chat, costi, ore; profilo: sotto-raccolte)
      await db.recursiveDelete(ref);
      esito.eliminati.push(percorso);
    } catch (e) {
      esito.errori.push(`eliminazione di ${percorso}: ${e.message}`);
    }
  }
  try {
    await auth.deleteUser(ids.uid);
    esito.eliminati.push(`auth:${ids.uid}`);
  } catch (e) {
    if (e?.code !== 'auth/user-not-found') esito.errori.push(`eliminazione utente Auth: ${e.message}`);
  }

  // verifica: non deve restare nulla
  try {
    let resta = false;
    for (const [percorso, ref] of daEliminare) {
      if ((await ref.get()).exists) {
        resta = true;
        esito.errori.push(`${percorso} esiste ancora`);
      }
      for (const sotto of await ref.listCollections()) {
        if (!(await sotto.limit(1).get()).empty) {
          resta = true;
          esito.errori.push(`${sotto.path} non e' vuota`);
        }
      }
    }
    try {
      await auth.getUser(ids.uid);
      resta = true;
      esito.errori.push('utente Auth ancora presente');
    } catch (e) {
      if (e?.code !== 'auth/user-not-found') {
        resta = true;
        esito.errori.push(`verifica utente Auth: ${e.message}`);
      }
    }
    esito.verificata = !resta && esito.errori.length === 0;
  } catch (e) {
    esito.errori.push(`verifica della pulizia: ${e.message}`);
  }
  return esito;
}
