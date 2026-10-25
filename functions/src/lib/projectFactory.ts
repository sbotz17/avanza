import { randomInt } from 'crypto';

/**
 * Costruzione condivisa di un progetto nuovo (T-20).
 *
 * UNICA implementazione di: alfabeto e generazione del codice cliente, normalizzazione dell'indirizzo GitHub,
 * forma dei documenti `projects/{id}` e `clientAccess/{codice}`. Usata sia dalla Cloud Function (progetti creati
 * in automatico) sia dallo script `scripts/registra-ore.mjs` (azione `crea-progetto`) e allineata a
 * `FirestoreService.createProject` dell'app. Modulo puro: nessuna dipendenza da Firestore (i timestamp si passano).
 */

/** Senza i caratteri ambigui (I, O, 0, 1). */
export const CLIENT_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const CLIENT_CODE_LENGTH = 6;

/** Codice progetto per l'accesso cliente: 6 caratteri casuali (generatore sicuro; `pick` iniettabile nei test). */
export function generateClientCode(pick: (max: number) => number = randomInt): string {
  let code = '';
  for (let i = 0; i < CLIENT_CODE_LENGTH; i++) code += CLIENT_CODE_ALPHABET[pick(CLIENT_CODE_ALPHABET.length)];
  return code;
}

/** Confronto degli indirizzi GitHub: maiuscole ignorate, una barra finale ignorata. */
export function normalizeGithubUrl(url: string): string {
  return url.toLowerCase().replace(/\/$/, '');
}

export interface NewProjectInput {
  name: string;
  description: string;
  githubUrl: string;
  clientCode: string;
  ownerId: string;
  /** Timestamp di Firestore (o equivalente) usato per createdAt e updatedAt. */
  now: unknown;
  /** Campi aggiuntivi (es. quelli del collegamento automatico). Non sovrascrivono i campi base. */
  extra?: Record<string, unknown>;
}

/** Documento `projects/{id}`: stessi campi di `crea-progetto` e dell'app. */
export function buildProjectData(input: NewProjectInput): Record<string, unknown> {
  return {
    ...(input.extra ?? {}),
    name: input.name,
    description: input.description,
    githubUrl: input.githubUrl,
    clientCode: input.clientCode,
    ownerId: input.ownerId,
    nextTaskNumber: 1,
    createdAt: input.now,
    updatedAt: input.now,
  };
}

/** Documento `clientAccess/{codice}`: voce di accesso cliente del progetto. */
export function buildClientAccessData(input: { projectId: string; ownerId: string; now: unknown }): Record<string, unknown> {
  return { projectId: input.projectId, ownerId: input.ownerId, createdAt: input.now };
}
