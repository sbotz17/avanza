import {
  DesiredUpdate,
  GitHubPayload,
  NoteType,
  PhaseUpdate,
  PullRequestPayload,
  PullRequestReviewPayload,
  PushPayload,
  TaskStatus,
} from '../../lib/types';

// ---- Helpers ----

/**
 * Extracts a T-N task code from a string (branch name or PR title).
 * Regex: /\bT-?(\d+)\b/i — normalizes to "T-N".
 * Examples:
 *   "feature/T-3-pagina-login" → "T-3"
 *   "feature/T3"              → "T-3"
 *   "T-3-qualcosa"            → "T-3"
 */
export function extractTaskCode(text: string): string | null {
  const m = text.match(/\bT-?(\d+)\b/i);
  return m ? `T-${m[1]}` : null;
}

/**
 * Extracts the branch name from a git ref string.
 * "refs/heads/feature/T-3-login" → "feature/T-3-login"
 */
export function extractBranch(ref: string): string {
  return ref.replace(/^refs\/heads\//, '');
}

// ---- Result type ----

export type RouterResult =
  | { type: 'no-op' }
  | {
      type: 'update';
      repoUrl: string;
      taskCode: string;
      desired: DesiredUpdate;
    };

// ---- Main router ----

/**
 * Routes a GitHub webhook event to a desired Firestore update.
 * Returns 'no-op' for unhandled events or when no task code can be extracted.
 *
 * @param eventType  Value of the X-GitHub-Event header
 * @param payload    Parsed JSON request body
 */
export function routeEvent(eventType: string, payload: GitHubPayload): RouterResult {
  switch (eventType) {
    case 'push':
      return routePush(payload as PushPayload);
    case 'pull_request':
      return routePullRequest(payload as PullRequestPayload);
    case 'pull_request_review':
      return routePullRequestReview(payload as PullRequestReviewPayload);
    default:
      return { type: 'no-op' };
  }
}

// ---- Per-event routers ----

function routePush(payload: PushPayload): RouterResult {
  const repoUrl = payload.repository?.html_url;
  if (!repoUrl) return { type: 'no-op' };

  const branch = extractBranch(payload.ref ?? '');
  const taskCode = extractTaskCode(branch);
  if (!taskCode) return { type: 'no-op' };

  if (payload.created) {
    // BRANCH_CREATED: advance task to active, mark Analisi phase as active
    const desired: DesiredUpdate = {
      newStatus: 'active' as TaskStatus,
      phaseUpdates: [{ phaseName: 'Analisi', newStatus: 'active' }] as PhaseUpdate[],
      note: { type: 'info' as NoteType, text: `[gh] Branch ${branch} creato` },
      githubBranch: branch,
    };
    return { type: 'update', repoUrl, taskCode, desired };
  } else {
    // COMMIT_PUSHED: add a note with sha (7 chars) and message (up to 100 chars)
    const commit = payload.commits?.[0];
    if (!commit) return { type: 'no-op' };
    const sha7 = commit.id.substring(0, 7);
    const msg = commit.message.substring(0, 100);
    const desired: DesiredUpdate = {
      note: { type: 'info' as NoteType, text: `[gh] Commit ${sha7}: ${msg}` },
    };
    return { type: 'update', repoUrl, taskCode, desired };
  }
}

function routePullRequest(payload: PullRequestPayload): RouterResult {
  const repoUrl = payload.repository?.html_url;
  if (!repoUrl) return { type: 'no-op' };

  const action = payload.action;
  const pr = payload.pull_request;

  if (action === 'opened' || action === 'synchronize' || action === 'reopened') {
    // PR_OPENED: record PR number, add note
    const branch = pr.head?.ref ?? '';
    const taskCode = extractTaskCode(branch) ?? extractTaskCode(pr.title ?? '');
    if (!taskCode) return { type: 'no-op' };

    const titleTrunc = (pr.title ?? '').substring(0, 80);
    const desired: DesiredUpdate = {
      note: { type: 'info' as NoteType, text: `[gh] PR #${pr.number} aperta: "${titleTrunc}"` },
      githubPrNumber: pr.number,
    };
    return { type: 'update', repoUrl, taskCode, desired };
  }

  if (action === 'closed') {
    const branch = pr.head?.ref ?? '';
    const taskCode = extractTaskCode(branch) ?? extractTaskCode(pr.title ?? '');
    if (!taskCode) return { type: 'no-op' };

    if (pr.merged) {
      // PR_MERGED: advance to review, mark Frontend phase as done
      const base = pr.base?.ref ?? '';
      const desired: DesiredUpdate = {
        newStatus: 'review' as TaskStatus,
        phaseUpdates: [{ phaseName: 'Frontend', newStatus: 'done' }] as PhaseUpdate[],
        note: { type: 'ok' as NoteType, text: `[gh] PR #${pr.number} mergeata in ${base}` },
      };
      return { type: 'update', repoUrl, taskCode, desired };
    } else {
      // PR_CLOSED (no merge): add a blocking note, no status change
      const desired: DesiredUpdate = {
        note: {
          type: 'blk' as NoteType,
          text: `[gh] PR #${pr.number} chiusa senza merge`,
        },
      };
      return { type: 'update', repoUrl, taskCode, desired };
    }
  }

  return { type: 'no-op' };
}

function routePullRequestReview(payload: PullRequestReviewPayload): RouterResult {
  const repoUrl = payload.repository?.html_url;
  if (!repoUrl) return { type: 'no-op' };

  const action = payload.action;
  const review = payload.review;

  if (action === 'submitted' && review?.state?.toLowerCase() === 'approved') {
    // PR_APPROVED: advance to validated, mark Validazione phase as done
    const pr = payload.pull_request;
    const branch = pr?.head?.ref ?? '';
    const taskCode = extractTaskCode(branch) ?? extractTaskCode(pr?.title ?? '');
    if (!taskCode) return { type: 'no-op' };

    const reviewer = review.user?.login ?? 'unknown';
    const prNumber = pr?.number ?? 0;
    const desired: DesiredUpdate = {
      newStatus: 'validated' as TaskStatus,
      phaseUpdates: [{ phaseName: 'Validazione', newStatus: 'done' }] as PhaseUpdate[],
      note: {
        type: 'ok' as NoteType,
        text: `[gh] PR #${prNumber} approvata da ${reviewer}`,
      },
    };
    return { type: 'update', repoUrl, taskCode, desired };
  }

  return { type: 'no-op' };
}
