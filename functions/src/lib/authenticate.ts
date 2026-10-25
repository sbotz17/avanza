import { verifySignature } from './hmac';
import { EventSource } from './types';
import { WebhookSecrets } from './secrets';

export type AuthResult =
  | { ok: true; source: EventSource }
  | { ok: false; status: 401 | 500; reason: string };

/**
 * Autentica una richiesta del webhook con la firma HMAC-SHA256 (X-Hub-Signature-256), accettando DUE segreti:
 *  1. quello storico dei webhook per-repository (provato per primo: il percorso di oggi non cambia);
 *  2. quello della GitHub App personale (provato solo se il primo non corrisponde, e solo se esiste).
 * Il confronto e' a tempo costante (verifySignature) e un segreto assente o vuoto non viene mai accettato.
 * Nessun segreto, firma o corpo finisce nei log o nei messaggi.
 */
export async function authenticateWebhook(
  rawBody: Buffer,
  signature: string | undefined,
  secrets: WebhookSecrets
): Promise<AuthResult> {
  // Senza firma non si consulta nemmeno Secret Manager.
  if (!signature) return { ok: false, status: 401, reason: 'firma_assente' };

  let primary: string;
  try {
    primary = await secrets.getPrimary();
  } catch {
    return { ok: false, status: 500, reason: 'segreto_non_disponibile' };
  }
  if (verifySignature(rawBody, signature, primary)) return { ok: true, source: 'webhook' };

  let app: string | null;
  try {
    app = await secrets.getApp();
  } catch {
    return { ok: false, status: 500, reason: 'segreto_app_non_disponibile' };
  }
  if (app && verifySignature(rawBody, signature, app)) return { ok: true, source: 'github-app' };

  return { ok: false, status: 401, reason: 'firma_non_valida' };
}
