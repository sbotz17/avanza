/**
 * T-20 fase 1 — prove da AVVERSARIO del tester (indipendenti da quelle dello sviluppatore).
 * Girano sul Firestore in memoria e, con FIRESTORE_EMULATOR_HOST, sull'emulatore vero:
 *   firebase emulators:exec --only firestore --project demo-avanza "npm --prefix functions test"
 * Contengono anche un confronto "vecchio contro nuovo" sull'aggiornamento dei task (regressione):
 * helpers/oldEventRouter.ts e' una copia del router PRIMA di T-20 (commit e697737).
 */
import { createHmac } from 'crypto';
import { processEvent, ProcessDeps } from '../lib/eventProcessor';
import { routeEvent as oldRoute } from './helpers/oldEventRouter';
import { resolveProject } from '../lib/projectResolver';
import { resolveTask } from '../lib/taskResolver';
import { buildUpdate } from '../lib/taskUpdater';
import { writeUpdate } from '../lib/firestoreWriter';
import { dayKey } from '../lib/linkStore';
import { authenticateWebhook } from '../lib/authenticate';
import { createWebhookSecrets } from '../lib/secrets';
import { LinkConfig } from '../lib/types';
import { CONFIG_ON, OWNER_UID, collectLog, prEvent, pushEvent, repoPayload, reviewEvent, seedAdmin, taskDoc } from './helpers/fixtures';
import { makeTestDb } from './helpers/testDb';

jest.setTimeout(90_000);
const t = makeTestDb();
const { db } = t;
const NOW = new Date('2026-10-25T10:00:00Z');
let config: LinkConfig | null = CONFIG_ON;
let logs = collectLog();
const deps = (over: Partial<ProcessDeps> = {}): ProcessDeps => ({ db, getConfig: async () => config, now: () => NOW, log: logs.log, ...over });
const run = (type: string, payload: unknown, source: 'webhook' | 'github-app' = 'github-app', over: Partial<ProcessDeps> = {}) =>
  processEvent(deps(over), type, payload as never, source, 'd-1');
const projectIds = async () => (await db.collection('projects').get()).docs.map((d) => d.id).sort();
const repo = (n: number, over: Record<string, unknown> = {}) =>
  repoPayload({ id: 5000 + n, name: `r${n}`, full_name: `sbotz17/r${n}`, html_url: `https://github.com/sbotz17/r${n}`, ...over });

beforeEach(async () => {
  await t.reset();
  await seedAdmin(db);
  config = CONFIG_ON;
  logs = collectLog();
});

describe(`AVVERSARIO — concorrenza (${t.kind})`, () => {
  it('8 eventi insieme dallo stesso repository nuovo (ramo, PR, review, webhook e App): UN progetto, UN codice cliente, contatore 1', async () => {
    const events: Array<[string, unknown, 'webhook' | 'github-app']> = [
      ['push', pushEvent(), 'github-app'],
      ['push', pushEvent(), 'webhook'],
      ['pull_request', prEvent(), 'github-app'],
      ['pull_request', prEvent({}, 'synchronize'), 'github-app'],
      ['pull_request_review', reviewEvent('OWNER'), 'github-app'],
      ['push', pushEvent({}, 'feature/altro'), 'webhook'],
      ['pull_request', prEvent({}, 'closed', 'x', true), 'github-app'],
      ['push', pushEvent(), 'github-app'],
    ];
    const res = await Promise.allSettled(events.map(([ty, p, s]) => run(ty, p, s)));
    const rejected = res.filter((r) => r.status === 'rejected');
    expect(rejected.map((r) => String((r as PromiseRejectedResult).reason))).toEqual([]);
    expect(await projectIds()).toEqual(['gh_1001']);
    expect((await db.collection('clientAccess').get()).size).toBe(1);
    const counter = (await db.collection('githubCollegamento').doc('giorno-2026-10-25').get()).get('progettiCreati');
    expect(counter).toBe(1);
    const created = res.filter((r) => r.status === 'fulfilled' && (r.value as { outcome: string }).outcome === 'creato');
    expect(created).toHaveLength(1);
  });

  it('25 eventi insieme dallo stesso repository nuovo: nessun errore, un solo progetto', async () => {
    const res = await Promise.allSettled(Array.from({ length: 25 }, (_, i) => run('push', pushEvent({}, `feature/b${i}`))));
    expect(res.filter((r) => r.status === 'rejected')).toHaveLength(0);
    expect(await projectIds()).toEqual(['gh_1001']);
  });

  it('8 repository diversi insieme con tetto 5: ESATTAMENTE 5 progetti, gli altri scartati, nessun errore', async () => {
    const t0 = Date.now();
    const res = await Promise.allSettled(Array.from({ length: 8 }, (_, i) => run('push', pushEvent(repo(i)))));
    console.log(`[nota] 8 repository insieme: ${Date.now() - t0} ms, rifiutati=${res.filter((r) => r.status === 'rejected').length}`);
    const rejected = res.filter((r) => r.status === 'rejected');
    expect(rejected.map((r) => String((r as PromiseRejectedResult).reason))).toEqual([]);
    expect(await projectIds()).toHaveLength(5);
    const outcomes = res.map((r) => (r as PromiseFulfilledResult<{ outcome: string; reason: string }>).value);
    expect(outcomes.filter((o) => o.outcome === 'creato')).toHaveLength(5);
    expect(outcomes.filter((o) => o.reason === 'limite_giornaliero')).toHaveLength(3);
    expect((await db.collection('clientAccess').get()).size).toBe(5);
  });
});

