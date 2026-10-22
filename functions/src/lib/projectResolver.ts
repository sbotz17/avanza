import { Firestore } from 'firebase-admin/firestore';

/**
 * Finds a project by matching its githubUrl against the GitHub repository URL.
 * Comparison is case-insensitive and ignores trailing slashes.
 *
 * ADR-03: loads all projects (with select for githubUrl only) and matches in memory.
 * Acceptable for < ~500 projects; revisit with a denormalized field if scale grows.
 *
 * @param db       Firestore instance
 * @param repoUrl  GitHub repository html_url from the webhook payload
 * @returns        Project document ID, or null if no matching project is found
 */
export async function resolveProject(db: Firestore, repoUrl: string): Promise<string | null> {
  const normalizedInput = repoUrl.toLowerCase().replace(/\/$/, '');
  const snapshot = await db.collection('projects').select('githubUrl').get();
  for (const doc of snapshot.docs) {
    const url = (doc.data()['githubUrl'] as string | undefined) ?? '';
    if (url.toLowerCase().replace(/\/$/, '') === normalizedInput) {
      return doc.id;
    }
  }
  return null;
}
