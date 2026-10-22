import { Firestore } from 'firebase-admin/firestore';
import { TaskSnapshot, TaskStatus } from './types';

/**
 * Finds a task by taskCode within a project's tasks subcollection.
 *
 * @param db         Firestore instance
 * @param projectId  Project document ID
 * @param taskCode   Task code to search for, e.g. "T-3"
 * @returns          { id, data } or null if no matching task is found
 */
export async function resolveTask(
  db: Firestore,
  projectId: string,
  taskCode: string
): Promise<{ id: string; data: TaskSnapshot } | null> {
  const snapshot = await db
    .collection('projects')
    .doc(projectId)
    .collection('tasks')
    .where('taskCode', '==', taskCode)
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  const doc = snapshot.docs[0];
  const d = doc.data();

  return {
    id: doc.id,
    data: {
      status: ((d['status'] as string) ?? 'backlog') as TaskStatus,
      phases: (d['phases'] as TaskSnapshot['phases']) ?? [],
      notes: (d['notes'] as TaskSnapshot['notes']) ?? [],
      githubBranch: (d['githubBranch'] as string | null | undefined) ?? null,
      githubPrNumber: (d['githubPrNumber'] as number | null | undefined) ?? null,
    },
  };
}