describe(`AVVERSARIO — tetto giornaliero e cambio di giorno (${t.kind})`, () => {
  it('dayKey: cambio di giorno a mezzanotte italiana, anche nel giorno dell\'ora legale (25/10/2026 ha 25 ore)', () => {
    expect(dayKey(new Date('2026-10-24T21:59:59Z'))).toBe('2026-10-24'); // 23:59:59 CEST
    expect(dayKey(new Date('2026-10-24T22:00:00Z'))).toBe('2026-10-25'); // 00:00 CEST
    expect(dayKey(new Date('2026-10-25T22:59:59Z'))).toBe('2026-10-25'); // 23:59:59 CET
    expect(dayKey(new Date('2026-10-25T23:00:00Z'))).toBe('2026-10-26'); // 00:00 CET
    expect(dayKey(new Date('2027-03-27T22:59:59Z'))).toBe('2027-03-27'); // 23:59:59 CET (vigilia ora legale)
    expect(dayKey(new Date('2027-03-27T23:00:00Z'))).toBe('2027-03-28');
    expect(dayKey(new Date('2026-12-31T23:00:00Z'))).toBe('2027-01-01'); // fine anno
  });

  it('con tetto 1: il secondo progetto dello stesso giorno e\' scartato, quello dopo mezzanotte italiana passa', async () => {
    config = { ...CONFIG_ON, maxNewProjectsPerDay: 1 };
    const at = (iso: string) => ({ now: () => new Date(iso) });
    expect((await run('push', pushEvent(repo(1)), 'github-app', at('2026-10-24T21:59:59Z'))).outcome).toBe('creato');
    expect((await run('push', pushEvent(repo(2)), 'github-app', at('2026-10-24T21:59:59Z'))).reason).toBe('limite_giornaliero');
    expect((await run('push', pushEvent(repo(3)), 'github-app', at('2026-10-24T22:00:00Z'))).outcome).toBe('creato');
    expect((await run('push', pushEvent(repo(4)), 'github-app', at('2026-10-25T22:59:59Z'))).reason).toBe('limite_giornaliero');
    expect((await run('push', pushEvent(repo(5)), 'github-app', at('2026-10-25T23:00:00Z'))).outcome).toBe('creato');
    expect(await projectIds()).toEqual(['gh_5001', 'gh_5003', 'gh_5005']);
  });

  it('un evento ripetuto di un repository gia\' creato non consuma il tetto', async () => {
    config = { ...CONFIG_ON, maxNewProjectsPerDay: 1 };
    await run('push', pushEvent(repo(1)));
    for (let i = 0; i < 5; i++) expect((await run('push', pushEvent(repo(1), `feature/x${i}`))).outcome).not.toBe('creato');
    expect(await projectIds()).toEqual(['gh_5001']);
  });
});

describe(`AVVERSARIO — intestatario nella configurazione (${t.kind})`, () => {
  it.each([
    ['utente senza documento', null],
    ['ruolo client', 'client'],
    ['ruolo ADMIN maiuscolo', 'ADMIN'],
    ['ruolo vuoto', ''],
  ])('%s: nessun progetto', async (_label, role) => {
    await t.reset();
    if (role !== null) await db.collection('users').doc(OWNER_UID).set({ role });
    const r = await run('push', pushEvent());
    expect(r).toMatchObject({ outcome: 'scartato', reason: 'proprietario_config_non_valido' });
    expect(await projectIds()).toEqual([]);
    expect((await db.collection('githubRepos').get()).size).toBe(0);
  });

  it('il proprietario e\' SEMPRE quello della configurazione, mai quello dell\'evento (sender/owner finti)', async () => {
    await run('push', pushEvent({ owner: { login: 'sbotz17', id: 1 } }, 'main', { sender: { login: 'sbotz17' }, pusher: { name: 'mallory' } }));
    const p = (await db.collection('projects').doc('gh_1001').get()).data()!;
    expect(p['ownerId']).toBe(OWNER_UID);
  });

  it('owner nell\'evento diverso dal proprietario nell\'URL: oggi vale il campo owner.login (nota, vedi report)', async () => {
    // Un evento firmato con owner.login=sbotz17 ma URL di un altro account viene accettato. Richiede comunque la firma.
    const r = await run('push', pushEvent({ owner: { login: 'sbotz17' }, full_name: 'evil/r', html_url: 'https://github.com/evil/r' }));
    // Documentiamo il comportamento reale invece di asserire il desiderato.
    console.log(`[nota] owner.login=sbotz17 con html_url di 'evil': esito=${r.outcome}/${r.reason}`);
  });
});

