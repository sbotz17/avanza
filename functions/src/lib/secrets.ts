import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

/**
 * Lettura dei segreti del webhook da Secret Manager (mai nel codice, mai nei log).
 *  - GITHUB_WEBHOOK_SECRET: segreto storico, copiato nei webhook dei singoli repository (obbligatorio);
 *  - GITHUB_APP_WEBHOOK_SECRET: segreto della GitHub App personale (T-20, facoltativo: finche' non esiste si usa solo il primo).
 */
export const PRIMARY_SECRET_NAME = 'GITHUB_WEBHOOK_SECRET';
export const APP_SECRET_NAME = 'GITHUB_APP_WEBHOOK_SECRET';

/** Legge l'ultima versione di un segreto. Restituisce null se il segreto non esiste; per ogni altro errore lancia. */
export type SecretReader = (name: string) => Promise<string | null>;

const FOUND_TTL_MS = 10 * 60_000; // un segreto cambiato (rotazione) vale entro 10 minuti
const MISSING_TTL_MS = 2 * 60_000; // un segreto non ancora creato si rilegge dopo 2 minuti

export function createSecretReader(projectId: string): SecretReader {
  const client = new SecretManagerServiceClient();
  return async (name: string) => {
    try {
      const [version] = await client.accessSecretVersion({
        name: `projects/${projectId}/secrets/${name}/versions/latest`,
      });
      return version.payload?.data?.toString() ?? '';
    } catch (err) {
      // 5 = NOT_FOUND (segreto o versione inesistente); 9 = FAILED_PRECONDITION (ultima versione disabilitata o distrutta):
      // per la funzione il segreto "non c'e'" e si continua con quello storico (nessun 500 per le richieste non firmate).
      const code = (err as { code?: number }).code;
      if (code === 5 || code === 9) return null;
      throw err;
    }
  };
}

export interface WebhookSecrets {
  /** Segreto storico dei webhook per-repository. */
  getPrimary(): Promise<string>;
  /** Segreto della GitHub App, oppure null se non e' (ancora) stato creato / e' vuoto. */
  getApp(): Promise<string | null>;
}

/** Segreti con copia in memoria a tempo. `now` iniettabile per i test. */
export function createWebhookSecrets(read: SecretReader, now: () => number = Date.now): WebhookSecrets {
  const cache = new Map<string, { value: string | null; expires: number }>();

  async function cached(name: string): Promise<string | null> {
    const hit = cache.get(name);
    if (hit && hit.expires > now()) return hit.value;
    const raw = await read(name);
    // Via solo gli a-capo finali (un segreto salvato con `echo` ne ha uno); il resto del valore resta com'e'.
    const value = raw === null ? null : raw.replace(/[\r\n]+$/, '');
    const normalized = value === '' ? null : value;
    cache.set(name, { value: normalized, expires: now() + (normalized === null ? MISSING_TTL_MS : FOUND_TTL_MS) });
    return normalized;
  }

  return {
    async getPrimary() {
      // Comportamento di sempre: nessun ritocco del valore. Se manca o e' vuoto e' un errore di configurazione (risposta 500).
      const hit = cache.get(PRIMARY_SECRET_NAME);
      if (hit && hit.expires > now() && hit.value) return hit.value;
      const raw = await read(PRIMARY_SECRET_NAME);
      if (!raw) throw new Error(`${PRIMARY_SECRET_NAME} mancante o vuoto`);
      cache.set(PRIMARY_SECRET_NAME, { value: raw, expires: now() + FOUND_TTL_MS });
      return raw;
    },
    getApp() {
      return cached(APP_SECRET_NAME);
    },
  };
}
