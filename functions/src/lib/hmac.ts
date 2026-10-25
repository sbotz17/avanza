import { createHmac, timingSafeEqual } from 'crypto';

/**
 * Verifies the X-Hub-Signature-256 header from a GitHub webhook request.
 *
 * Uses timingSafeEqual to prevent timing-based side-channel attacks.
 * The body must be the raw Buffer before JSON parsing.
 *
 * @param body      Raw request body as a Buffer
 * @param signature Value of the X-Hub-Signature-256 header (e.g. "sha256=abc123…")
 * @param secret    GITHUB_WEBHOOK_SECRET
 * @returns true if the signature is valid
 */
export function verifySignature(body: Buffer, signature: string, secret: string): boolean {
  // Un segreto vuoto non e' un segreto: con la chiave vuota chiunque saprebbe calcolare una firma valida.
  if (!secret) {
    return false;
  }
  if (!signature || !signature.startsWith('sha256=')) {
    return false;
  }
  const expected = 'sha256=' + createHmac('sha256', secret).update(body).digest('hex');
  const a = Buffer.from(expected, 'utf8');
  const b = Buffer.from(signature, 'utf8');
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}
