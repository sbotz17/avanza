const access = jest.fn();
jest.mock('@google-cloud/secret-manager', () => ({
  SecretManagerServiceClient: jest.fn().mockImplementation(() => ({ accessSecretVersion: (...a: unknown[]) => access(...a) })),
}));

import { APP_SECRET_NAME, createSecretReader, createWebhookSecrets } from '../lib/secrets';

const grpcError = (code: number | undefined, message = 'errore') => Object.assign(new Error(message), { code });

describe('createSecretReader', () => {
  beforeEach(() => access.mockReset());

  it('reads the latest version of the named secret in the given project', async () => {
    access.mockResolvedValue([{ payload: { data: Buffer.from('valore') } }]);
    expect(await createSecretReader('proj')('NOME')).toBe('valore');
    expect(access).toHaveBeenCalledWith({ name: 'projects/proj/secrets/NOME/versions/latest' });
  });

  it('NOT_FOUND (5) means "secret absent"', async () => {
    access.mockRejectedValue(grpcError(5));
    expect(await createSecretReader('proj')('NOME')).toBeNull();
  });

  it('D3: FAILED_PRECONDITION (9, version disabled or destroyed) means "secret absent" too', async () => {
    access.mockRejectedValue(grpcError(9, 'Secret Version is in DISABLED state'));
    expect(await createSecretReader('proj')('NOME')).toBeNull();
  });

  it.each([7, 14, 2, undefined])('any other error (code %p) is propagated', async (code) => {
    access.mockRejectedValue(grpcError(code, 'boom'));
    await expect(createSecretReader('proj')('NOME')).rejects.toThrow('boom');
  });

  it('D3: with the App secret version disabled the function keeps working with the historical secret only', async () => {
    access.mockImplementation(async ({ name }: { name: string }) => {
      if (name.includes(APP_SECRET_NAME)) throw grpcError(9, 'DISABLED');
      return [{ payload: { data: Buffer.from('storico-segreto') } }];
    });
    const secrets = createWebhookSecrets(createSecretReader('proj'));
    expect(await secrets.getPrimary()).toBe('storico-segreto');
    expect(await secrets.getApp()).toBeNull();
  });
});
