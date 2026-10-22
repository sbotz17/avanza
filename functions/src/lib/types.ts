/**
 * TypeScript interfaces for the githubWebhook Cloud Function.
 * Shared across all modules.
 */

export type TaskStatus = 'backlog' | 'active' | 'blocked' | 'review' | 'validated' | 'released';
export type PhaseStatus = 'pending' | 'active' | 'done' | 'blocked' | 'skip';
export type NoteType = 'info' | 'ok' | 'blk';

/** A task note as stored in Firestore (and used in the Flutter app). */
export interface TaskNote {
  type: NoteType;
  text: string;
}

/** A phase update requested by an event (before business-rule filtering). */
export interface PhaseUpdate {
  phaseName: string; // e.g. "Analisi", "Frontend", "Validazione"
  newStatus: PhaseStatus;
}

/**
 * The computed update to apply to a task.
 * Fields are only present when the business rules allow the change.
 */
export interface TaskUpdate {
  newStatus?: TaskStatus;        // present only when status is advancing
  phaseUpdates?: PhaseUpdate[];  // only phases that can advance
  note: TaskNote;
  githubBranch?: string;
  githubPrNumber?: number;
}

/**
 * The desired update produced by event routing,
 * before business-rule filtering (no-retreat, idempotency).
 */
export interface DesiredUpdate {
  newStatus?: TaskStatus;
  phaseUpdates?: PhaseUpdate[];
  note: TaskNote;
  githubBranch?: string;
  githubPrNumber?: number;
}

/** Snapshot of a task document as read from Firestore. */
export interface TaskSnapshot {
  status: TaskStatus;
  phases: Array<{ name: string; status: string; label: string }>;
  notes: Array<{ type: string; text: string }>;
  githubBranch?: string | null;
  githubPrNumber?: number | null;
}

// ---- GitHub payload types (only the fields we use) ----

export interface RepositoryInfo {
  html_url: string;
}

export interface PushPayload {
  ref: string;       // "refs/heads/feature/T-3-login"
  created: boolean;  // true = new branch, false = additional commits
  commits: Array<{ id: string; message: string }>;
  repository: RepositoryInfo;
}

export interface PullRequestPayload {
  action: string;
  pull_request: {
    number: number;
    title: string;
    merged: boolean;
    base: { ref: string };
    head: { ref: string };
  };
  repository: RepositoryInfo;
}

export interface PullRequestReviewPayload {
  action: string;
  review: {
    state: string;
    user: { login: string };
  };
  pull_request: {
    number: number;
    title: string;
    head: { ref: string };
  };
  repository: RepositoryInfo;
}

export type GitHubPayload =
  | PushPayload
  | PullRequestPayload
  | PullRequestReviewPayload
  | Record<string, unknown>;
