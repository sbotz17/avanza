# Validazione R-5 — Kanban: scorrimento verticale e orizzontale

- Data: 2026-11-02
- Validatore: sessione indipendente (diversa da chi ha sviluppato)
- Ramo: `fix/kanban-scorrimento` · PR **#54** verso `staging`
- Commit iniziale esaminato: `ad64f5a`; HEAD al momento del verdetto: `a731d7b`
- Materiale: `ritorni.md` §R-5, report tester `2026-11-02-r5-kanban-scorrimento.md`, prova browser
  `2026-11-02-r5-browser.md`, screenshot `2026-11-02-evidenze-r5/`, `registro-decisioni.md`.

## Revisione statica (primo giro)
- Classificazione: **correzione** di un malfunzionamento confermato, non una funzione nuova.
- Diff rispetto a `origin/staging`: solo widget, test, documentazione e screenshot. **Nessuna zona
  protetta** (`firestore.rules`, permessi, funzioni, CI, configurazioni, dipendenze) toccata.
- `KanbanBoard` è usato solo in `lib/pages/project_page.dart`: nessuna altra schermata coinvolta.
- `_KanbanScrollBehavior` è privato e locale al widget (non cambia il comportamento globale dell'app).
- Nessun codice `T-N` inventato: il task Avanza non è registrabile per il limite delle API GitHub Actions,
  documentato nel registro decisioni.

## Prove rieseguite (secondo giro)
| Prova | Esito |
|---|---|
| `flutter analyze` | 6 avvisi `info` (stessi preesistenti), 0 errori, 0 warning |
| `flutter test` | **118/118 verdi** |
| Prova rossa indipendente (versione pre-fix `d12df7e`) | i **3** test di scorrimento falliscono (`Some tests failed`), poi file ripristinato |
| Screenshot | 4 PNG da 900×700 (come il viewport dichiarato); verticale e orizzontale differiscono per ~49% dei pixel |

**Limite dichiarato dal validatore**: lo strumento di lettura della sua sessione non accetta immagini,
quindi non ha potuto vedere la banda rossa «Running in emulator mode» negli screenshot; l'ha verificata il
coordinatore, che ha anche letto le immagini. Il validatore non ha rilanciato lo script e2e per limite di
passi: la prova browser resta quella documentata dal tester/coordinatore.

## Difetti
Nessun difetto bloccante. Chiuso D-1 (mancava il test del mouse) con test dedicato e prova rossa.

## Aree
| Area | Stato |
|---|---|
| Scorrimento kanban (widget), test automatici, prova rossa | **PROVATA** |
| Kanban nel browser (emulatori locali, 900×700) | **PROVATA** |
| Telefono/tablet fisici, trackpad, rotella orizzontale | **BLOCCATA** (non provabili in questa sessione) |

## Verdetto
**APPROVATO** — correzione minima e isolata, prove automatiche rieseguite, prova rossa confermata,
documentazione coerente.

## Prima di pubblicare
Restano obbligatori l'**audit-completa** e il **GO del guardiano** prima di `staging` e produzione.
La PR #54 non è stata unita.
