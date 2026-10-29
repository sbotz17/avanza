import { Request } from 'firebase-functions/v2/https';
import { Response } from 'express';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { authenticateWebhook } from './lib/authenticate';
import { cleanDelivery } from './lib/eventLog';
import { processEvent } from './lib/eventProcessor';
import { createSecretReader, createWebhookSecrets, WebhookSecrets } from './lib/secrets';
import { GitHubPayload } from './lib/types';

// Initialize Firebase Admin once at module load (idempotent).
if (getApps().length === 0) {
  initializeApp();
}

// Segreti (Secret Manager) con copia in memoria a tempo; creati al primo uso.
let secrets: WebhookSecrets | null = null;
function getSecrets(): WebhookSecrets {
  if (!secrets) {
    secrets = createWebhookSecrets(createSecretReader(process.env.GOOGLE_CLOUD_PROJECT ?? 'avanza-b62d7'));
  }
  return secrets;
}

/**
 * Main handler for the githubWebhook Cloud Function.
 *
 * Flow:
 *  1. Reject non-POST requests (405)
 *  2. Verify HMAC-SHA256 signature against the two accepted secrets (per-repository webhook secret and GitHub App
 *     secret); 401 if invalid, 500 if a secret cannot be loaded
 *  3. processEvent (lib/eventProcessor.ts): find (or, when allowed, create) the project, find the task by T-N code,
 *     apply the business rules, write atomically; every event leaves a structured log entry
 *  4. 200 { ok: true } (500 on Firestore error)
 */
export async function githubWebhookHandler(req: Request, res: Response): Promise<void> {
  // 1. Only POST
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method not allowed' });
    return;
  }

  // 2. Verify HMAC signature
  // Firebase Functions v2 provides req.rawBody as a Buffer before JSON parsing.
  const rawBody: Buffer = (req as unknown as { rawBody: Buffer }).rawBody ?? Buffer.from(JSON.stringify(req.body));
  const signature = req.headers['x-hub-signature-256'] as string | undefined;

  const auth = await authenticateWebhook(rawBody, signature, getSecrets());
  if (!auth.ok) {
    if (auth.status === 500) console.error(`[githubWebhook] authentication unavailable: ${auth.reason}`);
    res.status(auth.status).json({ error: auth.status === 401 ? 'invalid signature' : 'internal error' });
    return;
  }

  // 3. Process the (authenticated) event
  const eventType = (req.headers['x-github-event'] as string | undefined) ?? '';
  const delivery = cleanDelivery(req.headers['x-github-delivery']);
  const payload = (req.body ?? {}) as GitHubPayload;

  try {
    await processEvent({ db: getFirestore() }, eventType, payload, auth.source, delivery);
  } catch (err) {
    console.error('[githubWebhook] Firestore error processing event:', err instanceof Error ? err.message : 'unknown');
    res.status(500).json({ error: 'internal error' });
    return;
  }

  // 4. Success
  res.status(200).json({ ok: true });
}
