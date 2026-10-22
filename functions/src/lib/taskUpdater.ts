import { DesiredUpdate, PhaseStatus, TaskSnapshot, TaskStatus, TaskUpdate } from './types';

/**
 * Ordered status progression for the "only advance, never retreat" rule.
 *
 * Notes:
 * - 'released' is terminal: no automatic update can change it.
 * - 'blocked' sits between 'active' and 'review' in the ordering.
 *   Automatic events can still advance a blocked task (e.g. a merged PR
 *   moves it to 'review'), as blocking is set manually.
 */
const STATUS_ORDER: TaskStatus[] = [
  'backlog',
  'active',
  'blocked',
  'review',
  'validated',
  'released',
];

/** Ordered phase status progression. */
const PHASE_STATUS_ORDER: PhaseStatus[] = ['pending', 'active', 'done', 'blocked', 'skip'];

function statusIndex(status: string): number {
  const idx = STATUS_ORDER.indexOf(status as TaskStatus);
  return idx === -1 ? 0 : idx;
}

function phaseStatusIndex(status: string): number {
  const idx = PHASE_STATUS_ORDER.indexOf(status as PhaseStatus);
  return idx === -1 ? 0 : idx;
}

/**
 * Applies business rules to a desired update and returns the filtered TaskUpdate.
 *
 * Rules applied:
 * 1. Idempotency: if a note with the same exact text already exists, return null (no-op).
 * 2. Status: only advance (new position must be strictly higher than current).
 *    'released' is terminal — never changed automatically.
 * 3. Phases: only advance (same rule per phase).
 *
 * @param task    Current task snapshot from Firestore
 * @param desired Desired update produced by eventRouter
 * @returns       Filtered TaskUpdate to write, or null if nothing needs to change
 */
export function buildUpdate(task: TaskSnapshot, desired: DesiredUpdate): TaskUpdate | null {
  // --- Idempotency check (exact text match, ADR-02) ---
  const noteAlreadyExists = task.notes.some((n) => n.text === desired.note.text);
  if (noteAlreadyExists) {
    return null;
  }

  const update: TaskUpdate = {
    note: desired.note,
  };

  // --- Status advancement ---
  if (desired.newStatus !== undefined) {
    if (task.status !== 'released') {
      const currentIdx = statusIndex(task.status);
      const newIdx = statusIndex(desired.newStatus);
      if (newIdx > currentIdx) {
        update.newStatus = desired.newStatus;
      }
    }
    // If 'released' or no advancement possible: field is simply omitted from update
  }

  // --- Phase updates (only advance) ---
  if (desired.phaseUpdates && desired.phaseUpdates.length > 0) {
    const validPhaseUpdates = desired.phaseUpdates.filter((pu) => {
      const phase = task.phases.find(
        (p) => p.name.toLowerCase() === pu.phaseName.toLowerCase()
      );
      if (!phase) return false; // Phase not found in task definition — skip
      const currentIdx = phaseStatusIndex(phase.status);
      const newIdx = phaseStatusIndex(pu.newStatus);
      return newIdx > currentIdx;
    });
    if (validPhaseUpdates.length > 0) {
      update.phaseUpdates = validPhaseUpdates;
    }
  }

  // --- GitHub-specific fields ---
  if (desired.githubBranch !== undefined) {
    update.githubBranch = desired.githubBranch;
  }
  if (desired.githubPrNumber !== undefined) {
    update.githubPrNumber = desired.githubPrNumber;
  }

  return update;
}
