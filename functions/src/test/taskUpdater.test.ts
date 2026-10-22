import { buildUpdate } from '../lib/taskUpdater';
import { DesiredUpdate, TaskSnapshot } from '../lib/types';

// ---- Helpers ----

function makeTask(overrides: Partial<TaskSnapshot> = {}): TaskSnapshot {
  return {
    status: 'backlog',
    phases: [
      { name: 'Analisi', status: 'pending', label: 'Analisi' },
      { name: 'Frontend', status: 'pending', label: 'Frontend' },
      { name: 'Validazione', status: 'pending', label: 'Validazione' },
    ],
    notes: [],
    githubBranch: null,
    githubPrNumber: null,
    ...overrides,
  };
}

// ---- Status advancement ----

describe('buildUpdate — status advancement', () => {
  it('advances from backlog to active', () => {
    const update = buildUpdate(makeTask({ status: 'backlog' }), {
      newStatus: 'active',
      note: { type: 'info', text: '[gh] Branch feature/T-3 creato' },
    });
    expect(update).not.toBeNull();
    expect(update!.newStatus).toBe('active');
  });

  it('advances from active to review', () => {
    const update = buildUpdate(makeTask({ status: 'active' }), {
      newStatus: 'review',
      note: { type: 'ok', text: '[gh] PR #5 mergeata in staging' },
    });
    expect(update!.newStatus).toBe('review');
  });

  it('advances from review to validated', () => {
    const update = buildUpdate(makeTask({ status: 'review' }), {
      newStatus: 'validated',
      note: { type: 'ok', text: '[gh] PR #5 approvata da rev' },
    });
    expect(update!.newStatus).toBe('validated');
  });

  it('does NOT retreat from review to active', () => {
    const update = buildUpdate(makeTask({ status: 'review' }), {
      newStatus: 'active',
      note: { type: 'info', text: '[gh] Branch feature/T-3 creato' },
    });
    expect(update).not.toBeNull(); // note is still added
    expect(update!.newStatus).toBeUndefined(); // but no status retreat
  });

  it('does NOT advance a released task', () => {
    const update = buildUpdate(makeTask({ status: 'released' }), {
      newStatus: 'active',
      note: { type: 'info', text: '[gh] Branch feature/T-3 creato' },
    });
    expect(update).not.toBeNull();
    expect(update!.newStatus).toBeUndefined();
  });

  it('does NOT set status when new equals current (e.g. already active)', () => {
    const update = buildUpdate(makeTask({ status: 'active' }), {
      newStatus: 'active',
      note: { type: 'info', text: '[gh] Branch feature/T-3-x creato' },
    });
    expect(update!.newStatus).toBeUndefined();
  });

  it('can advance a blocked task (blocked < review in STATUS_ORDER)', () => {
    const update = buildUpdate(makeTask({ status: 'blocked' }), {
      newStatus: 'review',
      note: { type: 'ok', text: '[gh] PR #5 mergeata in staging' },
    });
    expect(update!.newStatus).toBe('review');
  });

  it('omits newStatus field when no status change is requested', () => {
    const desired: DesiredUpdate = {
      note: { type: 'blk', text: '[gh] PR #5 chiusa senza merge' },
    };
    const update = buildUpdate(makeTask(), desired);
    expect(update).not.toBeNull();
    expect(update!.newStatus).toBeUndefined();
  });
});

// ---- Idempotency ----

describe('buildUpdate — idempotency', () => {
  it('returns null when the exact note already exists', () => {
    const task = makeTask({
      notes: [{ type: 'info', text: '[gh] Branch feature/T-3 creato' }],
    });
    const update = buildUpdate(task, {
      newStatus: 'active',
      note: { type: 'info', text: '[gh] Branch feature/T-3 creato' },
    });
    expect(update).toBeNull();
  });

  it('adds the note if text is different', () => {
    const task = makeTask({
      notes: [{ type: 'info', text: '[gh] Branch feature/T-3 creato' }],
    });
    const update = buildUpdate(task, {
      note: { type: 'info', text: '[gh] Commit abc1234: Fix something' },
    });
    expect(update).not.toBeNull();
  });

  it('does not consider type when checking for duplicate (text is sufficient)', () => {
    // Same text but different type — should still be treated as duplicate
    const task = makeTask({
      notes: [{ type: 'info', text: '[gh] PR #5 mergeata in staging' }],
    });
    const update = buildUpdate(task, {
      newStatus: 'review',
      note: { type: 'ok', text: '[gh] PR #5 mergeata in staging' },
    });
    expect(update).toBeNull();
  });
});

// ---- Phase updates ----

describe('buildUpdate — phase updates', () => {
  it('advances Analisi from pending to active on BRANCH_CREATED', () => {
    const update = buildUpdate(makeTask(), {
      newStatus: 'active',
      phaseUpdates: [{ phaseName: 'Analisi', newStatus: 'active' }],
      note: { type: 'info', text: '[gh] Branch feature/T-3 creato' },
      githubBranch: 'feature/T-3',
    });
    expect(update!.phaseUpdates).toHaveLength(1);
    expect(update!.phaseUpdates![0]).toEqual({ phaseName: 'Analisi', newStatus: 'active' });
  });

  it('does NOT advance a phase that is already at or past the target', () => {
    const task = makeTask({
      phases: [
        { name: 'Analisi', status: 'done', label: 'Analisi' },
        { name: 'Frontend', status: 'pending', label: 'Frontend' },
        { name: 'Validazione', status: 'pending', label: 'Validazione' },
      ],
    });
    const update = buildUpdate(task, {
      phaseUpdates: [{ phaseName: 'Analisi', newStatus: 'active' }],
      note: { type: 'info', text: '[gh] Branch feature/T-3-v2 creato' },
    });
    expect(update!.phaseUpdates).toBeUndefined();
  });

  it('skips a phase not present in the task', () => {
    const update = buildUpdate(makeTask({ phases: [] }), {
      phaseUpdates: [{ phaseName: 'Analisi', newStatus: 'active' }],
      note: { type: 'info', text: '[gh] Branch feature/T-3-y creato' },
    });
    expect(update!.phaseUpdates).toBeUndefined();
  });

  it('is case-insensitive when matching phase names', () => {
    const task = makeTask({
      phases: [{ name: 'analisi', status: 'pending', label: 'Analisi' }],
    });
    const update = buildUpdate(task, {
      phaseUpdates: [{ phaseName: 'Analisi', newStatus: 'active' }],
      note: { type: 'info', text: '[gh] Branch feature/T-3-z creato' },
    });
    expect(update!.phaseUpdates).toHaveLength(1);
  });
});

// ---- GitHub fields ----

describe('buildUpdate — github fields', () => {
  it('includes githubBranch', () => {
    const update = buildUpdate(makeTask(), {
      note: { type: 'info', text: '[gh] Branch feature/T-3 creato' },
      githubBranch: 'feature/T-3',
    });
    expect(update!.githubBranch).toBe('feature/T-3');
  });

  it('includes githubPrNumber', () => {
    const update = buildUpdate(makeTask(), {
      note: { type: 'info', text: '[gh] PR #42 aperta: "Title"' },
      githubPrNumber: 42,
    });
    expect(update!.githubPrNumber).toBe(42);
  });

  it('omits github fields when not provided', () => {
    const update = buildUpdate(makeTask(), {
      note: { type: 'blk', text: '[gh] PR #1 chiusa senza merge' },
    });
    expect(update!.githubBranch).toBeUndefined();
    expect(update!.githubPrNumber).toBeUndefined();
  });
});
