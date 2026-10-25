import { processEvent, ProcessDeps } from '../lib/eventProcessor';
import { LinkConfig } from '../lib/types';
import {
  CONFIG_ON,
  OWNER_UID,
  collectLog,
  prEvent,
  pushEvent,
  repoPayload,
  reviewEvent,
  seedAdmin,
  taskDoc,
} from './helpers/fixtures';
import { makeTestDb } from './helpers/testDb';

const t = makeTestDb();
const { db } = t;
const NOW = new Date('2026-10-25T10:00:00Z');

let config: LinkConfig | null = CONFIG_ON;
let logs = collectLog();
const deps = (over: Partial<ProcessDeps> = {}): ProcessDeps => ({
  db,
  getConfig: async () => config,
  now: () => NOW,
  log: logs.log,
  ...over,
});
const run = (type: string, payload: unknown, source: 'webhook' | 'github-app' = 'github-app') =>
  processEvent(deps(), type, payload as never, source, 'delivery-1');

const projectIds = async () => (await db.collection('projects').get()).docs.map((d) => d.id).sort();

beforeEach(async () => {
  await t.reset();
  await seedAdmin(db);
  config = CONFIG_ON;
  logs = collectLog();
});

describe(`processEvent — repository sconosciuto (${t.kind})`, () => {
  it('creates the project at the first branch of an unknown repository (CA-1.1, CA-1.3)', async () => {
    const r = await run('push', pushEvent());
    expect(r).toMatchObject({ outcome: 'creato', reason: 'progetto_creato' });
    const ids = await projectIds();
    expect(ids).toHaveLength(1);
    const p = (await db.collection('projects').doc(ids[0]).get()).data()!;
    expect(p).toMatchObject({
      name: 'prova-x',
      githubUrl: 'https://github.com/sbotz17/prova-x',
      ownerId: OWNER_UID,
      nextTaskNumber: 1,
      autoCreated: true,
      githubRepoId: 1001,
    });
    expect((await db.collection('clientAccess').doc(p['clientCode'] as string).get()).exists).toBe(true);
  });

  it('creates the project at the first pull request, review or closed PR too', async () => {
    expect((await run('pull_request', prEvent({ id: 11, html_url: 'https://github.com/sbotz17/a', name: 'a', full_name: 'sbotz17/a' }))).outcome).toBe('creato');
    expect((await run('pull_request_review', reviewEvent('NONE', { id: 12, html_url: 'https://github.com/sbotz17/b', name: 'b', full_name: 'sbotz17/b' }))).outcome).toBe('creato');
    expect((await run('pull_request', prEvent({ id: 13, html_url: 'https://github.com/sbotz17/c', name: 'c', full_name: 'sbotz17/c' }, 'closed'))).outcome).toBe('creato');
  });

  it('works with events signed by the historical per-repository secret as well', async () => {
    const r = await run('push', pushEvent(), 'webhook');
    expect(r.outcome).toBe('creato');
    const ids = await projectIds();
    expect((await db.collection('projects').doc(ids[0]).get()).get('autoCreatedSource')).toBe('webhook');
  });

  it('does NOT create anything when the switch is off or the configuration is missing (CA-7.3)', async () => {
    config = null;
    const r = await run('push', pushEvent());
    expect(r).toMatchObject({ outcome: 'non_agganciato', reason: 'creazione_spenta' });
    expect(await projectIds()).toEqual([]);
    expect((await db.collection('githubRepos').get()).size).toBe(0);
    expect((await db.collection('githubCollegamento').get()).size).toBe(0);
  });

  it('discards repositories of a different owner even with a valid signature (CA-1.5)', async () => {
    const r = await run('push', pushEvent({ owner: { login: 'qualcun-altro' }, full_name: 'qualcun-altro/prova-x', html_url: 'https://github.com/qualcun-altro/prova-x' }));
    expect(r).toMatchObject({ outcome: 'scartato', reason: 'proprietario_non_ammesso' });
    expect(await projectIds()).toEqual([]);
  });

  it('accepts the owner login in any letter case', async () => {
    const r = await run('push', pushEvent({ owner: { login: 'SBotz17' } }));
    expect(r.outcome).toBe('creato');
  });

  it('never creates a project for a fork, an archived repository or one without a numeric id (CA-6.5)', async () => {
    expect(await run('push', pushEvent({ fork: true }))).toMatchObject({ outcome: 'scartato', reason: 'fork' });
    expect(await run('push', pushEvent({ archived: true }))).toMatchObject({ outcome: 'scartato', reason: 'archiviato' });
    expect(await run('push', pushEvent({ id: undefined }))).toMatchObject({ outcome: 'scartato', reason: 'repository_senza_id' });
    expect(await projectIds()).toEqual([]);
  });

  it('skips a repository marked "non tracciare" (topic avanza-ignora): nothing created (CA-7.1)', async () => {
    const r = await run('push', pushEvent({ topics: ['flutter', 'avanza-ignora'] }));
    expect(r).toMatchObject({ outcome: 'escluso', reason: 'non_tracciare' });
    expect(await projectIds()).toEqual([]);
    expect((await db.collection('githubRepos').get()).size).toBe(0);
  });

  it('skips a "non tracciare" repository even if a project exists: no update at all', async () => {
    await db.collection('projects').doc('p1').set({ name: 'P', githubUrl: 'https://github.com/sbotz17/prova-x', ownerId: OWNER_UID });
    await db.collection('projects').doc('p1').collection('tasks').doc('t1').set(taskDoc('T-1'));
    const r = await run('push', pushEvent({ topics: ['avanza-ignora'] }, 'feature/T-1-x'));
    expect(r.outcome).toBe('escluso');
    const task = (await db.collection('projects').doc('p1').collection('tasks').doc('t1').get()).data()!;
    expect(task['status']).toBe('backlog');
    expect((await db.collection('projects').doc('p1').get()).get('githubRepoId')).toBeUndefined();
  });

  it.each([
    ['branch deleted', 'push', { ...pushEvent(), deleted: true }],
    ['tag push', 'push', { ...pushEvent(), ref: 'refs/tags/v1' }],
    ['repository created (empty repository)', 'repository', { action: 'created', repository: repoPayload() }],
    ['pull request labeled', 'pull_request', { ...prEvent(), action: 'labeled' }],
    ['review dismissed', 'pull_request_review', { ...reviewEvent('OWNER'), action: 'dismissed' }],
  ])('does not create a project on %s', async (_label, type, payload) => {
    const r = await run(type, payload);
    expect(r.outcome).toBe('non_agganciato');
    expect(await projectIds()).toEqual([]);
  });

  it.each(['ping', 'star', 'issues', 'installation', 'installation_repositories', 'check_run', 'workflow_run'])(
    'ignores the %s event (no project, no write)',
    async (type) => {
      const r = await run(type, { repository: repoPayload(), zen: 'Keep it logically awesome.' });
      expect(r.outcome).toBe('ignorato');
      expect(await projectIds()).toEqual([]);
    }
  );

  it('ignores an event without a repository', async () => {
    expect(await run('push', { ref: 'refs/heads/x' })).toMatchObject({ outcome: 'ignorato', reason: 'repository_assente' });
  });

  it('does not create anything if the configured owner is not an admin', async () => {
    config = { ...CONFIG_ON, ownerUid: 'uid-non-admin' };
    await db.collection('users').doc('uid-non-admin').set({ role: 'client' });
    const r = await run('push', pushEvent());
    expect(r).toMatchObject({ outcome: 'scartato', reason: 'proprietario_config_non_valido' });
    expect(await projectIds()).toEqual([]);
  });

  it('stops after the daily cap of new projects and logs the discarded events (CA-8.5)', async () => {
    config = { ...CONFIG_ON, maxNewProjectsPerDay: 2 };
    const ev = (n: number) => pushEvent({ id: 500 + n, name: `r${n}`, full_name: `sbotz17/r${n}`, html_url: `https://github.com/sbotz17/r${n}` });
    expect((await run('push', ev(1))).outcome).toBe('creato');
    expect((await run('push', ev(2))).outcome).toBe('creato');
    expect(await run('push', ev(3))).toMatchObject({ outcome: 'scartato', reason: 'limite_giornaliero' });
    expect(await projectIds()).toHaveLength(2);
    expect(logs.entries.some((e) => e.reason === 'limite_giornaliero' && e.repo === 'sbotz17/r3')).toBe(true);
  });

  it('is idempotent: the same delivery twice leaves one project (CA-1.2, CA-8.4)', async () => {
    const ev = pushEvent();
    const first = await run('push', ev);
    const second = await run('push', ev);
    expect(first.outcome).toBe('creato');
    expect(second.outcome).not.toBe('creato');
    expect(await projectIds()).toHaveLength(1);
    expect((await db.collection('clientAccess').get()).size).toBe(1);
  });

  it('concurrent events from the same new repository (branch + PR) create ONE project (CA-1.2)', async () => {
    const results = await Promise.all([
      run('push', pushEvent()),
      run('pull_request', prEvent()),
      run('push', pushEvent(), 'webhook'),
      run('pull_request_review', reviewEvent('NONE')),
      run('push', pushEvent({}, 'altro-ramo')),
    ]);
    expect(results.filter((r) => r.outcome === 'creato')).toHaveLength(1);
    expect(await projectIds()).toHaveLength(1);
    expect((await db.collection('clientAccess').get()).size).toBe(1);
  });

  it('a project deleted from the app does not come back (CA-7.2)', async () => {
    await run('push', pushEvent());
    const [id] = await projectIds();
    const code = (await db.collection('projects').doc(id).get()).get('clientCode') as string;
    await db.collection('projects').doc(id).delete();
    await db.collection('clientAccess').doc(code).delete();

    expect(await run('push', pushEvent())).toMatchObject({ outcome: 'escluso', reason: 'progetto_eliminato' });
    expect(await run('pull_request', prEvent())).toMatchObject({ outcome: 'escluso', reason: 'progetto_eliminato' });
    expect(await projectIds()).toEqual([]);
  });

  it('never creates tasks, not even for a branch with a task code (task creation is excluded from phase 1)', async () => {
    await run('push', pushEvent({}, 'feature/T-1-nuova-cosa'));
    const [id] = await projectIds();
    expect((await db.collection('projects').doc(id).collection('tasks').get()).size).toBe(0);
  });
});

