import { createHmac } from 'crypto';
import { makeTestDb } from './helpers/testDb';
import { OWNER_UID, pushEvent, seedAdmin, taskDoc } from './helpers/fixtures';

/**
 * Percorso completo dell'handler (firma -> configurazione letta da Firestore -> creazione / aggiornamento -> risposta),
 * senza finti per la logica: si sostituiscono solo Secret Manager e la sorgente del database di prova.
 */
const OLD = 'segreto-storico-per-repository-0123456789';
const NEW = 'segreto-della-github-app-9876543210';
const holder: { db: unknown } = { db: null };

jest.mock('../lib/secrets', () => ({
  createSecretReader: () => async () => null,
  createWebhookSecrets: () => ({ getPrimary: async () => 'segreto-storico-per-repository-0123456789', getApp: async () => 'segreto-della-github-app-9876543210' }),
}));
// L'handler chiama getFirestore() senza argomenti: quello e' il database di prova. Con argomenti (aiuto testDb per l'emulatore) vale l'originale.
jest.mock('firebase-admin/firestore', () => {
  const actual = jest.requireActual('firebase-admin/firestore');
  return { ...actual, getFirestore: (...args: unknown[]) => (args.length > 0 ? actual.getFirestore(...args) : holder.db) };
});
// getApps/initializeApp: l'handler non deve inizializzare l'app vera; l'aiuto testDb (emulatore) ha bisogno dell'originale con un nome.
jest.mock('firebase-admin/app', () => {
  const actual = jest.requireActual('firebase-admin/app');
  return { ...actual, getApps: () => [{}], initializeApp: (...args: unknown[]) => (args.length > 0 ? actual.initializeApp(...args) : {}) };
});
jest.mock('firebase-functions/v2', () => ({ logger: { info: jest.fn(), warn: jest.fn(), error: jest.fn() } }));

import { githubWebhookHandler } from '../githubWebhook';
import { resetLinkConfigCache } from '../lib/linkConfig';

// Contro l'emulatore le transazioni concorrenti (ripetute da Firestore in caso di conflitto) possono superare i 5 secondi predefiniti.
jest.setTimeout(30_000);

const t = makeTestDb();
holder.db = t.db;
const { db } = t;

function send(event: string, payload: object, secret = NEW) {
  const body = Buffer.from(JSON.stringify(payload));
  const req = {
    method: 'POST',
    headers: {
      'x-github-event': event,
      'x-github-delivery': 'd-1',
      'x-hub-signature-256': 'sha256=' + createHmac('sha256', secret).update(body).digest('hex'),
    },
    rawBody: body,
    body: JSON.parse(body.toString()),
  };
  const res = { statusCode: 0, status(c: number) { this.statusCode = c; return this; }, json() { return this; } };
  return githubWebhookHandler(req as never, res as never).then(() => res.statusCode);
}

const projects = async () => (await db.collection('projects').get()).docs.map((d) => d.id);
const writeConfig = (over: Record<string, unknown> = {}) =>
  db.collection('githubCollegamento').doc('config').set({ autoCreateProjects: true, ownerUid: OWNER_UID, allowedOwners: ['sbotz17'], maxNewProjectsPerDay: 5, ...over });

beforeEach(async () => {
  await t.reset();
  resetLinkConfigCache();
  await seedAdmin(db);
});

describe(`flusso completo dell'handler (${t.kind})`, () => {
  it('with no configuration document nothing is created (current behaviour preserved)', async () => {
    expect(await send('push', pushEvent())).toBe(200);
    expect(await projects()).toEqual([]);
  });

  it('with the configuration written by the admin script, a signed App event creates the project', async () => {
    await writeConfig();
    expect(await send('push', pushEvent())).toBe(200);
    const ids = await projects();
    expect(ids).toEqual(['gh_1001']);
    expect((await db.collection('projects').doc('gh_1001').get()).get('ownerId')).toBe(OWNER_UID);
  });

  it('a bad signature writes nothing and answers 401', async () => {
    await writeConfig();
    expect(await send('push', pushEvent(), 'segreto-sbagliato')).toBe(401);
    expect(await projects()).toEqual([]);
  });

  it('a historical per-repository webhook keeps updating tasks of existing projects', async () => {
    await db.collection('projects').doc('avanza').set({ name: 'Avanza', githubUrl: 'https://github.com/sbotz17/avanza', ownerId: OWNER_UID });
    await db.collection('projects').doc('avanza').collection('tasks').doc('t1').set(taskDoc('T-1'));
    const payload = pushEvent({ id: 55, name: 'avanza', full_name: 'sbotz17/avanza', html_url: 'https://github.com/sbotz17/avanza' }, 'feature/T-1-x');
    expect(await send('push', payload, OLD)).toBe(200);
    expect((await db.collection('projects').doc('avanza').collection('tasks').doc('t1').get()).get('status')).toBe('active');
    expect(await projects()).toEqual(['avanza']);
  });

  it('switching the switch off in the configuration document stops creation after the cache expires', async () => {
    await writeConfig();
    expect(await send('push', pushEvent())).toBe(200);
    expect(await projects()).toHaveLength(1);
    await writeConfig({ autoCreateProjects: false });
    resetLinkConfigCache(); // equivale ai 60 secondi di copia in memoria
    expect(await send('push', pushEvent({ id: 2002, name: 'altro', full_name: 'sbotz17/altro', html_url: 'https://github.com/sbotz17/altro' }))).toBe(200);
    expect(await projects()).toEqual(['gh_1001']);
  });

  it('answers 500 when Firestore fails, with a generic body', async () => {
    holder.db = { collection: () => { throw new Error('giu'); } };
    const spy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    try {
      expect(await send('push', pushEvent())).toBe(500);
    } finally {
      holder.db = t.db;
      spy.mockRestore();
    }
  });
});

describe('loadLinkConfig', () => {
  it('reads the document and keeps it for 60 seconds', async () => {
    const { loadLinkConfig } = await import('../lib/linkConfig');
    await writeConfig();
    const a = await loadLinkConfig(db, 1_000);
    expect(a?.ownerUid).toBe(OWNER_UID);
    await writeConfig({ autoCreateProjects: false });
    expect((await loadLinkConfig(db, 1_000 + 59_000))?.autoCreateProjects).toBe(true); // ancora la copia
    expect(await loadLinkConfig(db, 1_000 + 61_000)).toBeNull(); // riletta: spenta
  });
});
