import { Firestore } from 'firebase-admin/firestore';
import { EventLogEntry } from '../../lib/eventLog';
import { LinkConfig } from '../../lib/types';

export const OWNER_UID = 'uid-admin-andrea';

export const CONFIG_ON: LinkConfig = {
  autoCreateProjects: true,
  ownerUid: OWNER_UID,
  allowedOwners: ['sbotz17'],
  maxNewProjectsPerDay: 5,
};

/** Repository di prova (con tutti i campi che GitHub invia). */
export function repoPayload(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: 1001,
    name: 'prova-x',
    full_name: 'sbotz17/prova-x',
    html_url: 'https://github.com/sbotz17/prova-x',
    description: 'Repository di prova',
    fork: false,
    archived: false,
    private: true,
    topics: [],
    owner: { login: 'sbotz17' },
    ...over,
  };
}

export function pushEvent(repoOver: Record<string, unknown> = {}, branch = 'feature/senza-codice', extra: Record<string, unknown> = {}) {
  return {
    ref: `refs/heads/${branch}`,
    created: true,
    commits: [{ id: 'abcdef1234567', message: 'primo' }],
    repository: repoPayload(repoOver),
    ...extra,
  };
}

export function prEvent(repoOver: Record<string, unknown> = {}, action = 'opened', branch = 'feature/T-1-login', merged = false) {
  return {
    action,
    pull_request: { number: 7, title: 'Titolo', merged, base: { ref: 'staging' }, head: { ref: branch } },
    repository: repoPayload(repoOver),
  };
}

export function reviewEvent(association: string, repoOver: Record<string, unknown> = {}, branch = 'feature/T-1-login') {
  return {
    action: 'submitted',
    review: { state: 'approved', user: { login: 'chi-approva' }, author_association: association },
    pull_request: { number: 7, title: 'Titolo', head: { ref: branch } },
    repository: repoPayload(repoOver),
  };
}

export async function seedAdmin(db: Firestore, uid = OWNER_UID, role = 'admin'): Promise<void> {
  await db.collection('users').doc(uid).set({ email: 'andrea@example.com', role });
}

/** Task come lo crea `importa-task`. */
export function taskDoc(code: string, status = 'backlog'): Record<string, unknown> {
  const names = ['Analisi', 'Database', 'Backend', 'Design', 'Frontend', 'Test', 'Validazione'];
  return {
    title: `Task ${code}`,
    description: '',
    status,
    phases: names.map((name) => ({ name, status: 'pending', label: 'In attesa' })),
    notes: [],
    taskCode: code,
    taskNumber: Number(code.replace('T-', '')),
  };
}

/** Registro di prova: raccoglie le voci del log strutturato. */
export function collectLog(): { entries: EventLogEntry[]; log: (e: EventLogEntry) => void } {
  const entries: EventLogEntry[] = [];
  return { entries, log: (e) => entries.push(e) };
}
