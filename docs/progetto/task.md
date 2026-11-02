# Task attivi — Avanza

Ultima revisione: 2026-10-25 · La fonte vera è l'app Avanza (progetto Avanza). Qui solo l'elenco dei lavori recenti, con i codici REALI.

| Codice | Cosa | Stato | Note |
|---|---|---|---|
| T-17 | Squadra: ruolo a tendina e costi orari | in revisione | unita in `staging` (PR #28); la copia della squadra è stata fatta su produzione |
| T-18 | Avanza collegata a tutti i progetti (GitHub App, progetti automatici) | attivo | fase 1 in `staging` (PR #29), creazione automatica SPENTA |
| T-19 | Correzione: modificare un progetto azzera il contatore T-N | in revisione | R-4, unita in `staging` (PR #30); contatori reali in ordine |
| T-21 | Task: data e ora e richiesta originale visibili | in corso | richiesta di Andrea dell'1/11; ramo `feature/T-21-data-ora-richiesta-task` |
| T-22 | Collegamento GitHub: progetti nuovi e aggiornamento task in tempo reale | in corso | webhook Volty/Commerciali attivi e provati; 4 progetti caricati; creazione automatica da accendere dopo la GitHub App (decisione in sospeso) |
| T-25 | Kanban: mantenere la vista tornando da un task | in corso | richiesta di Andrea del 2/11; ramo `feature/T-25-vista-kanban-persistente` |
| T-24 | Kanban: date visibili e avanzamento non a 0% per i task in corso | in corso | richiesta di Andrea dell'1/11; ramo `feature/T-24-kanban-date-avanzamento` |
| T-23 | Costi squadra: valorizzare la spesa per operatore | in corso | tariffe interne tutte a 0 (decisione di Andrea); avviso in Costi |

Lavori senza task dedicato (da registrare a posteriori): regola "quando fermarsi" (nei rami: T-17 vecchio), promozione automatica (nei rami: T-18 vecchio), script configurazioni (T-16). Vedi `registro-decisioni.md` (dichiarazione del 25/10).
Prossimo: prima promozione `staging` → `main` (con Andrea, dopo audit-completa).