describe(`processEvent — progetto esistente (${t.kind})`, () => {
  const seedVolty = async () => {
    await db.collection('projects').doc('volty').set({
      name: 'Volty',
      description: 'Gestionale',
      githubUrl: 'https://github.com/sbotz17/Volty-Flutter/',
      clientCode: 'VOLTY2',
      ownerId: OWNER_UID,
      nextTaskNumber: 4,
      createdAt: 'creato-il',
      updatedAt: 'aggiornato-il',
    });
    await db.collection('projects').doc('volty').collection('tasks').doc('t1').set(taskDoc('T-1'));
    await db.collection('projects').doc('volty').collection('tasks').doc('t2').set(taskDoc('T-2', 'review'));
  };
  const voltyEvent = (over: Record<string, unknown> = {}) => ({
    id: 4242,
    name: 'volty-flutter',
    full_name: 'sbotz17/volty-flutter',
    html_url: 'https://github.com/sbotz17/volty-flutter',
    ...over,
  });

  it('attaches the repository id to the existing project without a duplicate and without touching anything else (CA-2.1)', async () => {
    await seedVolty();
    const r = await run('push', pushEvent(voltyEvent(), 'feature/T-1-login'));
    expect(r).toMatchObject({ outcome: 'aggiornato', projectId: 'volty', taskCode: 'T-1' });

    expect(await projectIds()).toEqual(['volty']);
    const p = (await db.collection('projects').doc('volty').get()).data()!;
    expect(p).toMatchObject({
      name: 'Volty',
      description: 'Gestionale',
      githubUrl: 'https://github.com/sbotz17/Volty-Flutter/', // invariato
      clientCode: 'VOLTY2',
      ownerId: OWNER_UID,
      nextTaskNumber: 4,
      createdAt: 'creato-il',
      updatedAt: 'aggiornato-il', // la lista progetti e' ordinata per questo campo: non si tocca
      githubRepoId: 4242, // l'unica aggiunta
    });
    expect((await db.collection('githubRepos').doc('4242').get()).data()).toMatchObject({ projectId: 'volty', state: 'tracked', source: 'attach' });
    expect((await db.collection('clientAccess').get()).size).toBe(0); // nessun nuovo codice
  });

  it('attaches existing projects even when automatic creation is switched off', async () => {
    await seedVolty();
    config = null;
    await run('push', pushEvent(voltyEvent(), 'feature/T-1-login'));
    expect((await db.collection('projects').doc('volty').get()).get('githubRepoId')).toBe(4242);
  });

  it('keeps updating the task exactly as before (status, note, branch) (CA-2.4 regression)', async () => {
    await seedVolty();
    await run('push', pushEvent(voltyEvent(), 'feature/T-1-login'));
    const task = (await db.collection('projects').doc('volty').collection('tasks').doc('t1').get()).data()!;
    expect(task['status']).toBe('active');
    expect(task['githubBranch']).toBe('feature/T-1-login');
    expect(task['notes']).toEqual([{ type: 'info', text: '[gh] Branch feature/T-1-login creato' }]);
    expect((task['phases'] as Array<{ name: string; status: string }>).find((p) => p.name === 'Analisi')!.status).toBe('active');
  });

  it('is idempotent on a repeated delivery: no second note, no second project (CA-2.3)', async () => {
    await seedVolty();
    const ev = pushEvent(voltyEvent(), 'feature/T-1-login');
    await run('push', ev);
    const second = await run('push', ev);
    expect(second).toMatchObject({ outcome: 'ignorato', reason: 'nota_gia_presente' });
    const task = (await db.collection('projects').doc('volty').collection('tasks').doc('t1').get()).data()!;
    expect(task['notes']).toHaveLength(1);
    expect(await projectIds()).toEqual(['volty']);
  });

  it('never moves a "released" task and never goes backwards', async () => {
    await seedVolty();
    await db.collection('projects').doc('volty').collection('tasks').doc('t3').set(taskDoc('T-3', 'released'));
    await run('push', pushEvent(voltyEvent(), 'feature/T-3-x'));
    expect((await db.collection('projects').doc('volty').collection('tasks').doc('t3').get()).get('status')).toBe('released');
    await run('push', pushEvent(voltyEvent(), 'feature/T-2-x'));
    expect((await db.collection('projects').doc('volty').collection('tasks').doc('t2').get()).get('status')).toBe('review');
  });

  it('a collaborator approval promotes to validated; a stranger approval only leaves a note (CA-4.1, CA-4.2)', async () => {
    await seedVolty();
    await run('pull_request_review', reviewEvent('NONE', voltyEvent(), 'feature/T-1-login'));
    let task = (await db.collection('projects').doc('volty').collection('tasks').doc('t1').get()).data()!;
    expect(task['status']).toBe('backlog');
    expect(task['notes']).toEqual([{ type: 'info', text: '[gh] PR #7: approvazione di chi-approva non considerata (non collaboratore)' }]);

    await run('pull_request_review', reviewEvent('COLLABORATOR', voltyEvent(), 'feature/T-1-login'));
    task = (await db.collection('projects').doc('volty').collection('tasks').doc('t1').get()).data()!;
    expect(task['status']).toBe('validated');
  });

  it('finds a project registered with a different URL form (case, trailing slash)', async () => {
    await seedVolty();
    const r = await run('push', pushEvent(voltyEvent({ html_url: 'https://github.com/sbotz17/VOLTY-FLUTTER' }), 'feature/T-1-x'));
    expect(r.projectId).toBe('volty');
    expect(await projectIds()).toEqual(['volty']);
  });

  it('a repository renamed or transferred keeps its project: same id, new address (CA-6.2)', async () => {
    await seedVolty();
    await run('push', pushEvent(voltyEvent(), 'feature/T-1-x')); // aggancio
    const renamed = voltyEvent({ name: 'volty', full_name: 'sbotz17/volty', html_url: 'https://github.com/sbotz17/volty' });
    const r = await run('push', pushEvent(renamed, 'feature/T-2-x'));
    expect(r.projectId).toBe('volty');
    expect(await projectIds()).toEqual(['volty']);
    const p = (await db.collection('projects').doc('volty').get()).data()!;
    expect(p['githubUrl']).toBe('https://github.com/sbotz17/volty');
    expect(p['githubUrlPrecedente']).toBe('https://github.com/sbotz17/Volty-Flutter/');
    expect(p['githubRepoId']).toBe(4242);
    // gli eventi successivi continuano ad agganciarsi allo stesso progetto
    expect((await run('push', pushEvent(renamed, 'feature/T-1-y'))).projectId).toBe('volty');
  });

  it('a repository recreated with the same name (different id) does not overwrite the stored id nor create a duplicate', async () => {
    await seedVolty();
    await run('push', pushEvent(voltyEvent(), 'feature/T-1-x'));
    const r = await run('push', pushEvent(voltyEvent({ id: 9999 }), 'feature/T-2-x'));
    expect(r.projectId).toBe('volty');
    expect((await db.collection('projects').doc('volty').get()).get('githubRepoId')).toBe(4242);
    expect(await projectIds()).toEqual(['volty']);
    expect(logs.entries.some((e) => e.reason === 'identificativo_repository_diverso')).toBe(true);
    expect((await db.collection('githubRepos').doc('9999').get()).exists).toBe(false);
  });

  it('the project of a repository created later is matched by the address registered in advance (CA-2.2)', async () => {
    await db.collection('projects').doc('commerciali').set({ name: 'Commerciali', githubUrl: 'https://github.com/sbotz17/commerciali', ownerId: OWNER_UID, nextTaskNumber: 1 });
    const r = await run('push', pushEvent({ id: 777, name: 'commerciali', full_name: 'sbotz17/commerciali', html_url: 'https://github.com/sbotz17/commerciali' }));
    expect(r.projectId).toBe('commerciali');
    expect(await projectIds()).toEqual(['commerciali']);
    expect((await db.collection('projects').doc('commerciali').get()).get('githubRepoId')).toBe(777);
  });

  it('an unknown task code is logged as not attached and creates nothing (CA-3.4)', async () => {
    await seedVolty();
    const r = await run('push', pushEvent(voltyEvent(), 'feature/T-99-x'));
    expect(r).toMatchObject({ outcome: 'non_agganciato', reason: 'task_inesistente', taskCode: 'T-99' });
    expect((await db.collection('projects').doc('volty').collection('tasks').get()).size).toBe(2);
  });

  it('a branch without a task code is logged as not attached', async () => {
    await seedVolty();
    expect(await run('push', pushEvent(voltyEvent(), 'feature/senza-codice'))).toMatchObject({ outcome: 'non_agganciato', reason: 'senza_codice_task' });
  });

  it('marks archived / unarchived / deleted repositories on the project, deleting nothing (CA-6.1, CA-6.3)', async () => {
    await seedVolty();
    await run('push', pushEvent(voltyEvent(), 'feature/T-1-x'));
    expect(await run('repository', { action: 'archived', repository: repoPayload(voltyEvent({ archived: true })) })).toMatchObject({ outcome: 'aggiornato' });
    expect((await db.collection('projects').doc('volty').get()).get('githubArchived')).toBe(true);
    expect(await run('repository', { action: 'archived', repository: repoPayload(voltyEvent({ archived: true })) })).toMatchObject({ outcome: 'ignorato' });
    await run('repository', { action: 'unarchived', repository: repoPayload(voltyEvent()) });
    expect((await db.collection('projects').doc('volty').get()).get('githubArchived')).toBe(false);
    await run('repository', { action: 'deleted', repository: repoPayload(voltyEvent()) });
    expect((await db.collection('projects').doc('volty').get()).get('githubDeleted')).toBe(true);
    expect((await db.collection('projects').doc('volty').collection('tasks').get()).size).toBe(2);
    expect(await projectIds()).toEqual(['volty']);
  });

  it('a "repository" event about an unknown repository creates nothing', async () => {
    expect(await run('repository', { action: 'archived', repository: repoPayload() })).toMatchObject({ outcome: 'non_agganciato' });
    expect(await projectIds()).toEqual([]);
  });

  it('a project recreated by hand after deletion is matched again and becomes tracked', async () => {
    await run('push', pushEvent());
    const [id] = await projectIds();
    await db.collection('projects').doc(id).delete();
    expect((await run('push', pushEvent())).outcome).toBe('escluso');
    // La squadra ricrea il progetto a mano con lo stesso indirizzo.
    await db.collection('projects').doc('manuale').set({ name: 'prova-x', githubUrl: 'https://github.com/sbotz17/prova-x', ownerId: OWNER_UID, nextTaskNumber: 1 });
    const r = await run('push', pushEvent());
    expect(r.projectId).toBe('manuale');
    expect(await projectIds()).toEqual(['manuale']);
  });
});

