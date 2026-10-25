# Indice del progetto — Avanza

Ultima revisione: 2026-10-25 · Ogni lavoro parte da qui: si apre solo il nodo dell'area pertinente (`memoria/`), poi i documenti indicati.
Stato rapido: `LEGGI-PRIMA.md` · Decisioni: `registro-decisioni.md` · Rilasci: `rilasci.md` · Task: `task.md` (e l'app Avanza).

## Aree, file chiave, dove guardare
| Area | File chiave | Nodo di memoria | Documenti |
|---|---|---|---|
| App Flutter (pagine, widget, modelli) | `lib/app.dart`, `lib/pages/`, `lib/pages/admin/`, `lib/widgets/`, `lib/models/` | `memoria/app-flutter.md` | `catalogo.md`, `architettura.md` |
| Squadra e costi orari | `lib/pages/admin/team_page.dart`, `time_report.dart`, `costs_page.dart` | `memoria/squadra-e-costi.md` | `requisiti-costi.md`, `manuale/squadra.md` |
| Dati Firestore | `firestore.rules`, `firestore.indexes.json`, `docs/database.md` | `memoria/dati-firestore.md` | `database.md`, `docs/database.md` |
| Collegamento GitHub (webhook, App, progetti automatici) | `functions/src/githubWebhook.ts`, `functions/src/lib/` | `memoria/collegamento-github.md` | `requisiti-collegamento.md`, `docs/*-integrazione-github.md` |
| Rilascio e promozione | `.github/workflows/{rilascio-produzione,promozione,ci,deploy,controlli-pr}.yml`, `.claude/scripts/` | `memoria/rilascio-e-promozione.md` | `produzione.md`, `ambienti.md`, `rilasci.md` |
| Sicurezza, limiti, regole della squadra | `AGENTS.md`, `CLAUDE.md`, `.claude/skills/squadra-*`, `.claude/zone-protette.json` | `memoria/sicurezza-e-limiti.md` | `regole-globali-squadra.md`, `registro-decisioni.md` |
| Registro task e ore in Avanza | `scripts/registra-ore.mjs`, `.github/workflows/registra-ore.yml` | (in `collegamento-github.md`) | `protocollo-task.md` |
| Configurazioni GitHub/Google | `scripts/applica-configurazioni.sh` | `memoria/rilascio-e-promozione.md` | `configurazioni-da-fare.md` |
| Test e collaudi | `test/`, `functions/src/test/` | — | `docs/progetto/test/*`, `ritorni.md` |

## Memoria viva (si aggiorna a ogni lavoro)
`diario.md` (tecnico), `log-attivita.md` (una riga per attività), `registro-decisioni.md` (decisioni e dichiarazioni), `catalogo.md` (oggetti riusabili), `ritorni.md` (bug).

## Da sistemare (segnalato il 2026-10-25, non ancora corretto)
- **Obsoleti**: `da-validare.md` (sostituito da `rilasci.md`; la voce [1] dice ancora "in attesa di validazione Andrea", che non vale più); `LEGGI-PRIMA.md` (aggiornato al 23/10, ora riallineato nelle sezioni stato/ambienti); `architettura.md` (dice che `avanza-test` è da creare e che i workflow sono "in preparazione"; elenco azioni di `registra-ore.mjs` incompleto); `docs/requisiti-integrazione-github.md` e `docs/architettura-integrazione-github.md` (400+ righe, anteriori a T-18/`requisiti-collegamento.md`); `README.md` (2 righe).
- **Formato**: `log-attivita.md` ha righe senza intestazione e formati misti; `registro-decisioni.md` (275+ righe) e `diario.md` (220 righe) sono lunghi: valutare un archivio per mese.
- **Mancano rispetto alle regole sincronizzate**: `task.md` (creato ora), `docs/progetto/test/audit-completa.md` (da produrre prima della prima promozione).
- **Non mappati / da capire**: `opencode.jsonc` e comandi OpenCode (PR #31); cartelle `android/`, `ios/` (Avanza è solo web); `SETUP.md` (configurazione Firebase, data da verificare); `.claude/modelli/`.
