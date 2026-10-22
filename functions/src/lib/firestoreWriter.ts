import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { TaskSnapshot, TaskUpdate } from './types';

/** Status order duplicated here to avoid circular imports with taskUpdater. */
const STATUS_ORDER = ['backlog', 'active', 'blocked', 'review', 'validated', 'released'];

/** Phase status order duplicated here for the same reason. */
const PHASE_STATUS_ORDER = ['pending', 'active', 'done', 'blocked', 'skip'];

/**
 * Writes the computed TaskUpdate to Firestore using an atomic transaction.
 *
 * The transaction re-checks the "only advance" rule to protect against race
 * conditions when two webhook events arrive nearly simultaneously for the
 * same task.
 *
 * Notes are written with FieldValue.arrayUnion, which is idempotent:
 * Firestore will not add a duplicate note if the object already exists
 * in the array (deep equality).
 *
 * @param db         Firestore instance
 * @param projectId  Project document ID
 * @param taskId     Task document ID
 * @param update     The update to apply (pre-filtered by buildUpdate)
 */
export async function writeUpdate(
  db: Firestore,
  projectId: string,
  taskId: string,
  update: TaskUpdate
): Promise<void> {
  const taskRef = db.collection('projects').doc(projectId).collection('tasks').doc(taskId);

  await db.runTransaction(async (tx) => {
    const taskDoc = await tx.get(taskRef);
    if (!taskDoc.exists) {
      // Task was deleted between resolveTask and this write — treat as no-op.
      return;
    }

    const data = taskDoc.data()!;
    const firestoreUpdate: Record<string, unknown> = {
      updatedAt: FieldValue.serverTimestamp(),
    };

    // Status: re-check advancement inside transaction (race safety)
    if (update.newStatus !== undefined) {
      const currentStatus = (data['status'] as string) ?? 'backlog';
      if (currentStatus !== 'released') {
        const currentIdx = STATUS_ORDER.indexOf(currentStatus);
        const newIdx = STATUS_ORDER.indexOf(update.newStatus);
        if (newIdx > currentIdx) {
          firestoreUpdate['status'] = update.newStatus;
        }
      }
    }

    // Phases: re-check advancement inside transaction
    if (update.phaseUpdates && update.phaseUpdates.length > 0) {
      const currentPhases = (data['phases'] as TaskSnapshot['phases']) ?? [];
      const updatedPhases = currentPhases.map((phase) => {
        const pu = update.phaseUpdates!.find(
          (p) => p.phaseName.toLowerCase() === phase.name.toLowerCase()
        );
        if (!pu) return phase;
        const currentIdx = PHASE_STATUS_ORDER.indexOf(phase.status);
        const newIdx = PHASE_STATUS_ORDER.indexOf(pu.newStatus);
        return newIdx > currentIdx ? { ...phase, status: pu.newStatus } : phase;
      });
      firestoreUpdate['phases'] = updatedPhases;
    }

    // Notes: arrayUnion provides Firestore-level idempotency
    firestoreUpdate['notes'] = FieldValue.arrayUnion(update.note);

    // GitHub fields
    if (update.githubBranch !== undefined) {
      firestoreUpdate['githubBranch'] = update.githubBranch;
    }
    if (update.githubPrNumber !== undefined) {
      firestoreUpdate['githubPrNumber'] = update.githubPrNumber;
    }

    tx.update(taskRef, firestoreUpdate);
  });
}
