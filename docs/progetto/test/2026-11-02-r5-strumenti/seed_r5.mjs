// R-5: dati finti SOLO emulatori locali (Auth 9099, Firestore 8080).
import { seed, signUp, clearAll } from './docs/progetto/test/2026-10-28-audit-strumenti/e2e/emu.mjs';

const PW = 'Prova-1234-xyz';
await clearAll();
const admin = await signUp('admin@test.it', PW);
const now = new Date('2026-11-02T10:00:00Z');
const phases = (done) =>
  ['Analisi', 'Database', 'Backend', 'Design', 'Frontend', 'Test', 'Validazione'].map((n, i) => ({
    name: n,
    status: i < done ? 'done' : 'pending',
    label: i < done ? 'Fatto' : 'In attesa',
  }));

await seed(`users/${admin}`, { email: 'admin@test.it', role: 'admin', createdAt: now });
await seed('projects/p1', {
  name: 'Progetto Alfa',
  description: 'Prova scorrimento kanban',
  githubUrl: '',
  clientCode: 'ABC234',
  ownerId: admin,
  nextTaskNumber: 30,
  createdAt: now,
  updatedAt: now,
});
await seed('clientAccess/ABC234', { projectId: 'p1', ownerId: admin, createdAt: now });

for (let i = 1; i <= 22; i++) {
  const n = String(i).padStart(2, '0');
  await seed(`projects/p1/tasks/t${n}`, {
    title: `Task kanban numero ${n}`,
    description: '',
    clientRequest: '',
    status: 'active',
    phases: phases(i % 7),
    notes: [],
    order: i,
    taskCode: `T-${i}`,
    taskNumber: i,
    githubBranch: null,
    githubPrNumber: null,
    createdAt: now,
    updatedAt: now,
  });
}
await seed('projects/p1/tasks/t90', {
  title: 'Task in revisione',
  description: '', clientRequest: '', status: 'review', phases: phases(4), notes: [], order: 90,
  taskCode: 'T-90', taskNumber: 90, createdAt: now, updatedAt: now,
});
await seed('projects/p1/tasks/t91', {
  title: 'Task validato',
  description: '', clientRequest: '', status: 'validated', phases: phases(7), notes: [], order: 91,
  taskCode: 'T-91', taskNumber: 91, createdAt: now, updatedAt: now,
});

console.log('seed r5 ok', { admin, PW });
