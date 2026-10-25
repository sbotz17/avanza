import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { repoRef } from './linkStore';
import { normalizeGithubUrl } from './projectFactory';
import { isGithubRepoUrl } from './repoInfo';
import { ResolvedProject } from './projectResolver';
import { RepoInfo } from './types';

export interface SyncResult {
  /** L'identificativo del repository e' stato aggiunto al progetto. */
  attached: boolean;
  /** L'indirizzo del progetto e' stato aggiornato perche' il repository e' stato rinominato o trasferito. */
  renamed: boolean;
  /** Il progetto ha gia' un altro identificativo (repository ricreato con lo stesso nome): non si tocca nulla. */
  idMismatch: boolean;
}

/**
 * Aggancia un progetto ESISTENTE al repository che ha generato l'evento (T-20, solo aggiunte):
 *  - aggiunge `githubRepoId` se manca (e la voce nel registro `githubRepos`); nome, descrizione, codice cliente,
 *    proprietario e task restano identici;
 *  - se il progetto e' riconosciuto per identificativo ma l'indirizzo e' cambiato (rinomina / trasferimento),
 *    aggiorna `githubUrl` conservando il vecchio valore in `githubUrlPrecedente`;
 *  - non tocca mai `updatedAt` (la lista dei progetti e' ordinata per quel campo).
 * Idempotente: ripetuta, non scrive nulla.
 */
export async function syncProjectLink(
  db: Firestore,
  resolved: ResolvedProject,
  repo: RepoInfo,
  now: Date = new Date()
): Promise<SyncResult> {
  const projectRef = db.collection('projects').doc(resolved.id);
  const stamp = Timestamp.fromDate(now);
  const result: SyncResult = { attached: false, renamed: false, idMismatch: false };

  await db.runTransaction(async (tx) => {
    result.attached = false;
    result.renamed = false;
    result.idMismatch = false;

    const project = await tx.get(projectRef);
    if (!project.exists) return; // eliminato nel frattempo: niente da agganciare
    const registryRef = repo.id !== null ? repoRef(db, repo.id) : null;
    const registry = registryRef ? await tx.get(registryRef) : null;

    const storedId = project.get('githubRepoId');
    const storedUrl = String(project.get('githubUrl') ?? '');
    const projectUpdates: Record<string, unknown> = {};

    if (repo.id !== null) {
      if (typeof storedId !== 'number') {
        projectUpdates['githubRepoId'] = repo.id;
        result.attached = true;
      } else if (storedId !== repo.id) {
        result.idMismatch = true;
      }
    }

    const sameRepo = repo.id !== null && (storedId === repo.id || result.attached);
    if (
      resolved.byRepoId &&
      sameRepo &&
      isGithubRepoUrl(repo.htmlUrl) &&
      normalizeGithubUrl(storedUrl) !== normalizeGithubUrl(repo.htmlUrl)
    ) {
      projectUpdates['githubUrl'] = repo.htmlUrl;
      projectUpdates['githubUrlPrecedente'] = storedUrl;
      result.renamed = true;
    }

    // Registro dei repository (serve a riconoscere un progetto eliminato; vedi createProjectForRepo).
    if (registryRef && registry && !result.idMismatch) {
      if (!registry.exists) {
        tx.set(registryRef, {
          repoId: repo.id,
          fullName: repo.fullName,
          githubUrl: repo.htmlUrl,
          projectId: resolved.id,
          state: 'tracked',
          source: 'attach',
          createdAt: stamp,
          updatedAt: stamp,
        });
      } else {
        const state = registry.get('state');
        const pointsElsewhere = registry.get('projectId') !== resolved.id;
        if (state === 'readmitted' || (state === 'tracked' && pointsElsewhere)) {
          // Il progetto e' stato ricreato (a mano o dopo la riammissione): il registro punta al progetto attuale.
          tx.update(registryRef, { state: 'tracked', projectId: resolved.id, githubUrl: repo.htmlUrl, updatedAt: stamp });
        }
      }
    }

    if (Object.keys(projectUpdates).length > 0) tx.update(projectRef, projectUpdates);
  });

  return result;
}

/** Eventi `repository` che cambiano lo stato del repository (T-20, CA-6.1 e CA-6.3): si segnano e basta, mai cancellare. */
const REPOSITORY_FLAGS: Record<string, Record<string, boolean>> = {
  archived: { githubArchived: true },
  unarchived: { githubArchived: false },
  deleted: { githubDeleted: true },
};

/**
 * Segna sul progetto l'archiviazione / la cancellazione del repository. Restituisce true se ha scritto qualcosa.
 * Il progetto, la sua storia, i task, le ore e i costi restano com'erano.
 */
export async function applyRepositoryAction(db: Firestore, projectId: string, action: string): Promise<boolean> {
  const flags = REPOSITORY_FLAGS[action];
  if (!flags) return false;
  const ref = db.collection('projects').doc(projectId);
  return db.runTransaction(async (tx) => {
    const project = await tx.get(ref);
    if (!project.exists) return false;
    const changed = Object.entries(flags).filter(([k, v]) => project.get(k) !== v);
    if (changed.length === 0) return false;
    tx.update(ref, Object.fromEntries(changed));
    return true;
  });
}
