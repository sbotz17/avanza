// Carica regole diverse sull'EMULATORE in esecuzione (mai produzione): node setrules.mjs <file>
import fs from 'fs';
const f = process.argv[2];
const r = await fetch('http://127.0.0.1:8080/emulator/v1/projects/avanza-test-c33ef:securityRules', {
  method: 'PUT', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ rules: { files: [{ name: 'firestore.rules', content: fs.readFileSync(f, 'utf8') }] } }),
});
console.log('setrules', f.split('/').pop(), r.status, (await r.text()).slice(0, 200));
