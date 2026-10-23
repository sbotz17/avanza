---
description: Esegue il flusso completo analisi → sviluppo → test → validazione per una funzionalità
argument-hint: <cosa vuoi sviluppare>
---
Esegui il FLUSSO STANDARD DI SVILUPPO descritto in CLAUDE.md per questa richiesta:

$ARGUMENTS

Lavora SOLO nel repository di sviluppo (verifica docs/progetto/ambienti.md e git remote -v); non toccare la produzione. Applica la regola di riuso (cerca in catalogo.md e nel codice, riusa, crea solo se serve e registra nel catalogo). Coinvolgi solo gli agenti necessari (analista sempre; architetto, dba, designer-frontend se pertinenti), poi sviluppatori (in parallelo se i blocchi sono indipendenti), poi `tester` e infine `validatore`. Tester e validatore sono sempre obbligatori. Massimo 3 cicli di correzione. Lavora su un ramo `feature/...` (o sul ramo assegnato dalla sessione) con pull request verso `staging`, mai verso `main`. Se è un NUOVO SVILUPPO: a fine lavoro, con APPROVATO, la pull request resta aperta, prepari `docs/progetto/da-validare.md` (cosa fa, link di anteprima, test, rischi) e lo fai arrivare nel ramo (parte l'avviso WhatsApp); dopo la validazione di Andrea la pull request si unisce e lui approva su GitHub. Se invece è una correzione di un malfunzionamento, segui `/ritorno`. Concludi con un resoconto breve per Andrea: cosa è stato fatto, come provarlo, cosa resta aperto.
