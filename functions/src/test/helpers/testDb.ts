import { randomUUID } from 'crypto';
import { initializeApp } from 'firebase-admin/app';
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { FakeFirestore } from './fakeFirestore';

export interface TestDb {
  db: Firestore;
  kind: 'emulator' | 'fake';
  /** Svuota tutti i dati di questa istanza di prova. */
  reset(): Promise<void>;
}

/**
 * Database per i test. Di default un Firestore in memoria (gira in CI e ovunque). Se e' impostata
 * FIRESTORE_EMULATOR_HOST (es. con `firebase emulators:exec --only firestore "npx jest"`), gli STESSI test girano
 * contro l'emulatore vero di Firestore, con un progetto di prova diverso per ogni file (nessuna interferenza).
 */
export function makeTestDb(): TestDb {
  const host = process.env['FIRESTORE_EMULATOR_HOST'];
  if (host) {
    const projectId = `demo-avanza-${randomUUID().slice(0, 8)}`;
    const app = initializeApp({ projectId }, `test-${projectId}`);
    const db = getFirestore(app);
    return {
      db,
      kind: 'emulator',
      async reset() {
        await fetch(`http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`, { method: 'DELETE' });
      },
    };
  }
  const fake = new FakeFirestore();
  return { db: fake as unknown as Firestore, kind: 'fake', async reset() { fake.clear(); } };
}
