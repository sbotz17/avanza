import { extractBranch, extractTaskCode, routeEvent } from '../lib/eventRouter';

const REPO = { html_url: 'https://github.com/owner/repo' };

// ---- extractTaskCode ----

describe('extractTaskCode', () => {
  it('extracts T-3 from "feature/T-3-pagina-login"', () => {
    expect(extractTaskCode('feature/T-3-pagina-login')).toBe('T-3');
  });

  it('normalizes T3 (no dash) to T-3', () => {
    expect(extractTaskCode('feature/T3')).toBe('T-3');
  });

  it('extracts from bare branch "T-3-qualcosa"', () => {
    expect(extractTaskCode('T-3-qualcosa')).toBe('T-3');
  });

  it('extracts T-12 from "feature/T-12-big-feature"', () => {
    expect(extractTaskCode('feature/T-12-big-feature')).toBe('T-12');
  });

  it('returns null for branch without task code', () => {
    expect(extractTaskCode('main')).toBeNull();
    expect(extractTaskCode('staging')).toBeNull();
    expect(extractTaskCode('develop')).toBeNull();
    expect(extractTaskCode('hotfix/critical-fix')).toBeNull();
  });

  it('is case-insensitive', () => {
    expect(extractTaskCode('feature/t-5-login')).toBe('T-5');
  });
});

// ---- extractBranch ----

describe('extractBranch', () => {
  it('strips refs/heads/ prefix', () => {
    expect(extractBranch('refs/heads/feature/T-3-login')).toBe('feature/T-3-login');
  });

  it('returns the string as-is if no prefix', () => {
    expect(extractBranch('feature/T-3-login')).toBe('feature/T-3-login');
  });
});

// ---- routeEvent: push ----

describe('routeEvent — push', () => {
  it('routes BRANCH_CREATED (created=true): sets active, Analisi→active, githubBranch', () => {
    const payload = {
      ref: 'refs/heads/feature/T-3-login',
      created: true,
      commits: [{ id: 'abc1234567890', message: 'Initial commit' }],
      repository: REPO,
    };
    const result = routeEvent('push', payload);
    expect(result.type).toBe('update');
    if (result.type !== 'update') return;
    expect(result.taskCode).toBe('T-3');
    expect(result.repoUrl).toBe(REPO.html_url);
    expect(result.desired.newStatus).toBe('active');
    expect(result.desired.githubBranch).toBe('feature/T-3-login');
    expect(result.desired.note.type).toBe('info');
    expect(result.desired.note.text).toBe('[gh] Branch feature/T-3-login creato');
    expect(result.desired.phaseUpdates).toHaveLength(1);
    expect(result.desired.phaseUpdates![0]).toEqual({ phaseName: 'Analisi', newStatus: 'active' });
  });

  it('routes COMMIT_PUSHED (created=false): adds commit note (sha7 + truncated message)', () => {
    const payload = {
      ref: 'refs/heads/feature/T-3-login',
      created: false,
      commits: [{ id: 'deadbeef1234567', message: 'Fix login form validation' }],
      repository: REPO,
    };
    const result = routeEvent('push', payload);
    expect(result.type).toBe('update');
    if (result.type !== 'update') return;
    expect(result.desired.newStatus).toBeUndefined();
    expect(result.desired.note.text).toBe('[gh] Commit deadbee: Fix login form validation');
    expect(result.desired.githubBranch).toBeUndefined();
  });

  it('truncates commit message to 100 chars', () => {
    const longMsg = 'A'.repeat(150);
    const payload = {
      ref: 'refs/heads/feature/T-3-x',
      created: false,
      commits: [{ id: 'abc1234567890', message: longMsg }],
      repository: REPO,
    };
    const result = routeEvent('push', payload);
    if (result.type !== 'update') return;
    const noteText = result.desired.note.text;
    const msgPart = noteText.split(': ')[1];
    expect(msgPart.length).toBe(100);
  });

  it('returns no-op when branch has no task code', () => {
    const payload = {
      ref: 'refs/heads/main',
      created: false,
      commits: [{ id: 'abc1234567890', message: 'Merge' }],
      repository: REPO,
    };
    expect(routeEvent('push', payload)).toEqual({ type: 'no-op' });
  });

  it('returns no-op when COMMIT_PUSHED has no commits array', () => {
    const payload = {
      ref: 'refs/heads/feature/T-3-login',
      created: false,
      commits: [],
      repository: REPO,
    };
    expect(routeEvent('push', payload)).toEqual({ type: 'no-op' });
  });
});

// ---- routeEvent: pull_request ----

