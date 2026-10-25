import { createHmac } from 'crypto';
import { authenticateWebhook } from '../lib/authenticate';
import { verifySignature } from '../lib/hmac';
import { APP_SECRET_NAME, PRIMARY_SECRET_NAME, SecretReader, WebhookSecrets, createWebhookSecrets } from '../lib/secrets';

const OLD = 'segreto-storico-per-repository-0123456789';
const NEW = 'segreto-della-github-app-9876543210';
const BODY = Buffer.from('{"ref":"refs/heads/feature/T-3-x","created":true}');

const sign = (secret: string, body: Buffer = BODY): string =>
  'sha256=' + createHmac('sha256', secret).update(body).digest('hex');

function secretsOf(opts: {
  primary?: string | Error;
  app?: string | null | Error;
}): WebhookSecrets & { calls: { primary: number; app: number } } {
  const calls = { primary: 0, app: 0 };
  return {
    calls,
    async getPrimary() {
      calls.primary++;
      const p = opts.primary ?? OLD;
      if (p instanceof Error) throw p;
      return p;
    },
    async getApp() {
      calls.app++;
      const a = opts.app === undefined ? NEW : opts.app;
      if (a instanceof Error) throw a;
      return a;
    },
  };
}

describe('authenticateWebhook — due segreti (T-20)', () => {
  it('accepts a signature made with the historical per-repository secret', async () => {
    const s = secretsOf({});
    expect(await authenticateWebhook(BODY, sign(OLD), s)).toEqual({ ok: true, source: 'webhook' });
  });

  it('does not even read the GitHub App secret when the historical one matches (current path unchanged)', async () => {
    const s = secretsOf({});
    await authenticateWebhook(BODY, sign(OLD), s);
    expect(s.calls.app).toBe(0);
  });

  it('accepts a signature made with the GitHub App secret', async () => {
    const s = secretsOf({});
    expect(await authenticateWebhook(BODY, sign(NEW), s)).toEqual({ ok: true, source: 'github-app' });
  });

  it('rejects a signature made with an unknown secret (401)', async () => {
    const r = await authenticateWebhook(BODY, sign('altro-segreto'), secretsOf({}));
    expect(r).toMatchObject({ ok: false, status: 401 });
  });

  it('rejects a valid signature of a different body (401)', async () => {
    const r = await authenticateWebhook(Buffer.from('{"altro":1}'), sign(NEW), secretsOf({}));
    expect(r).toMatchObject({ ok: false, status: 401 });
  });

  it('rejects a missing signature (401) without reading any secret', async () => {
    const s = secretsOf({});
    expect(await authenticateWebhook(BODY, undefined, s)).toMatchObject({ ok: false, status: 401 });
    expect(await authenticateWebhook(BODY, '', s)).toMatchObject({ ok: false, status: 401 });
    expect(s.calls.primary + s.calls.app).toBe(0);
  });

  it('rejects a signature without the sha256= prefix (401)', async () => {
    const raw = createHmac('sha256', NEW).update(BODY).digest('hex');
    expect(await authenticateWebhook(BODY, raw, secretsOf({}))).toMatchObject({ ok: false, status: 401 });
  });

  it('works with only the historical secret while the App secret does not exist yet', async () => {
    const s = secretsOf({ app: null });
    expect(await authenticateWebhook(BODY, sign(OLD), s)).toEqual({ ok: true, source: 'webhook' });
    // un evento firmato col segreto (futuro) dell'App non passa finche' il segreto non esiste
    expect(await authenticateWebhook(BODY, sign(NEW), s)).toMatchObject({ ok: false, status: 401 });
  });

  it('never accepts a signature computed with an EMPTY key', async () => {
    const emptyKeySig = sign('');
    expect(await authenticateWebhook(BODY, emptyKeySig, secretsOf({ app: '' }))).toMatchObject({ ok: false, status: 401 });
    expect(verifySignature(BODY, emptyKeySig, '')).toBe(false);
  });

  it('returns 500 when the historical secret cannot be loaded', async () => {
    const r = await authenticateWebhook(BODY, sign(OLD), secretsOf({ primary: new Error('boom') }));
    expect(r).toMatchObject({ ok: false, status: 500 });
  });

  it('returns 500 (not 401) when the App secret cannot be loaded and the historical one does not match', async () => {
    const r = await authenticateWebhook(BODY, sign(NEW), secretsOf({ app: new Error('permission denied') }));
    expect(r).toMatchObject({ ok: false, status: 500 });
  });

  it('keeps accepting the historical secret even if reading the App secret would fail', async () => {
    const r = await authenticateWebhook(BODY, sign(OLD), secretsOf({ app: new Error('permission denied') }));
    expect(r).toEqual({ ok: true, source: 'webhook' });
  });

  it('never puts a secret or a signature in the failure reason', async () => {
    const r = await authenticateWebhook(BODY, sign('altro'), secretsOf({}));
    expect(JSON.stringify(r)).not.toContain(OLD);
    expect(JSON.stringify(r)).not.toContain(NEW);
    expect(JSON.stringify(r)).not.toContain(sign('altro'));
  });
});

describe('createWebhookSecrets (cache e lettura)', () => {
  function reader(values: Record<string, string | null | Error>, counter: Record<string, number> = {}): SecretReader {
    return async (name) => {
      counter[name] = (counter[name] ?? 0) + 1;
      const v = values[name];
      if (v instanceof Error) throw v;
      return v === undefined ? null : v;
    };
  }

  it('strips trailing newlines from the App secret only', async () => {
    const s = createWebhookSecrets(reader({ [PRIMARY_SECRET_NAME]: OLD + '\n', [APP_SECRET_NAME]: NEW + '\r\n' }));
    expect(await s.getApp()).toBe(NEW);
    expect(await s.getPrimary()).toBe(OLD + '\n'); // comportamento storico: nessun ritocco
  });

  it('treats a missing or empty App secret as absent', async () => {
    expect(await createWebhookSecrets(reader({ [PRIMARY_SECRET_NAME]: OLD })).getApp()).toBeNull();
    expect(await createWebhookSecrets(reader({ [PRIMARY_SECRET_NAME]: OLD, [APP_SECRET_NAME]: '\n' })).getApp()).toBeNull();
  });

  it('throws when the historical secret is missing or empty', async () => {
    await expect(createWebhookSecrets(reader({})).getPrimary()).rejects.toThrow();
    await expect(createWebhookSecrets(reader({ [PRIMARY_SECRET_NAME]: '' })).getPrimary()).rejects.toThrow();
  });

  it('caches a found secret, and re-reads a missing one only after the short delay', async () => {
    let t = 0;
    const counter: Record<string, number> = {};
    const values: Record<string, string | null> = { [PRIMARY_SECRET_NAME]: OLD, [APP_SECRET_NAME]: null };
    const s = createWebhookSecrets(reader(values, counter), () => t);

    await s.getPrimary();
    await s.getPrimary();
    expect(counter[PRIMARY_SECRET_NAME]).toBe(1);

    expect(await s.getApp()).toBeNull();
    values[APP_SECRET_NAME] = NEW; // Andrea crea il segreto
    t = 60_000;
    expect(await s.getApp()).toBeNull(); // ancora la copia "assente"
    t = 3 * 60_000;
    expect(await s.getApp()).toBe(NEW); // riletto
  });

  it('propagates read errors other than "not found"', async () => {
    const s = createWebhookSecrets(reader({ [PRIMARY_SECRET_NAME]: OLD, [APP_SECRET_NAME]: new Error('unavailable') }));
    await expect(s.getApp()).rejects.toThrow('unavailable');
  });
});
