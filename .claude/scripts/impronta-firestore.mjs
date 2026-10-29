#!/usr/bin/env node
// Impronta di un database Firestore: per ogni collezione (anche le sottocollezioni) stampa
//   nome <TAB> numero_documenti <TAB> hash_del_contenuto
// Il nome della collezione usa * al posto degli ID dei documenti (es. projects/*/tasks).
// Due database con la stessa impronta hanno gli stessi dati. SOLA LETTURA.
// Uso: node impronta-firestore.mjs [--json]
// Variabili: FIRESTORE_PROJECT (default avanza-b62d7), FIRESTORE_DATABASE (default "(default)").
// Credenziali: quelle predefinite di Google (GOOGLE_APPLICATION_CREDENTIALS / gcloud auth application-default).
// Nota: legge tutti i documenti; va bene per database piccoli/medi come quello di Avanza.
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import path from 'node:path';

const require = createRequire(path.resolve('functions/package.json'));
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const PROGETTO = process.env.FIRESTORE_PROJECT || 'avanza-b62d7';
const DATABASE = process.env.FIRESTORE_DATABASE || '(default)';
const JSON_OUT = process.argv.includes('--json');

if (getApps().length === 0) initializeApp({ projectId: PROGETTO });
const db = DATABASE === '(default)' ? getFirestore() : getFirestore(DATABASE);

// Serializzazione canonica: stessi dati => stessa stringa, qualunque sia l'ordine delle chiavi.
function canon(v) {
  if (v === null || v === undefined) return 'null';
  const t = typeof v;
  if (t === 'string') return JSON.stringify(v);
  if (t === 'number' || t === 'boolean') return String(v);
  if (Array.isArray(v)) return '[' + v.map(canon).join(',') + ']';
  const nome = v.constructor?.name;
  if (nome === 'Timestamp') return `T(${v.seconds},${v.nanoseconds})`;
  if (nome === 'GeoPoint') return `G(${v.latitude},${v.longitude})`;
  if (nome === 'DocumentReference') return `R(${v.path})`;
  if (Buffer.isBuffer(v) || v instanceof Uint8Array) return `B(${Buffer.from(v).toString('base64')})`;
  return '{' + Object.keys(v).sort().map((k) => JSON.stringify(k) + ':' + canon(v[k])).join(',') + '}';
}

const gruppi = new Map(); // nome collezione -> righe canoniche

async function visita(colRef, nome) {
  const snap = await colRef.get();
  const lista = gruppi.get(nome) ?? [];
  for (const doc of snap.docs) {
    lista.push(doc.ref.path + '\u0000' + canon(doc.data()));
    for (const sub of await doc.ref.listCollections()) {
      await visita(sub, `${nome}/*/${sub.id}`);
    }
  }
  gruppi.set(nome, lista);
}

for (const col of await db.listCollections()) await visita(col, col.id);

const risultato = [...gruppi.entries()]
  .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
  .map(([nome, righe]) => {
    righe.sort();
    const hash = righe.length ? createHash('sha256').update(righe.join('\n')).digest('hex') : '';
    return { collezione: nome, documenti: righe.length, hash };
  });

if (JSON_OUT) {
  console.log(JSON.stringify({ progetto: PROGETTO, database: DATABASE, collezioni: risultato }, null, 2));
} else {
  for (const r of risultato) console.log(`${r.collezione}\t${r.documenti}\t${r.hash}`);
}
