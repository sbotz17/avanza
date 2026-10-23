// Test end-to-end del webhook GitHub -> Cloud Function -> Firestore.
// Variabili: TEST_USER_EMAIL, TEST_USER_PASSWORD, GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_SHA.
const API_KEY = process.env.FIREBASE_API_KEY;
const PROJECT = 'avanza-b62d7';
const TASK_CODE = process.env.TASK_CODE || 'T-1';
const REPO = process.env.GITHUB_REPOSITORY;
const REPO_URL = `https://github.com/${REPO}`.toLowerCase();
const BRANCH = `test/${TASK_CODE}-e2e-${process.env.GITHUB_RUN_ID || Date.now()}`;
const DOCS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

const need = ['FIREBASE_API_KEY', 'TEST_USER_EMAIL', 'TEST_USER_PASSWORD', 'GITHUB_TOKEN', 'GITHUB_REPOSITORY', 'GITHUB_SHA'];
for (const k of need) {
  if (!process.env[k]) {
    console.error(`Variabile mancante: ${k}`);
    process.exit(2);
  }
}

const gh = (path, init = {}) =>
  fetch(`https://api.github.com/repos/${REPO}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${process.env.GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
    },
  });

async function signIn() {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: process.env.TEST_USER_EMAIL,
        password: process.env.TEST_USER_PASSWORD,
        returnSecureToken: true,
      }),
    },
  );
  const body = await res.json();
  if (!res.ok) throw new Error(`Login fallito: ${body?.error?.message ?? res.status}`);
  return { token: body.idToken, uid: body.localId };
}

async function runQuery(parent, token, structuredQuery) {
  const res = await fetch(`${DOCS}${parent}:runQuery`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ structuredQuery }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`Query Firestore fallita (${res.status}): ${JSON.stringify(body)}`);
  return body.filter((r) => r.document).map((r) => r.document);
}

const str = (f) => f?.stringValue ?? null;
const noteTexts = (doc) =>
  (doc.fields.notes?.arrayValue?.values ?? []).map((v) => str(v.mapValue?.fields?.text));

async function main() {
  const { token, uid } = await signIn();
  console.log('Login utente di prova: OK');

  const projects = await runQuery('', token, {
    from: [{ collectionId: 'projects' }],
    where: { fieldFilter: { field: { fieldPath: 'ownerId' }, op: 'EQUAL', value: { stringValue: uid } } },
  });
  const project = projects.find(
    (p) => (str(p.fields.githubUrl) ?? '').toLowerCase().replace(/\/$/, '') === REPO_URL,
  );
  if (!project) {
    throw new Error(
      `L'utente di prova non ha un progetto con githubUrl ${REPO_URL}. Crealo dall'app (vedi istruzioni).`,
    );
  }
  const projectPath = `/${project.name.split('/documents/')[1]}`;
  console.log(`Progetto trovato: ${str(project.fields.name)}`);

  const tasks = await runQuery(projectPath, token, {
    from: [{ collectionId: 'tasks' }],
    where: { fieldFilter: { field: { fieldPath: 'taskCode' }, op: 'EQUAL', value: { stringValue: TASK_CODE } } },
    limit: 1,
  });
  if (tasks.length === 0) throw new Error(`Nel progetto non esiste il task ${TASK_CODE}.`);
  const taskPath = `/${tasks[0].name.split('/documents/')[1]}`;
  console.log(`Task ${TASK_CODE} trovato`);

  const created = await gh('/git/refs', {
    method: 'POST',
    body: JSON.stringify({ ref: `refs/heads/${BRANCH}`, sha: process.env.GITHUB_SHA }),
  });
  if (!created.ok) throw new Error(`Creazione branch fallita (${created.status}): ${await created.text()}`);
  console.log(`Branch di prova creato: ${BRANCH}`);

  const expectedNote = `[gh] Branch ${BRANCH} creato`;
  let ok = false;
  let last = null;
  for (let i = 0; i < 18 && !ok; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    const res = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents${taskPath}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    last = await res.json();
    if (res.ok && noteTexts(last).includes(expectedNote) && str(last.fields.githubBranch) === BRANCH) ok = true;
  }
  if (!ok) {
    throw new Error(
      `Il task non e' stato aggiornato entro 90 secondi. Stato: ${str(last?.fields?.status)}, ` +
        `branch: ${str(last?.fields?.githubBranch)}. Controlla Recent Deliveries del webhook.`,
    );
  }
  console.log(`OK: nota "${expectedNote}" presente, stato task = ${str(last.fields.status)}`);
}

let failed = false;
try {
  await main();
} catch (e) {
  failed = true;
  console.error(`FALLITO: ${e.message}`);
} finally {
  const del = await gh(`/git/refs/heads/${BRANCH}`, { method: 'DELETE' });
  console.log(`Pulizia branch di prova: ${del.status === 204 ? 'fatta' : `stato ${del.status}`}`);
}
process.exit(failed ? 1 : 0);
