import { createHmac } from 'crypto';
import { verifySignature } from '../lib/hmac';

function makeSignature(body: Buffer, secret: string): string {
  return 'sha256=' + createHmac('sha256', secret).update(body).digest('hex');
}

const SECRET = 'test-secret-abc123';
const BODY = Buffer.from('{"ref":"refs/heads/feature/T-3-login","created":true}');

describe('verifySignature', () => {
  it('accepts a valid signature', () => {
    const sig = makeSignature(BODY, SECRET);
    expect(verifySignature(BODY, sig, SECRET)).toBe(true);
  });

  it('rejects a signature with wrong secret', () => {
    const wrongSig = makeSignature(BODY, 'wrong-secret');
    expect(verifySignature(BODY, wrongSig, SECRET)).toBe(false);
  });

  it('rejects a tampered body', () => {
    const sig = makeSignature(BODY, SECRET);
    const tamperedBody = Buffer.from('{"ref":"refs/heads/main","created":false}');
    expect(verifySignature(tamperedBody, sig, SECRET)).toBe(false);
  });

  it('rejects a signature without sha256= prefix', () => {
    const rawHex = createHmac('sha256', SECRET).update(BODY).digest('hex');
    expect(verifySignature(BODY, rawHex, SECRET)).toBe(false);
  });

  it('rejects an empty signature string', () => {
    expect(verifySignature(BODY, '', SECRET)).toBe(false);
  });

  it('rejects a truncated valid signature (length mismatch)', () => {
    const sig = makeSignature(BODY, SECRET).substring(0, 10);
    expect(verifySignature(BODY, sig, SECRET)).toBe(false);
  });
});