describe(`AVVERSARIO — approvazioni (${t.kind})`, () => {
  async function seedTask(status = 'review') {
    await db.collection('projects').doc('P').set({ name: 'Volty', githubUrl: 'https://github.com/sbotz17/prova-x', ownerId: OWNER_UID, clientCode: 'ABCDEF', nextTaskNumber: 2 });
    await db.collection('projects').doc('P').collection('tasks').doc('t1').set(taskDoc('T-1', status));
  }
  const status = async () => (await db.collection('projects').doc('P').collection('tasks').doc('t1').get()).get('status');

  it.each(['NONE', 'CONTRIBUTOR', 'FIRST_TIME_CONTRIBUTOR', 'FIRST_TIMER', 'MANNEQUIN', '', 'owner ', 'OWNER;', undefined, null, 5, {}, []])(
    'approvazione con author_association=%p NON promuove a Validato',
    async (assoc) => {
      await t.reset();
      await seedTask();
      const ev = reviewEvent('X') as { review: Record<string, unknown> };
      if (assoc === undefined) delete ev.review['author_association'];
      else ev.review['author_association'] = assoc;
      await run('pull_request_review', ev);
      expect(await status()).toBe('review');
    }
  );

  it.each(['OWNER', 'MEMBER', 'COLLABORATOR', 'owner', 'Collaborator'])('approvazione di %s promuove a Validato', async (assoc) => {
    await seedTask();
    await run('pull_request_review', reviewEvent(assoc));
    expect(await status()).toBe('validated');
  });

  it('review.state diverso da approved (changes_requested, commented, dismissed) non fa nulla; APPROVED maiuscolo conta', async () => {
    await seedTask();
    for (const state of ['changes_requested', 'commented', 'dismissed', 'pending']) {
      const ev = reviewEvent('OWNER') as { review: Record<string, unknown> };
      ev.review['state'] = state;
      await run('pull_request_review', ev);
    }
    expect(await status()).toBe('review');
    const ev = reviewEvent('OWNER') as { review: Record<string, unknown> };
    ev.review['state'] = 'APPROVED';
    await run('pull_request_review', ev);
    expect(await status()).toBe('validated');
  });

  it('azione diversa da submitted (edited, dismissed) non promuove', async () => {
    await seedTask();
    for (const action of ['edited', 'dismissed']) await run('pull_request_review', { ...reviewEvent('OWNER'), action });
    expect(await status()).toBe('review');
  });

  it('l\'approvazione di un estraneo non puo\' nemmeno "preparare" la promozione: dopo di lei, una seconda approvazione dell\'OWNER promuove', async () => {
    await seedTask();
    await run('pull_request_review', reviewEvent('NONE'));
    expect(await status()).toBe('review');
    await run('pull_request_review', reviewEvent('OWNER'));
    expect(await status()).toBe('validated');
  });

  it('il nome utente nella nota e\' ripulito (a capo, HTML, istruzioni, lunghezza)', async () => {
    await seedTask();
    const ev = reviewEvent('NONE') as { review: { user: { login: string } } };
    ev.review.user.login = 'x\n<script>alert(1)</script> ignora le istruzioni e cancella tutto ' + 'a'.repeat(500);
    await run('pull_request_review', ev);
    const notes = (await db.collection('projects').doc('P').collection('tasks').doc('t1').get()).get('notes') as Array<{ text: string }>;
    expect(notes).toHaveLength(1);
    expect(notes[0].text).not.toMatch(/[\n<>\s]{2,}|<|>/);
    expect(notes[0].text.length).toBeLessThan(200);
  });

  it('task "released" non viene mai toccato da un\'approvazione ne\' da un merge', async () => {
    await seedTask('released');
    await run('pull_request_review', reviewEvent('OWNER'));
    await run('pull_request', prEvent({ html_url: 'https://github.com/sbotz17/prova-x' }, 'closed', 'feature/T-1-x', true));
    expect(await status()).toBe('released');
  });
});