describe(`processEvent — tracciabilita' (${t.kind})`, () => {
  it('every event leaves a structured log entry with outcome and reason and no personal data (CA-8.2)', async () => {
    await run('push', pushEvent({ description: 'dati-riservati-del-cliente' }, 'feature/segreto-del-ramo'));
    await run('star', { repository: repoPayload() });
    await run('push', pushEvent({ id: 2, fork: true, full_name: 'sbotz17/fork-y', html_url: 'https://github.com/sbotz17/fork-y' }));
    expect(logs.entries.map((e) => `${e.outcome}:${e.reason}`)).toEqual(['creato:progetto_creato', 'ignorato:evento_non_gestito', 'scartato:fork']);
    for (const e of logs.entries) {
      expect(e.delivery).toBe('delivery-1');
      expect(e.repo).toMatch(/^sbotz17\/(prova-x|fork-y)$/);
      const text = JSON.stringify(e);
      expect(text).not.toContain('dati-riservati-del-cliente');
      expect(text).not.toContain('segreto-del-ramo');
      expect(text).not.toContain('abcdef1234567'); // niente commit
    }
  });

  it('propagates Firestore errors so that the function answers 500', async () => {
    const broken = { collection: () => { throw new Error('firestore giu'); } };
    await expect(processEvent({ ...deps(), db: broken as never }, 'push', pushEvent() as never, 'webhook', 'd')).rejects.toThrow('firestore giu');
  });
});
