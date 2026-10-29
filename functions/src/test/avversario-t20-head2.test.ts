/**
 * T-20 fase 1 — prove da AVVERSARIO sul nuovo head cf8e782: creazione solo dalla GitHub App (D1) e proprietario coerente.
 */
import { processEvent, ProcessDeps } from '../lib/eventProcessor';
import { LinkConfig } from '../lib/types';
import { CONFIG_ON, collectLog, prEvent, pushEvent, repoPayload, reviewEvent, seedAdmin, taskDoc } from './helpers/fixtures';
import { makeTestDb } from './helpers/testDb';

jest.setTimeout(60_000);
const t = makeTestDb();
const { db } = t;
const NOW = new Date('2026-10-25T10:00:00Z');
const config: LinkConfig = CONFIG_ON;
let logs = collectLog();
const deps = (): ProcessDeps => ({ db, getConfig: async () => config, now: () => NOW, log: logs.log });
const run = (type: string, payload: unknown, source: 'webhook' | 'github-app' = 'github-app') =>
  processEvent(deps(), type, payload as never, source, 'd-1');
const projectIds = async () => (await db.collection('projects').get()).docs.map((d) => d.id).sort();
const repo = (n: number) =>
  repoPayload({ id: 5000 + n, name: `r${n}`, full_name: `sbotz17/r${n}`, html_url: `https://github.com/sbotz17/r${n}` });

beforeEach(async () => {
  await t.reset();
  await seedAdmin(db);
  logs = collectLog();
});

describe(`AVVERSARIO head2 — D1 (${t.kind})`, () => {
  it('un evento firmato con il segreto STORICO non crea mai un progetto, ma aggiorna i task come prima', async () => {
    for (const ty of ['push', 'pull_request', 'pull_request_review'] as const) {
      const p = ty === 'push' ? pushEvent() : ty === 'pull_request' ? prEvent() : reviewEvent('OWNER');
      expect(await run(ty, p, 'webhook')).toMatchObject({ outcome: 'non_agganciato', reason: 'creazione_solo_da_github_app' });
    }
    expect(await projectIds()).toEqual([]);
    expect((await db.collection('githubRepos').get()).size).toBe(0);
    expect((await db.collection('githubCollegamento').get()).size).toBe(0);
    expect((await run('push', pushEvent(), 'github-app')).outcome).toBe('creato');
    await db.collection('projects').doc('gh_1001').collection('tasks').doc('t1').set(taskDoc('T-1', 'backlog'));
    expect((await run('push', pushEvent({}, 'feature/T-1-x'), 'webhook')).outcome).toBe('aggiornato');
  });

  it('20 repository nuovi dal webhook storico non consumano il tetto giornaliero', async () => {
    for (let i = 0; i < 20; i++) await run('push', pushEvent(repo(i) as never), 'webhook');
    expect(await projectIds()).toEqual([]);
    expect((await run('push', pushEvent(repo(99) as never), 'github-app')).outcome).toBe('creato');
  });

  it.each([
    ['owner.login diverso da full_name', { owner: { login: 'sbotz17' }, full_name: 'evil/r1', html_url: 'https://github.com/sbotz17/r1', name: 'r1' }],
    ["owner.login diverso dall'URL", { owner: { login: 'sbotz17' }, full_name: 'sbotz17/r1', html_url: 'https://github.com/evil/r1', name: 'r1' }],
    ['full_name e URL con nome diverso', { owner: { login: 'sbotz17' }, full_name: 'sbotz17/altro', html_url: 'https://github.com/sbotz17/r1', name: 'r1' }],
    ["name diverso dall'URL", { owner: { login: 'sbotz17' }, full_name: 'sbotz17/r1', html_url: 'https://github.com/sbotz17/r1', name: 'zzz' }],
    ['full_name senza barra', { owner: { login: 'sbotz17' }, full_name: 'sbotz17', html_url: 'https://github.com/sbotz17/r1', name: 'r1' }],
    ['owner senza login (da full_name) ma URL altrui', { owner: {}, full_name: 'sbotz17/r1', html_url: 'https://github.com/evil/r1', name: 'r1' }],
  ])('%s -> mai creato', async (_l, over) => {
    const r = await run('push', pushEvent({ id: 4242, ...over }));
    expect(r.outcome).not.toBe('creato');
    expect(await projectIds()).toEqual([]);
    expect((await db.collection('githubCollegamento').get()).size).toBe(0);
  });

  it('NOTA (informativa): full_name con una terza parte ("sbotz17/r1/x", impossibile su GitHub reale) viene accettato dal controllo di coerenza', async () => {
    const r = await run('push', pushEvent({ id: 4243, owner: { login: 'sbotz17' }, full_name: 'sbotz17/r1/x', html_url: 'https://github.com/sbotz17/r1', name: 'r1' }));
    console.log(`[nota] full_name a tre parti -> ${r.outcome}`);
  });

  it('NOTA (informativa, pre-esistente): payload firmato malformato su progetto NOTO -> eccezione (la funzione risponde 500)', async () => {
    await db.collection('projects').doc('P').set({ name: 'V', githubUrl: 'https://github.com/sbotz17/prova-x', ownerId: 'u' });
    const bad: Array<[string, unknown]> = [
      ['pull_request senza pull_request', { action: 'opened', repository: repoPayload() }],
      ['push con commit senza id', { ref: 'refs/heads/feature/T-1-x', created: false, commits: [{}], repository: repoPayload() }],
      ['review senza review', { action: 'submitted', repository: repoPayload() }],
    ];
    for (const [l, p] of bad) {
      const ty = l.startsWith('push') ? 'push' : l.startsWith('review') ? 'pull_request_review' : 'pull_request';
      const r = await run(ty, p).then((x) => `${x.outcome}/${x.reason}`, (e) => `ECCEZIONE ${(e as Error).message.slice(0, 60)}`);
      console.log(`[nota] ${l}: ${r}`);
    }
  });

  it('maiuscole diverse tra owner.login, full_name e URL sono coerenti', async () => {
    const r = await run('push', pushEvent({ owner: { login: 'SBotz17' }, full_name: 'sbotz17/R1', html_url: 'https://github.com/SBOTZ17/r1', name: 'r1' }));
    expect(r.outcome).toBe('creato');
  });
});