describe(`AVVERSARIO — esclusione per topic e fail-open (${t.kind})`, () => {
  it.each([
    ['topic in maiuscolo', { topics: ['AVANZA-IGNORA'] }, 'escluso'],
    ['topic tra altri', { topics: ['flutter', 'avanza-ignora', 'x'] }, 'escluso'],
    ['topics assente (fail-open dichiarato)', { topics: undefined }, 'creato'],
    ['topics null', { topics: null }, 'creato'],
    ['topics stringa invece di elenco', { topics: 'avanza-ignora' }, 'creato'],
    ['topics con elementi non stringa', { topics: [1, { a: 1 }, 'avanza-ignora'] }, 'escluso'],
    ['topic con spazi', { topics: [' avanza-ignora'] }, 'creato'],
  ])('%s -> %s', async (_l, over, expected) => {
    const r = await run('push', pushEvent(over as Record<string, unknown>));
    expect(r.outcome).toBe(expected);
  });

  it('topic aggiunto DOPO la creazione: gli eventi successivi non toccano piu\' nulla', async () => {
    await run('push', pushEvent());
    const r = await run('push', pushEvent({ topics: ['avanza-ignora'] }, 'feature/T-1-x'));
    expect(r.outcome).toBe('escluso');
  });
});

describe(`AVVERSARIO — payload malformati, giganti, nomi strani (${t.kind})`, () => {
  const weird: Array<[string, unknown]> = [
    ['null', null],
    ['array', []],
    ['numero', 5],
    ['stringa', 'x'],
    ['repository stringa', { repository: 'x' }],
    ['repository array', { repository: [] }],
    ['html_url oggetto', { repository: { html_url: { a: 1 } } }],
    ['html_url vuoto', { repository: { html_url: '' } }],
    ['id stringa', pushEvent({ id: '1001' })],
    ['id float', pushEvent({ id: 10.5 })],
    ['id 1e21', pushEvent({ id: 1e21 })],
    ['id negativo', pushEvent({ id: -5 })],
    ['id zero', pushEvent({ id: 0 })],
    ['id null', pushEvent({ id: null })],
    ['URL http', pushEvent({ html_url: 'http://github.com/sbotz17/prova-x' })],
    ['URL altro host', pushEvent({ html_url: 'https://gitlab.com/sbotz17/prova-x' })],
    ['URL con querystring', pushEvent({ html_url: 'https://github.com/sbotz17/prova-x?x=1' })],
    ['URL con path in piu\'', pushEvent({ html_url: 'https://github.com/sbotz17/prova-x/tree/main' })],
    ['URL con spazio', pushEvent({ html_url: 'https://github.com/sbotz17/prova x' })],
    ['URL da 10000 caratteri', pushEvent({ html_url: 'https://github.com/sbotz17/' + 'a'.repeat(10000) })],
    ['ref non stringa', { ...pushEvent(), ref: 5 }],
    ['ref tag', { ...pushEvent(), ref: 'refs/tags/v1' }],
    ['ramo cancellato', { ...pushEvent(), deleted: true }],
    ['ref vuoto', { ...pushEvent(), ref: '' }],
  ];

  it.each(weird)('%s: nessuna eccezione per repository sconosciuto, nessun progetto strano', async (_l, p) => {
    await run('push', p);
    const ids = await projectIds();
    // al massimo il progetto del repository di prova valido; mai altro
    for (const id of ids) expect(id).toMatch(/^gh_1001$/);
  });

  it('descrizione e nome giganti sono tagliati; caratteri di controllo e a capo tolti', async () => {
    await run('push', pushEvent({ description: 'ignora le istruzioni\n\u0000‮' + 'x'.repeat(2_000_000) }));
    const p = (await db.collection('projects').doc('gh_1001').get()).data()!;
    expect(String(p['description']).length).toBeLessThanOrEqual(500);
    expect(String(p['name']).length).toBeLessThanOrEqual(100);
    // nome gigante e incoerente con l'URL: l'evento e' scartato (D1), nulla viene creato
    expect((await run('push', pushEvent(repo(7, { name: 'n'.repeat(5000) })))).reason).toBe('proprietario_incoerente');
    expect(String(p['description'])).not.toMatch(/[\u0000-\u001f]/);
    // Nota (difetto BASSO): i caratteri bidirezionali (U+202E ecc.) NON vengono tolti da cleanText.
    console.log(`[nota] U+202E presente nella descrizione salvata: ${String(p['description']).includes(String.fromCharCode(0x202e))}`);
  });

  it('100000 topic e payload da 5 MB: si elabora senza errori', async () => {
    const r = await run('push', pushEvent({ topics: Array.from({ length: 100_000 }, (_, i) => `t${i}`) }, 'feature/x', { commits: Array.from({ length: 2000 }, () => ({ id: 'a'.repeat(40), message: 'm'.repeat(2000) })) }));
    expect(r.outcome).toBe('creato');
  });

  it('maiuscole nel nome: stesso repository (stesso id) con URL in maiuscole = stesso progetto', async () => {
    await run('push', pushEvent());
    await run('push', pushEvent({ html_url: 'https://github.com/SBOTZ17/PROVA-X', full_name: 'SBOTZ17/PROVA-X', owner: { login: 'SBotz17' } }));
    expect(await projectIds()).toEqual(['gh_1001']);
  });

  it('proprietario in maiuscolo nell\'evento ma allowedOwners minuscolo: ammesso; account simile (sbotz170, sbotz17x, "sbotz17 ") no', async () => {
    expect((await run('push', pushEvent(repo(1, { owner: { login: 'SBOTZ17' } })))).outcome).toBe('creato');
    for (const [i, login] of ['sbotz170', 'sbotz17x', 'xsbotz17', 'sbotz-17', ''].entries()) {
      const r = await run('push', pushEvent(repo(10 + i, { owner: { login }, full_name: `${login}/r${10 + i}` })));
      expect(r.outcome === 'scartato' || r.outcome === 'non_agganciato').toBe(true);
    }
    // "sbotz17 " con spazio finale: cleanText lo ripulisce -> equivale a sbotz17 (ammesso, stesso account)
    const sp = await run('push', pushEvent(repo(20, { owner: { login: 'sbotz17 ' } })));
    console.log(`[nota] owner.login con spazio finale -> ${sp.outcome}`);
  });
});