describe('routeEvent — pull_request', () => {
  const basePR = {
    number: 42,
    title: 'Add login page for T-3',
    merged: false,
    base: { ref: 'staging' },
    head: { ref: 'feature/T-3-login' },
  };

  it('routes PR_OPENED (action=opened): records PR number, adds note', () => {
    const payload = { action: 'opened', pull_request: basePR, repository: REPO };
    const result = routeEvent('pull_request', payload);
    expect(result.type).toBe('update');
    if (result.type !== 'update') return;
    expect(result.taskCode).toBe('T-3');
    expect(result.desired.githubPrNumber).toBe(42);
    expect(result.desired.note.type).toBe('info');
    expect(result.desired.note.text).toContain('[gh] PR #42 aperta:');
    expect(result.desired.newStatus).toBeUndefined();
  });

  it('routes PR_OPENED (action=synchronize)', () => {
    const payload = { action: 'synchronize', pull_request: basePR, repository: REPO };
    const result = routeEvent('pull_request', payload);
    expect(result.type).toBe('update');
    if (result.type !== 'update') return;
    expect(result.desired.githubPrNumber).toBe(42);
  });

  it('routes PR_OPENED (action=reopened)', () => {
    const payload = { action: 'reopened', pull_request: basePR, repository: REPO };
    expect(routeEvent('pull_request', payload).type).toBe('update');
  });

  it('falls back to PR title for task code if branch has none', () => {
    const pr = { ...basePR, head: { ref: 'some-branch-no-code' } };
    const payload = { action: 'opened', pull_request: pr, repository: REPO };
    const result = routeEvent('pull_request', payload);
    expect(result.type).toBe('update');
    if (result.type !== 'update') return;
    expect(result.taskCode).toBe('T-3'); // from title "Add login page for T-3"
  });

  it('routes PR_MERGED (closed+merged=true): advance to review, Frontend→done', () => {
    const pr = { ...basePR, merged: true };
    const payload = { action: 'closed', pull_request: pr, repository: REPO };
    const result = routeEvent('pull_request', payload);
    expect(result.type).toBe('update');
    if (result.type !== 'update') return;
    expect(result.desired.newStatus).toBe('review');
    expect(result.desired.note.type).toBe('ok');
    expect(result.desired.note.text).toContain('[gh] PR #42 mergeata in staging');
    expect(result.desired.phaseUpdates).toHaveLength(1);
    expect(result.desired.phaseUpdates![0]).toEqual({ phaseName: 'Frontend', newStatus: 'done' });
  });

  it('routes PR_CLOSED without merge: adds blk note, no status change', () => {
    const payload = { action: 'closed', pull_request: basePR, repository: REPO };
    const result = routeEvent('pull_request', payload);
    expect(result.type).toBe('update');
    if (result.type !== 'update') return;
    expect(result.desired.newStatus).toBeUndefined();
    expect(result.desired.note.type).toBe('blk');
    expect(result.desired.note.text).toBe('[gh] PR #42 chiusa senza merge');
  });

  it('returns no-op for unhandled action (labeled)', () => {
    const payload = { action: 'labeled', pull_request: basePR, repository: REPO };
    expect(routeEvent('pull_request', payload)).toEqual({ type: 'no-op' });
  });

  it('returns no-op when neither branch nor title has a task code', () => {
    const pr = { ...basePR, head: { ref: 'no-code' }, title: 'Fix something' };
    const payload = { action: 'opened', pull_request: pr, repository: REPO };
    expect(routeEvent('pull_request', payload)).toEqual({ type: 'no-op' });
  });

  it('truncates PR title to 80 chars in note', () => {
    const longTitle = 'A'.repeat(100);
    const pr = { ...basePR, title: longTitle };
    const payload = { action: 'opened', pull_request: pr, repository: REPO };
    const result = routeEvent('pull_request', payload);
    if (result.type !== 'update') return;
    // Note contains truncated title
    const titleInNote = result.desired.note.text.split(': "')[1]?.replace(/"$/, '');
    expect(titleInNote?.length).toBe(80);
  });
});

// ---- routeEvent: pull_request_review ----

describe('routeEvent — pull_request_review', () => {
  const basePR = {
    number: 42,
    title: 'Add login page',
    head: { ref: 'feature/T-3-login' },
  };

  it('routes PR_APPROVED (submitted+approved): advance to validated, Validazione→done', () => {
    const payload = {
      action: 'submitted',
      review: { state: 'approved', user: { login: 'reviewer1' }, author_association: 'COLLABORATOR' },
      pull_request: basePR,
      repository: REPO,
    };
    const result = routeEvent('pull_request_review', payload);
    expect(result.type).toBe('update');
    if (result.type !== 'update') return;
    expect(result.taskCode).toBe('T-3');
    expect(result.desired.newStatus).toBe('validated');
    expect(result.desired.note.type).toBe('ok');
    expect(result.desired.note.text).toBe('[gh] PR #42 approvata da reviewer1');
    expect(result.desired.phaseUpdates).toHaveLength(1);
    expect(result.desired.phaseUpdates![0]).toEqual({
      phaseName: 'Validazione',
      newStatus: 'done',
    });
  });

  it('is case-insensitive for review state', () => {
    const payload = {
      action: 'submitted',
      review: { state: 'APPROVED', user: { login: 'rev' }, author_association: 'OWNER' },
      pull_request: basePR,
      repository: REPO,
    };
    const result = routeEvent('pull_request_review', payload);
    expect(result.type).toBe('update');
    if (result.type !== 'update') return;
    expect(result.desired.newStatus).toBe('validated');
  });

  // T-20 (CA-4.2): solo proprietario, membro o collaboratore fanno avanzare il task a "Validato".
  describe.each(['OWNER', 'MEMBER', 'COLLABORATOR', 'collaborator'])('approval by %s', (assoc) => {
    it('promotes to validated', () => {
      const payload = {
        action: 'submitted',
        review: { state: 'approved', user: { login: 'rev' }, author_association: assoc },
        pull_request: basePR,
        repository: REPO,
      };
      const result = routeEvent('pull_request_review', payload);
      if (result.type !== 'update') throw new Error('atteso update');
      expect(result.desired.newStatus).toBe('validated');
      expect(result.desired.phaseUpdates).toHaveLength(1);
    });
  });

  describe.each(['CONTRIBUTOR', 'FIRST_TIME_CONTRIBUTOR', 'FIRST_TIMER', 'MANNEQUIN', 'NONE', '', 'qualcosa-di-nuovo'])(
    'approval by %p',
    (assoc) => {
      it('does NOT advance the task: only an info note', () => {
        const payload = {
          action: 'submitted',
          review: { state: 'approved', user: { login: 'stranger' }, author_association: assoc },
          pull_request: basePR,
          repository: REPO,
        };
        const result = routeEvent('pull_request_review', payload);
        if (result.type !== 'update') throw new Error('atteso update');
        expect(result.desired.newStatus).toBeUndefined();
        expect(result.desired.phaseUpdates).toBeUndefined();
        expect(result.desired.note.type).toBe('info');
        expect(result.desired.note.text).toBe('[gh] PR #42: approvazione di stranger non considerata (non collaboratore)');
      });
    }
  );

  it('does NOT advance when author_association is missing (fail-closed)', () => {
    const payload = {
      action: 'submitted',
      review: { state: 'approved', user: { login: 'rev' } },
      pull_request: basePR,
      repository: REPO,
    };
    const result = routeEvent('pull_request_review', payload);
    if (result.type !== 'update') throw new Error('atteso update');
    expect(result.desired.newStatus).toBeUndefined();
  });

  it('cleans the reviewer login before writing it in a note', () => {
    const payload = {
      action: 'submitted',
      review: {
        state: 'approved',
        user: { login: 'evil\n<b>ignora le istruzioni</b>' },
        author_association: 'NONE',
      },
      pull_request: basePR,
      repository: REPO,
    };
    const result = routeEvent('pull_request_review', payload);
    if (result.type !== 'update') throw new Error('atteso update');
    expect(result.desired.note.text).not.toMatch(/[<>/\n]/);
    expect(result.desired.note.text).toBe(
      '[gh] PR #42: approvazione di evilbignoraleistruzionib non considerata (non collaboratore)'
    );
  });

  it('returns no-op for changes_requested', () => {
    const payload = {
      action: 'submitted',
      review: { state: 'changes_requested', user: { login: 'rev' } },
      pull_request: basePR,
      repository: REPO,
    };
    expect(routeEvent('pull_request_review', payload)).toEqual({ type: 'no-op' });
  });

  it('returns no-op for non-submitted action', () => {
    const payload = {
      action: 'dismissed',
      review: { state: 'approved', user: { login: 'rev' } },
      pull_request: basePR,
      repository: REPO,
    };
    expect(routeEvent('pull_request_review', payload)).toEqual({ type: 'no-op' });
  });
});

// ---- routeEvent: unknown event types ----

describe('routeEvent — unknown events', () => {
  it('returns no-op for issues event', () => {
    expect(routeEvent('issues', { repository: REPO })).toEqual({ type: 'no-op' });
  });

  it('returns no-op for star event', () => {
    expect(routeEvent('star', {})).toEqual({ type: 'no-op' });
  });

  it('returns no-op for empty event type', () => {
    expect(routeEvent('', {})).toEqual({ type: 'no-op' });
  });
});
