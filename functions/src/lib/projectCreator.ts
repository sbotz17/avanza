import { randomInt } from 'crypto';
import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { autoProjectId, dayRef, repoRef } from './linkStore';
import { buildClientAccessData, buildProjectData, generateClientCode } from './projectFactory';
import { EventSource, LinkConfig, RepoInfo } from './types';

export type CreateResult =
  | { result: 'creato'; projectId: string; clientCode: string }
  | { result: 'esistente'; projectId: string }
  | { result: 'escluso'; reason: 'progetto_eliminato' | 'repository_escluso' }
  | { result: 'limite_giornaliero' }
  | { result: 'proprietario_config_non_valido' };

/** Quanti codici cliente candidati si leggono insieme per scegliere uno libero (la collisione tra 32^6 codici e' rarissima). */
const CODE_CANDIDATES = 5;

/**
 * Crea in automatico il progetto di un repository SCONOSCIUTO (T-20). Si chiama solo dopo i controlli di
 * eleggibilita' (interruttore acceso, proprietario ammesso, non fork / archiviato / "non tracciare").
 *
 * Una sola transazione, con identificativo deterministico del progetto (`gh_<id repository>`):
 *  - idempotente: la stessa consegna ripetuta o due eventi insieme producono UN progetto e UN codice cliente;
 *  - un progetto eliminato dall'app non risorge: il registro `githubRepos/{id}` ricorda che il repository era noto
 *    (stato `tracked`) e, non trovando piu' il progetto, passa a `excluded` senza ricrearlo;
 *  - tetto giornaliero di progetti nuovi (contatore nella stessa transazione);
 *  - l'intestatario deve essere davvero un admin (`users/{uid}.role == 'admin'`), altrimenti non si crea nulla;
 *  - stessa forma di `crea-progetto` (modulo condiviso projectFactory) e voce `clientAccess` per il codice cliente.
 * Non cancella e non modifica mai dati esistenti, se non lo stato del registro (`tracked` -> `excluded`).
 */
export async function createProjectForRepo(
  db: Firestore,
  repo: RepoInfo,
  config: LinkConfig,
  source: EventSource,
  now: Date = new Date(),
  pick: (max: number) => number = randomInt
): Promise<CreateResult> {
  if (repo.id === null) throw new Error('createProjectForRepo: repository senza id');
  const repoId = repo.id;
  const projectRef = db.collection('projects').doc(autoProjectId(repoId));
  const registryRef = repoRef(db, repoId);
  const counterRef = dayRef(db, now);
  const ownerRef = db.collection('users').doc(config.ownerUid);
  const stamp = Timestamp.fromDate(now);

  const codes = Array.from({ length: CODE_CANDIDATES }, () => generateClientCode(pick));
  const accessRefs = codes.map((c) => db.collection('clientAccess').doc(c));

  return db.runTransaction(async (tx): Promise<CreateResult> => {
    // Tutte le letture prima di qualsiasi scrittura.
    const [project, registry, counter, owner] = await Promise.all([
      tx.get(projectRef),
      tx.get(registryRef),
      tx.get(counterRef),
      tx.get(ownerRef),
    ]);
    const accessDocs = await tx.getAll(...accessRefs);

    if (project.exists) return { result: 'esistente', projectId: projectRef.id };

    if (registry.exists) {
      const state = registry.get('state');
      if (state === 'tracked') {
        // Il repository era noto e ora il suo progetto non c'e' piu': e' stato eliminato. Non lo ricreiamo.
        tx.update(registryRef, { state: 'excluded', reason: 'progetto_eliminato', updatedAt: stamp });
        return { result: 'escluso', reason: 'progetto_eliminato' };
      }
      if (state !== 'readmitted') {
        // 'excluded' oppure uno stato non riconosciuto (dato corrotto): nel dubbio non si crea.
        return { result: 'escluso', reason: registry.get('reason') === 'progetto_eliminato' ? 'progetto_eliminato' : 'repository_escluso' };
      }
      // 'readmitted': l'amministratore ha tolto l'esclusione, si prosegue con la creazione.
    }

    if (!owner.exists || owner.get('role') !== 'admin') return { result: 'proprietario_config_non_valido' };

    // Contatore illeggibile o non numerico = tetto considerato raggiunto (mai aggirare il limite per un dato corrotto).
    const raw: unknown = counter.exists ? counter.get('progettiCreati') : 0;
    const created = raw === undefined ? 0 : raw;
    if (typeof created !== 'number' || !Number.isFinite(created) || created >= config.maxNewProjectsPerDay) {
      return { result: 'limite_giornaliero' };
    }

    const freeIndex = accessDocs.findIndex((d) => !d.exists);
    if (freeIndex === -1) throw new Error('Nessun codice cliente libero tra i candidati: riprovare');
    const clientCode = codes[freeIndex];

    tx.set(
      projectRef,
      buildProjectData({
        name: repo.name,
        description: repo.description,
        githubUrl: repo.htmlUrl,
        clientCode,
        ownerId: config.ownerUid,
        now: stamp,
        extra: { githubRepoId: repoId, autoCreated: true, autoCreatedSource: source },
      })
    );
    tx.set(accessRefs[freeIndex], buildClientAccessData({ projectId: projectRef.id, ownerId: config.ownerUid, now: stamp }));
    tx.set(
      registryRef,
      {
        repoId,
        fullName: repo.fullName,
        githubUrl: repo.htmlUrl,
        projectId: projectRef.id,
        state: 'tracked',
        source: 'auto',
        ...(registry.exists ? {} : { createdAt: stamp }),
        updatedAt: stamp,
      },
      { merge: true }
    );
    tx.set(counterRef, { progettiCreati: created + 1, updatedAt: stamp }, { merge: true });

    return { result: 'creato', projectId: projectRef.id, clientCode };
  });
}