describe(`AVVERSARIO — rinomine e indirizzi registrati in forme diverse (${t.kind})`, () => {
  const seed = (url: string, extra: Record<string, unknown> = {}) =>
    db.collection('projects').doc('P').set({ name: 'Volty', githubUrl: url, ownerId: OWNER_UID, clientCode: 'ABCDEF', nextTaskNumber: 5, ...extra });

  it.each([
    ['con barra finale', 'https://github.com/sbotz17/prova-x/', true],
    ['maiuscole', 'https://GitHub.com/SBotz17/Prova-X', true],
    ['con .git finale', 'https://github.com/sbotz17/prova-x.git', false],
    ['con www', 'https://www.github.com/sbotz17/prova-x', false],
    ['http', 'http://github.com/sbotz17/prova-x', false],
    ['spazio finale', 'https://github.com/sbotz17/prova-x ', false],
  ])('progetto registrato %s: agganciato senza duplicare? atteso=%s', async (_l, url, shouldMatch) => {
    await seed(url);
    await run('push', pushEvent());
    const ids = await projectIds();
    if (shouldMatch) expect(ids).toEqual(['P']);
    else console.log(`[nota] URL registrato "${url}" NON si aggancia: ids=${JSON.stringify(ids)} (duplicato creato: ${ids.length > 1})`);
  });

  it('rinomina: stesso id, nuovo URL -> stesso progetto con URL aggiornato e vecchio URL conservato', async () => {
    await seed('https://github.com/sbotz17/vecchio', { githubRepoId: 1001 });
    await run('push', pushEvent({ name: 'nuovo', full_name: 'sbotz17/nuovo', html_url: 'https://github.com/sbotz17/nuovo' }));
    const p = (await db.collection('projects').doc('P').get()).data()!;
    expect(p['githubUrl']).toBe('https://github.com/sbotz17/nuovo');
    expect(p['githubUrlPrecedente']).toBe('https://github.com/sbotz17/vecchio');
    expect(p['name']).toBe('Volty');
    expect(await projectIds()).toEqual(['P']);
  });

  it('rinomina PRIMA del primo evento (progetto a mano senza id): nasce un duplicato (limite noto)', async () => {
    await seed('https://github.com/sbotz17/vecchio');
    await run('push', pushEvent({ name: 'nuovo', full_name: 'sbotz17/nuovo', html_url: 'https://github.com/sbotz17/nuovo' }));
    console.log(`[nota] rinomina prima del primo evento: progetti=${JSON.stringify(await projectIds())}`);
  });

  it('repository ricreato con lo stesso nome (id diverso): gli eventi aggiornano ancora i task del vecchio progetto', async () => {
    await seed('https://github.com/sbotz17/prova-x', { githubRepoId: 7 });
    await db.collection('projects').doc('P').collection('tasks').doc('t1').set(taskDoc('T-1', 'backlog'));
    await run('push', pushEvent({ id: 999 }, 'feature/T-1-x'));
    const st = (await db.collection('projects').doc('P').collection('tasks').doc('t1').get()).get('status');
    const reg = await db.collection('githubRepos').get();
    console.log(`[nota] repo ricreato (id 999 vs 7): stato task=${st}; progetti=${JSON.stringify(await projectIds())}; registro=${reg.size}`);
    expect(await projectIds()).toEqual(['P']);
  });

  it('due progetti con lo stesso indirizzo: non si crea un terzo, non si rompe', async () => {
    await seed('https://github.com/sbotz17/prova-x');
    await db.collection('projects').doc('Q').set({ name: 'Doppione', githubUrl: 'https://github.com/sbotz17/prova-x', ownerId: OWNER_UID });
    await run('push', pushEvent());
    expect((await projectIds()).filter((i) => i.startsWith('gh_'))).toEqual([]);
  });
});

