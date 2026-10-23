import { Request } from 'firebase-functions/v2/https';
import { Response } from 'express';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';
import { verifySignature } from './lib/hmac';
import { resolveProject } from './lib/projectResolver';
import { routeEvent } from './lib/eventRouter';
import { resolveTask } from './lib/taskResolver';
import { buildUpdate } from './lib/taskUpdater';
import { writeUpdate } from './lib/firestoreWriter';
import { TaskSnapshot } from './lib/types';

// Initialize Firebase Admin once at module load (idempotent).
if (getApps().length === 0) {
  initializeApp();
}

// Cache the secret to avoid repeated Secret Manager calls.
let cachedWebhookSecret: string | null = null;

async function getWebhookSecret(): Promise<string> {
  if (cachedWebhookSecret) return cachedWebhookSecret;
  const projectId = process.env.GOOGLE_CLOUD_PROJECT ?? 'avanza-b62d7';
  const client = new SecretManagerServiceClient();
  const [version] = await client.accessSecretVersion({
    name: `projects/${projectId}/secrets/GITHUB_WEBHOOK_SECRET/versions/latest`,
  });
  cachedWebhookSecret = version.payload?.data?.toString() ?? '';
  return cachedWebhookSecret;
}

/**
 * Main handler for the githubWebhook Cloud Function.
 *
 * Flow:
 *  1. Reject non-POST requests (405)
 *  2. Verify HMAC-SHA256 signature (401 if invalid)
 *  3. Route event type → desired update (200 no-op if unhandled)
 *  4. Resolve project by GitHub URL (200 no-op if not found)
 *  5. Resolve task by taskCode (200 no-op if not found)
 *  6. Apply business rules (200 no-op if idempotent)
 *  7. Write to Firestore atomically (500 on Firestore error → GitHub retries)
 *  8. 200 { ok: true }
 */
export async function githubWebhookHandler(req: Request, res: Response): Promise<void> {
  // 1. Only POST
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method not allowed' });
    return;
  }

  // 2. Verify HMAC signature
  const signature = req.headers['x-hub-signature-256'] as string | undefined;
  let secret: string;
  try {
    secret = await getWebhookSecret();
  } catch (err) {
    console.error('[githubWebhook] Failed to load GITHUB_WEBHOOK_SECRET:', err);
    res.status(500).json({ error: 'internal error' });
    return;
  }

  if (!secret) {
    console.error('[githubWebhook] GITHUB_WEBHOOK_SECRET is empty');
    res.status(500).json({ error: 'internal error' });
    return;
  }

  // Firebase Functions v2 provides req.rawBody as a Buffer before JSON parsing.
  const rawBody: Buffer = (req as unknown as { rawBody: Buffer }).rawBody
    ?? Buffer.from(JSON.stringify(req.body));

  if (!signature || !verifySignature(rawBody, signature, secret)) {
    res.status(401).json({ error: 'invalid signature' });
    return;
  }

  // 3. Route event
  const eventType = (req.headers['x-github-event'] as string | undefined) ?? '';
  const delivery = (req.headers['x-github-delivery'] as string | undefined) ?? '-';
  const payload = req.body as Record<string, unknown>;

  console.info(`[githubWebhook] event=${eventType} delivery=${delivery}`);

  const routeResult = routeEvent(eventType, payload);
  if (routeResult.type === 'no-op') {
    res.status(200).json({ ok: true });
    return;
  }

  const { repoUrl, taskCode, desired } = routeResult;

  // 4. Resolve project
  const db = getFirestore();
  let projectId: string | null;
  try {
    projectId = await resolveProject(db, repoUrl);
  } catch (err) {
    console.error('[githubWebhook] Firestore error resolving project:', err);
    res.status(500).json({ error: 'internal error' });
    return;
  }

  if (!projectId) {
    console.warn(`[githubWebhook] No project found for GitHub URL: ${repoUrl}`);
    res.status(200).json({ ok: true });
    return;
  }

  // 5. Resolve task
  let taskResult: { id: string; data: TaskSnapshot } | null;
  try {
    taskResult = await resolveTask(db, projectId, taskCode);
  } catch (err) {
    console.error('[githubWebhook] Firestore error resolving task:', err);
    res.status(500).json({ error: 'internal error' });
    return;
  }

  if (!taskResult) {
    console.warn(`[githubWebhook] Task ${taskCode} not found in project ${projectId}`);
    res.status(200).json({ ok: true });
    return;
  }

  // 6. Apply business rules
  const update = buildUpdate(taskResult.data, desired);
  if (!update) {
    // Already processed (idempotent)
    res.status(200).json({ ok: true });
    return;
  }

  // 7. Write to Firestore
  try {
    await writeUpdate(db, projectId, taskResult.id, update);
  } catch (err) {
    console.error('[githubWebhook] Firestore error writing update:', err);
    res.status(500).json({ error: 'internal error' });
    return;
  }

  // 8. Success
  console.info(
    `[githubWebhook] Updated task ${taskCode} in project ${projectId}: ` +
      `status=${update.newStatus ?? 'unchanged'}`
  );
  res.status(200).json({ ok: true });
}
