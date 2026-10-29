import { Firestore } from 'firebase-admin/firestore';
import { HANDLED_EVENT_TYPES, isProjectCreatingEvent, routeEvent } from './eventRouter';
import { EventLogEntry, Outcome, logEvent } from './eventLog';
import { loadLinkConfig } from './linkConfig';
import { createProjectForRepo } from './projectCreator';
import { applyRepositoryAction, syncProjectLink } from './projectLink';
import { resolveProjectForRepo } from './projectResolver';
import { creationBlockReason, extractRepoInfo, isIgnoredRepo, ownerIsConsistent } from './repoInfo';
import { writeUpdate } from './firestoreWriter';
import { resolveTask } from './taskResolver';
import { buildUpdate } from './taskUpdater';
import { EventSource, GitHubPayload, LinkConfig, RepoInfo } from './types';

export interface ProcessDeps {
  db: Firestore;
  /** Lettura della configurazione del collegamento (di default: documento githubCollegamento/config, copia in memoria 60 s). */
  getConfig?: () => Promise<LinkConfig | null>;
  now?: () => Date;
  /** Registro degli eventi (di default: log strutturato su Cloud Logging). */
  log?: (entry: EventLogEntry) => void;
}

export interface ProcessResult {
  outcome: Outcome;
  reason: string;
  projectId?: string;
  taskCode?: string;
}

/**
 * Elabora un evento GITHUB GIA' AUTENTICATO (firma verificata da authenticateWebhook).
 *
 * Percorso:
 *  1. eventi non gestiti e `ping`: ignorati (registrati);
 *  2. repository marcato "non tracciare" (topic `avanza-ignora`): non si crea e non si aggiorna nulla;
 *  3. progetto del repository: per identificativo numerico, poi per indirizzo; se esiste lo si aggancia (solo aggiunte)
 *     e si prosegue con l'aggiornamento del task, come sempre (regole "solo avanzare", note idempotenti);
 *  4. progetto sconosciuto: se l'evento e' lavoro vero e l'interruttore e' acceso, il proprietario e' ammesso, il
 *     repository non e' fork / archiviato / escluso e il tetto giornaliero non e' raggiunto, nasce il progetto;
 *  5. ogni evento lascia una traccia strutturata (esito + motivo), anche quelli non agganciati.
 * Un errore di Firestore si propaga (la funzione risponde 500); tutto il resto risponde 200.
 * Qui NON si creano mai task: i task li crea solo la squadra.
 */