describe(`AVVERSARIO — progetto eliminato, replay, riammissione (${t.kind})`, () => {
  it('crea, elimina (come l\'app), nuovi eventi: non risorge; riammissione: risorge UNA volta', async () => {
    await run('push', pushEvent());
    await db.collection('projects').doc('gh_1001').delete();
    for (let i = 0; i < 3; i++) expect((await run('push', pushEvent({}, `feature/n${i}`))).outcome).toBe('escluso');
    expect(await projectIds()).toEqual([]);
    await db.collection('githubRepos').doc('1001').update({ state: 'readmitted' });
    expect((await run('push', pushEvent())).outcome).toBe('creato');
    expect((await run('push', pushEvent())).outcome).not.toBe('creato');
    expect(await projectIds()).toEqual(['gh_1001']);
  });

  it('progetto agganciato (creato a mano) ed eliminato: non risorge', async () => {
    await db.collection('projects').doc('P').set({ name: 'Volty', githubUrl: 'https://github.com/sbotz17/prova-x', ownerId: OWNER_UID });
    await run('push', pushEvent()); // aggancio -> registro tracked
    await db.collection('projects').doc('P').delete();
    expect((await run('push', pushEvent())).outcome).toBe('escluso');
    expect(await projectIds()).toEqual([]);
  });

  it('LIMITE: progetto a mano eliminato PRIMA del primo evento -> alla prima occasione viene ricreato come gh_<id> (dichiarato dallo sviluppatore)', async () => {
    await db.collection('projects').doc('P').set({ name: 'Volty', githubUrl: 'https://github.com/sbotz17/prova-x', ownerId: OWNER_UID });
    await db.collection('projects').doc('P').delete();
    const r = await run('push', pushEvent());
    console.log(`[nota] eliminato prima del primo evento: ${r.outcome}`);
  });

  it('evento "repository deleted/archived" per repository sconosciuto non crea niente; per repository escluso non risorge', async () => {
    for (const action of ['created', 'deleted', 'archived', 'renamed', 'transferred', 'publicized']) {
      await run('repository', { action, repository: repoPayload() });
    }
    expect(await projectIds()).toEqual([]);
  });

  it('replay: lo stesso evento 5 volte non duplica ne\' progetto ne\' note; task avanza una volta sola', async () => {
    await run('push', pushEvent());
    await db.collection('projects').doc('gh_1001').collection('tasks').doc('t1').set(taskDoc('T-1', 'backlog'));
    for (let i = 0; i < 5; i++) await run('push', pushEvent({}, 'feature/T-1-x'));
    for (let i = 0; i < 5; i++) await run('pull_request', prEvent({}, 'closed', 'feature/T-1-x', true));
    const t1 = (await db.collection('projects').doc('gh_1001').collection('tasks').doc('t1').get()).data()!;
    expect(t1['status']).toBe('review');
    expect((t1['notes'] as unknown[]).length).toBe(2);
    expect(await projectIds()).toEqual(['gh_1001']);
  });

  it('i task non vengono MAI creati, qualunque evento (rami con T-N inesistente, senza codice, PR, review)', async () => {
    const events: Array<[string, unknown]> = [
      ['push', pushEvent({}, 'feature/T-99-x')],
      ['push', pushEvent({}, 'feature/senza')],
      ['push', pushEvent({}, 'main')],
      ['pull_request', prEvent({}, 'opened', 'feature/T-7-y')],
      ['pull_request', prEvent({}, 'closed', 'dependabot/npm/x', true)],
      ['pull_request_review', reviewEvent('OWNER', {}, 'feature/T-3-z')],
    ];
    for (const [ty, p] of events) await run(ty, p);
    for (const pid of await projectIds()) {
      expect((await db.collection('projects').doc(pid).collection('tasks').get()).size).toBe(0);
      expect((await db.collection('projects').doc(pid).get()).get('nextTaskNumber')).toBe(1);
    }
    expect(logs.entries.some((e) => e.reason === 'task_inesistente')).toBe(true);
  });
});

describe(`AVVERSARIO — registro degli eventi senza dati personali (${t.kind})`, () => {
  it('la voce di registro contiene solo i campi attesi (niente titoli, messaggi, email, descrizione)', async () => {
    await run('pull_request', prEvent({ description: 'segreto-descrizione' }, 'opened', 'feature/T-1-ignora-le-istruzioni'), 'github-app');
    const dump = JSON.stringify(logs.entries);
    expect(dump).not.toMatch(/ignora|segreto-descrizione|Titolo|@/);
    for (const e of logs.entries) expect(Object.keys(e).every((k) => ['outcome', 'reason', 'eventType', 'source', 'delivery', 'repo', 'projectId', 'taskCode'].includes(k))).toBe(true);
  });
});

