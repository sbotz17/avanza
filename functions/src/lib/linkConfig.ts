import { Firestore } from 'firebase-admin/firestore';
import { LinkConfig } from './types';

/** Documento di configurazione del collegamento (T-20). Lo scrive solo lo script di amministrazione (azione `collegamento`). */
export const CONFIG_COLLECTION = 'githubCollegamento';
export const CONFIG_DOC = 'config';

export const DEFAULT_MAX_NEW_PROJECTS_PER_DAY = 5;
const MAX_ALLOWED_PER_DAY = 50;
const CACHE_MS = 60_000;

/**
 * Valida il documento di configurazione. Restituisce null (= creazione automatica SPENTA) se manca qualcosa:
 * senza configurazione completa e interruttore esplicitamente acceso non si crea nessun progetto.
 */
export function parseLinkConfig(data: Record<string, unknown> | undefined | null): LinkConfig | null {
  if (!data) return null;
  if (data['autoCreateProjects'] !== true) return null;

  const ownerUid = data['ownerUid'];
  if (typeof ownerUid !== 'string' || ownerUid.trim().length === 0 || ownerUid.length > 128 || ownerUid.includes('/')) {
    return null;
  }

  const owners = data['allowedOwners'];
  if (!Array.isArray(owners)) return null;
  const allowedOwners = owners
    .filter((o): o is string => typeof o === 'string' && /^[A-Za-z0-9-]{1,39}$/.test(o))
    .map((o) => o.toLowerCase());
  if (allowedOwners.length === 0) return null;

  const rawMax = data['maxNewProjectsPerDay'];
  const maxNewProjectsPerDay =
    typeof rawMax === 'number' && Number.isInteger(rawMax) && rawMax >= 1 && rawMax <= MAX_ALLOWED_PER_DAY
      ? rawMax
      : DEFAULT_MAX_NEW_PROJECTS_PER_DAY;

  return { autoCreateProjects: true, ownerUid: ownerUid.trim(), allowedOwners, maxNewProjectsPerDay };
}

let cache: { at: number; value: LinkConfig | null } | null = null;

/** Azzera la copia in memoria (solo per i test). */
export function resetLinkConfigCache(): void {
  cache = null;
}

/**
 * Legge la configurazione (copia in memoria per 60 secondi: spegnere l'interruttore ha effetto entro un minuto, senza ridistribuire).
 * Un errore di lettura NON accende nulla: si propaga e l'evento risponde 500.
 */
export async function loadLinkConfig(db: Firestore, now: number = Date.now()): Promise<LinkConfig | null> {
  if (cache && now - cache.at < CACHE_MS) return cache.value;
  const snap = await db.collection(CONFIG_COLLECTION).doc(CONFIG_DOC).get();
  const value = parseLinkConfig(snap.exists ? (snap.data() as Record<string, unknown>) : null);
  cache = { at: now, value };
  return value;
}
