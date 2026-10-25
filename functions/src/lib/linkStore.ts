import { DocumentReference, Firestore } from 'firebase-admin/firestore';
import { CONFIG_COLLECTION } from './linkConfig';

/**
 * Documenti di supporto del collegamento automatico (T-20). Collezioni riservate all'Admin SDK:
 * nessuna regola `match` in firestore.rules, quindi i client sono respinti (Firestore nega cio' che non e' permesso).
 *
 *  - githubRepos/{repoId}: registro dei repository noti (id numerico GitHub) con lo stato; serve a non far "risorgere"
 *    un progetto eliminato dall'app e a riconoscere i repository esclusi.
 *  - githubCollegamento/giorno-AAAA-MM-GG: contatore dei progetti creati in automatico nel giorno (tetto anti-abuso).
 */
export const REPOS_COLLECTION = 'githubRepos';

/**
 * Stato di un repository nel registro:
 *  - tracked:   ha (o ha avuto) un progetto; se il progetto sparisce senza che nessuno lo abbia ricreato, e' stato eliminato -> diventa excluded;
 *  - excluded:  non si crea piu' un progetto da solo (eliminato dall'app, o escluso a mano);
 *  - readmitted: l'amministratore ha tolto l'esclusione: al prossimo evento il progetto si ricrea e lo stato torna tracked.
 */
export type RepoState = 'tracked' | 'excluded' | 'readmitted';

export function repoRef(db: Firestore, repoId: number): DocumentReference {
  return db.collection(REPOS_COLLECTION).doc(String(repoId));
}

/** Identificativo deterministico del progetto creato in automatico per un repository: due eventi insieme non possono crearne due. */
export function autoProjectId(repoId: number): string {
  return `gh_${repoId}`;
}

/** Giorno in ora italiana, formato AAAA-MM-GG. */
export function dayKey(now: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Rome',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

export function dayRef(db: Firestore, now: Date): DocumentReference {
  return db.collection(CONFIG_COLLECTION).doc(`giorno-${dayKey(now)}`);
}