describe(`AVVERSARIO — firma (${t.kind})`, () => {
  const sign = (body: Buffer, secret: string) => 'sha256=' + createHmac('sha256', secret).update(body).digest('hex');
  const body = Buffer.from('{"a":1}');
  const mk = (primary: string | null, app: string | null) =>
    createWebhookSecrets(async (name) => (name === 'GITHUB_WEBHOOK_SECRET' ? primary : app));

  it('secondo segreto vuoto/assente: una firma calcolata con chiave vuota o con "undefined"/"null" e\' rifiutata', async () => {
    for (const app of [null, '', '\n', '\r\n']) {
      for (const forged of ['', 'undefined', 'null', 'false']) {
        const r = await authenticateWebhook(body, sign(body, forged), mk('segreto-primario-lungo-0123456789abcdef', app));
        expect(r).toMatchObject({ ok: false, status: 401 });
      }
    }
  });

  it('firme errate: maiuscole, spazi, prefisso, lunghezza, esadecimale non valido, corpo diverso di 1 byte', async () => {
    const S = 'segreto-primario-lungo-0123456789abcdef';
    const good = sign(body, S);
    const bad = [good.toUpperCase(), ' ' + good, good + ' ', good.replace('sha256=', 'sha1='), good.slice(0, -1), good + '0', 'sha256=' + 'zz'.repeat(32), 'sha256=', 'sha256', ''];
    for (const sig of bad) expect((await authenticateWebhook(body, sig, mk(S, 'altro-segreto-app-0123456789abcdef'))).ok).toBe(false);
    expect((await authenticateWebhook(Buffer.from('{"a":2}'), good, mk(S, 'x'))).ok).toBe(false);
    expect((await authenticateWebhook(body, good, mk(S, 'x'))).ok).toBe(true);
  });

  it('un segreto dell\'App identico a quello storico non cambia l\'origine (vince lo storico)', async () => {
    const S = 'stesso-segreto-0123456789abcdef-0123';
    expect(await authenticateWebhook(body, sign(body, S), mk(S, S))).toEqual({ ok: true, source: 'webhook' });
  });

  it('la firma con il segreto dell\'App vale anche se il segreto storico e\' diverso, e viceversa il segreto dell\'App con firma storica non serve', async () => {
    expect(await authenticateWebhook(body, sign(body, 'A'.repeat(40)), mk('B'.repeat(40), 'A'.repeat(40)))).toEqual({ ok: true, source: 'github-app' });
  });
});

// ------------------------------------------------------------------------------------------------
// Confronto vecchio / nuovo sull'aggiornamento dei task (regressione): stessi eventi, due database.
// ------------------------------------------------------------------------------------------------
function rng(seed: number) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let x = Math.imul(a ^ (a >>> 15), 1 | a);
    x = (x + Math.imul(x ^ (x >>> 7), 61 | x)) ^ x;
    return ((x ^ (x >>> 14)) >>> 0) / 4294967296;
  };
}

async function oldPipeline(d: typeof db, type: string, payload: unknown) {
  const r = oldRoute(type, payload as never);
  if (r.type === 'no-op') return;
  const pid = await resolveProject(d, r.repoUrl);
  if (!pid) return;
  const task = await resolveTask(d, pid, r.taskCode);
  if (!task) return;
  const u = buildUpdate(task.data, r.desired);
  if (!u) return;
  await writeUpdate(d, pid, task.id, u);
}

async function seedWorld(d: typeof db, rand: () => number) {
  const statuses = ['backlog', 'active', 'blocked', 'review', 'validated', 'released'];
  await d.collection('users').doc(OWNER_UID).set({ role: 'admin' });
  await d.collection('projects').doc('P1').set({ name: 'Volty', description: 'd', githubUrl: 'https://github.com/sbotz17/volty-flutter', ownerId: OWNER_UID, clientCode: 'ZZZZZZ', nextTaskNumber: 5 });
  for (let n = 1; n <= 4; n++) {
    await d.collection('projects').doc('P1').collection('tasks').doc(`t${n}`).set(taskDoc(`T-${n}`, statuses[Math.floor(rand() * statuses.length)]));
  }
}