export async function processEvent(
  deps: ProcessDeps,
  eventType: string,
  payload: GitHubPayload,
  source: EventSource,
  delivery: string
): Promise<ProcessResult> {
  const log = deps.log ?? logEvent;
  const repo = extractRepoInfo(payload);
  const done = (r: ProcessResult): ProcessResult => {
    log({
      outcome: r.outcome,
      reason: r.reason,
      eventType,
      source,
      delivery,
      ...(repo ? { repo: repo.fullName } : {}),
      ...(r.projectId ? { projectId: r.projectId } : {}),
      ...(r.taskCode ? { taskCode: r.taskCode } : {}),
    });
    return r;
  };

  if (eventType === 'ping') return done({ outcome: 'ignorato', reason: 'ping' });
  if (!HANDLED_EVENT_TYPES.includes(eventType)) return done({ outcome: 'ignorato', reason: 'evento_non_gestito' });
  if (!repo) return done({ outcome: 'ignorato', reason: 'repository_assente' });
  if (isIgnoredRepo(repo)) return done({ outcome: 'escluso', reason: 'non_tracciare' });

  const db = deps.db;
  const resolved = await resolveProjectForRepo(db, { htmlUrl: repo.htmlUrl, id: repo.id });

  // ---- Progetto sconosciuto ----
  if (!resolved) {
    if (eventType === 'repository' || !isProjectCreatingEvent(eventType, payload)) {
      return done({ outcome: 'non_agganciato', reason: 'progetto_sconosciuto' });
    }
    return done(await tryCreateProject(deps, repo, source));
  }

  // ---- Progetto noto: aggancio (solo aggiunte) ----
  const link = await syncProjectLink(db, resolved, repo, deps.now?.());
  if (link.idMismatch) {
    // Repository ricreato con lo stesso nome: l'identificativo registrato e' un altro. Si segnala, non si tocca nulla.
    log({ outcome: 'non_agganciato', reason: 'identificativo_repository_diverso', eventType, source, delivery, repo: repo.fullName, projectId: resolved.id });
  }

  if (eventType === 'repository') {
    const action = (payload as { action?: unknown }).action;
    const changed = typeof action === 'string' ? await applyRepositoryAction(db, resolved.id, action) : false;
    return done({ outcome: changed ? 'aggiornato' : 'ignorato', reason: changed ? `repository_${String(action)}` : 'repository_nessuna_modifica', projectId: resolved.id });
  }

  // ---- Aggiornamento del task (comportamento storico) ----
  const route = routeEvent(eventType, payload);
  if (route.type === 'no-op') {
    return done({ outcome: 'non_agganciato', reason: 'senza_codice_task', projectId: resolved.id });
  }
  const task = await resolveTask(db, resolved.id, route.taskCode);
  if (!task) {
    return done({ outcome: 'non_agganciato', reason: 'task_inesistente', projectId: resolved.id, taskCode: route.taskCode });
  }
  const update = buildUpdate(task.data, route.desired);
  if (!update) {
    return done({ outcome: 'ignorato', reason: 'nota_gia_presente', projectId: resolved.id, taskCode: route.taskCode });
  }
  await writeUpdate(db, resolved.id, task.id, update);
  return done({
    outcome: 'aggiornato',
    reason: update.newStatus ? `stato_${update.newStatus}` : 'nota',
    projectId: resolved.id,
    taskCode: route.taskCode,
  });
}

/** Creazione automatica del progetto di un repository sconosciuto, con tutti i controlli. */
async function tryCreateProject(deps: ProcessDeps, repo: RepoInfo, source: EventSource): Promise<ProcessResult> {
  const blocked = creationBlockReason(repo);
  if (blocked) return { outcome: 'scartato', reason: blocked };

  // Solo la GitHub App (segreto dedicato, installata sui soli repository dell'account) puo' far nascere un progetto:
  // il segreto storico e' copiato in ogni webhook per-repository e continua a servire solo per aggiornare i task.
  if (source !== 'github-app') return { outcome: 'non_agganciato', reason: 'creazione_solo_da_github_app' };

  const config = await (deps.getConfig ?? (() => loadLinkConfig(deps.db)))();
  // Interruttore spento o configurazione incompleta: si torna al comportamento di prima (solo aggiornamenti).
  if (!config) return { outcome: 'non_agganciato', reason: 'creazione_spenta' };

  // owner.login, full_name e html_url devono dire la stessa cosa, e quel proprietario deve essere tra quelli ammessi.
  if (!ownerIsConsistent(repo)) return { outcome: 'scartato', reason: 'proprietario_incoerente' };
  if (!config.allowedOwners.includes(repo.ownerLogin)) return { outcome: 'scartato', reason: 'proprietario_non_ammesso' };

  const created = await createProjectForRepo(deps.db, repo, config, source, deps.now?.());
  switch (created.result) {
    case 'creato':
      return { outcome: 'creato', reason: 'progetto_creato', projectId: created.projectId };
    case 'esistente':
      return { outcome: 'ignorato', reason: 'progetto_gia_creato', projectId: created.projectId };
    case 'escluso':
      return { outcome: 'escluso', reason: created.reason };
    case 'limite_giornaliero':
      return { outcome: 'scartato', reason: 'limite_giornaliero' };
    case 'proprietario_config_non_valido':
      return { outcome: 'scartato', reason: 'proprietario_config_non_valido' };
  }
}
