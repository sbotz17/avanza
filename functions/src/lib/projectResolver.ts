import { Firestore } from 'firebase-admin/firestore';
import { normalizeGithubUrl } from './projectFactory';

/** Progetto trovato per un repository. */
export interface ResolvedProject {
  id: string;
  /** true se riconosciuto dall'identificativo numerico del repository (resiste a rinomina e trasferimento). */
  byRepoId: boolean;
  githubUrl: string;
  /** Identificativo del repository gia' registrato sul progetto, se presente. */
  githubRepoId: number | null;
}

/**
 * Trova il progetto di un repository: prima per identificativo numerico stabile (`githubRepoId`, T-20),
 * poi per indirizzo GitHub (`githubUrl`, confronto senza maiuscole e senza barra finale; e' l'unico modo per i progetti
 * registrati a mano che non hanno ancora l'identificativo).
 *
 * ADR-03: carica tutti i progetti (solo i due campi usati) e confronta in memoria.
 * Accettabile per < ~500 progetti; da rivedere con un campo denormalizzato se la scala cresce.
 */
export async function resolveProjectForRepo(
  db: Firestore,
  repo: { htmlUrl: string; id?: number | null }
): Promise<ResolvedProject | null> {
  const wanted = normalizeGithubUrl(repo.htmlUrl);
  const snapshot = await db.collection('projects').select('githubUrl', 'githubRepoId').get();

  const toResolved = (doc: (typeof snapshot.docs)[number], byRepoId: boolean): ResolvedProject => {
    const data = doc.data();
    const storedId = data['githubRepoId'];
    return {
      id: doc.id,
      byRepoId,
      githubUrl: (data['githubUrl'] as string | undefined) ?? '',
      githubRepoId: typeof storedId === 'number' ? storedId : null,
    };
  };

  if (typeof repo.id === 'number') {
    const byId = snapshot.docs.find((d) => d.data()['githubRepoId'] === repo.id);
    if (byId) return toResolved(byId, true);
  }
  const byUrl = snapshot.docs.find((d) => {
    const url = (d.data()['githubUrl'] as string | undefined) ?? '';
    return url !== '' && normalizeGithubUrl(url) === wanted;
  });
  return byUrl ? toResolved(byUrl, false) : null;
}

/**
 * Finds a project by matching its githubUrl against the GitHub repository URL.
 * Comparison is case-insensitive and ignores trailing slashes.
 *
 * @param db       Firestore instance
 * @param repoUrl  GitHub repository html_url from the webhook payload
 * @returns        Project document ID, or null if no matching project is found
 */
export async function resolveProject(db: Firestore, repoUrl: string): Promise<string | null> {
  return (await resolveProjectForRepo(db, { htmlUrl: repoUrl }))?.id ?? null;
}