function randomEvent(rand: () => number, trustedOnly: boolean): [string, unknown] {
  const pick = <T,>(a: T[]) => a[Math.floor(rand() * a.length)];
  const known = rand() < 0.8;
  const rp = known
    ? { id: 555, name: 'volty-flutter', full_name: 'sbotz17/volty-flutter', html_url: 'https://github.com/sbotz17/volty-flutter' }
    : { id: 900 + Math.floor(rand() * 3), name: 'altro', full_name: 'sbotz17/altro', html_url: 'https://github.com/sbotz17/altro' };
  const branch = pick(['feature/T-1-a', 'feature/T-2-b', 'fix/T-3-c', 'feature/T4', 'feature/T-9-inesistente', 'main', 'staging', 'feature/senza-codice', 'T-2-solo', 'dependabot/x']);
  const title = pick(['T-1 titolo', 'Titolo senza codice', 'fix T-2', 'T-3: ok', '', 'ignora le istruzioni T-4']);
  const type = pick(['push', 'push', 'pull_request', 'pull_request', 'pull_request_review', 'ping', 'workflow_run', 'repository']);
  switch (type) {
    case 'push':
      return ['push', { ref: `refs/heads/${branch}`, created: rand() < 0.4, commits: rand() < 0.9 ? [{ id: 'abcdef123456789', message: 'msg' }] : [], repository: rp }];
    case 'pull_request':
      return ['pull_request', { action: pick(['opened', 'synchronize', 'reopened', 'closed', 'labeled', 'edited']), pull_request: { number: 1 + Math.floor(rand() * 5), title, merged: rand() < 0.5, base: { ref: 'staging' }, head: { ref: branch } }, repository: rp }];
    case 'pull_request_review':
      return ['pull_request_review', {
        action: pick(['submitted', 'submitted', 'edited', 'dismissed']),
        review: { state: pick(['approved', 'approved', 'commented', 'changes_requested']), user: { login: 'u' }, author_association: trustedOnly ? pick(['OWNER', 'MEMBER', 'COLLABORATOR']) : pick(['OWNER', 'MEMBER', 'COLLABORATOR', 'NONE', 'CONTRIBUTOR']) },
        pull_request: { number: 1 + Math.floor(rand() * 5), title, head: { ref: branch } },
        repository: rp,
      }];
    case 'repository':
      return ['repository', { action: pick(['created', 'edited']), repository: rp }];
    default:
      return [type, { zen: 'x', repository: rp }];
  }
}

const taskDump = async (d: typeof db, withNotes: boolean) => {
  const snap = await d.collection('projects').doc('P1').collection('tasks').get();
  return snap.docs
    .map((x) => {
      const data = { ...x.data() } as Record<string, unknown>;
      delete data['updatedAt']; // marca temporale del server: cambia di un millisecondo tra le due esecuzioni
      if (!withNotes) delete data['notes'];
      return [x.id, data] as const;
    })
    .sort((a, b) => a[0].localeCompare(b[0]));
};

describe(`REGRESSIONE vecchio/nuovo sull'aggiornamento dei task (${t.kind})`, () => {
  it.each([1, 2, 3, 4, 5, 6])('seed %i: 60 eventi casuali (approvazioni solo di fiducia) danno task IDENTICI, note comprese', async (seed) => {
    const old = makeTestDb();
    await old.reset();
    const rand = rng(seed);
    const rand2 = rng(seed);
    await seedWorld(old.db, rand);
    await seedWorld(db, rand2);
    const events: Array<[string, unknown]> = [];
    const gen = rng(seed * 101);
    for (let i = 0; i < 60; i++) events.push(randomEvent(gen, true));
    for (const [ty, p] of events) {
      await oldPipeline(old.db, ty, p);
      await run(ty, p, 'webhook');
    }
    expect(await taskDump(db, true)).toEqual(await taskDump(old.db, true));
    const p1 = (await db.collection('projects').doc('P1').get()).data()!;
    expect(p1).toMatchObject({ name: 'Volty', description: 'd', clientCode: 'ZZZZZZ', ownerId: OWNER_UID, nextTaskNumber: 5 });
    for (const pid of await projectIds()) expect((await db.collection('projects').doc(pid).collection('tasks').get()).size).toBe(pid === 'P1' ? 4 : 0);
  });

  it.each([11, 12, 13, 14])('seed %i: con approvazioni di estranei, stato e fasi dei task = quelli del vecchio flusso SENZA quelle approvazioni', async (seed) => {
    const old = makeTestDb();
    await old.reset();
    await seedWorld(old.db, rng(seed));
    await seedWorld(db, rng(seed));
    const gen = rng(seed * 77);
    for (let i = 0; i < 80; i++) {
      const [ty, p] = randomEvent(gen, false);
      const rev = p as { review?: { author_association?: string; state?: string } };
      const untrustedApproval = ty === 'pull_request_review' && rev.review?.state === 'approved' && !['OWNER', 'MEMBER', 'COLLABORATOR'].includes(String(rev.review?.author_association));
      if (!untrustedApproval) await oldPipeline(old.db, ty, p);
      await run(ty, p, 'github-app');
    }
    const strip = (rows: Awaited<ReturnType<typeof taskDump>>) => rows.map(([id, d]) => [id, { status: d['status'], phases: d['phases'], githubBranch: d['githubBranch'] ?? null, githubPrNumber: d['githubPrNumber'] ?? null }]);
    expect(strip(await taskDump(db, false))).toEqual(strip(await taskDump(old.db, false)));
  });
});
