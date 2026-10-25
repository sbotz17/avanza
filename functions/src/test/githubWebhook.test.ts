import { createHmac } from 'crypto';

const OLD = 'segreto-storico-per-repository-0123456789';
const NEW = 'segreto-della-github-app-9876543210';

const processEvent = jest.fn();
const secretState: { app: string | null; primary: string | Error } = { app: NEW, primary: OLD };

jest.mock('../lib/eventProcessor', () => ({ processEvent: (...args: unknown[]) => processEvent(...args) }));
jest.mock('../lib/secrets', () => ({
  createSecretReader: () => async () => null,
  createWebhookSecrets: () => ({
    getPrimary: async () => {
      if (secretState.primary instanceof Error) throw secretState.primary;
      return secretState.primary;
    },
    getApp: async () => secretState.app,
  }),
}));
jest.mock('firebase-admin/firestore', () => ({ getFirestore: () => ({ fake: true }) }));
jest.mock('firebase-admin/app', () => ({ getApps: () => [{}], initializeApp: () => ({}) }));

import { githubWebhookHandler } from '../githubWebhook';

const sign = (secret: string, body: Buffer) => 'sha256=' + createHmac('sha256', secret).update(body).digest('hex');

function call(opts: { method?: string; signature?: string | null; secret?: string; body?: object; event?: string }) {
  const body = Buffer.from(JSON.stringify(opts.body ?? { repository: { html_url: 'https://github.com/sbotz17/x' } }));
  const headers: Record<string, string> = { 'x-github-event': opts.event ?? 'push', 'x-github-delivery': 'abc-123' };
  const signature = opts.signature === undefined && opts.secret ? sign(opts.secret, body) : opts.signature;
  if (signature) headers['x-hub-signature-256'] = signature;
  const req = { method: opts.method ?? 'POST', headers, rawBody: body, body: JSON.parse(body.toString()) };
  const res = {
    statusCode: 0,
    payload: undefined as unknown,
    status(code: number) {
      this.statusCode = code;
      return this;
    },
    json(p: unknown) {
      this.payload = p;
      return this;
    },
  };
  return githubWebhookHandler(req as never, res as never).then(() => res);
}

beforeEach(() => {
  processEvent.mockReset();
  processEvent.mockResolvedValue({ outcome: 'ignorato', reason: 'x' });
  secretState.app = NEW;
  secretState.primary = OLD;
  jest.spyOn(console, 'error').mockImplementation(() => undefined);
});

describe('githubWebhookHandler', () => {
  it('405 for non-POST requests', async () => {
    expect((await call({ method: 'GET' })).statusCode).toBe(405);
    expect(processEvent).not.toHaveBeenCalled();
  });

  it('401 without a signature, and nothing is processed', async () => {
    const res = await call({ signature: null });
    expect(res.statusCode).toBe(401);
    expect(processEvent).not.toHaveBeenCalled();
  });

  it('401 with a wrong signature, and nothing is processed', async () => {
    const res = await call({ secret: 'altro-segreto' });
    expect(res.statusCode).toBe(401);
    expect(processEvent).not.toHaveBeenCalled();
  });

  it('200 and source "webhook" for the historical secret', async () => {
    const res = await call({ secret: OLD });
    expect(res.statusCode).toBe(200);
    expect(processEvent).toHaveBeenCalledTimes(1);
    expect(processEvent.mock.calls[0].slice(1)).toEqual(['push', expect.anything(), 'webhook', 'abc-123']);
  });

  it('200 and source "github-app" for the GitHub App secret', async () => {
    const res = await call({ secret: NEW, event: 'pull_request' });
    expect(res.statusCode).toBe(200);
    expect(processEvent.mock.calls[0][1]).toBe('pull_request');
    expect(processEvent.mock.calls[0][3]).toBe('github-app');
  });

  it('the GitHub App secret is refused while it does not exist yet', async () => {
    secretState.app = null;
    expect((await call({ secret: NEW })).statusCode).toBe(401);
    expect((await call({ secret: OLD })).statusCode).toBe(200);
  });

  it('500 (generic body) when the historical secret cannot be loaded', async () => {
    secretState.primary = new Error('permission denied for SECRET-VALUE');
    const res = await call({ secret: OLD });
    expect(res.statusCode).toBe(500);
    expect(JSON.stringify(res.payload)).not.toContain('SECRET-VALUE');
  });

  it('500 (generic body, no details) when processing fails on Firestore', async () => {
    processEvent.mockRejectedValue(new Error('dettaglio interno di firestore'));
    const res = await call({ secret: OLD });
    expect(res.statusCode).toBe(500);
    expect(res.payload).toEqual({ error: 'internal error' });
  });
});
