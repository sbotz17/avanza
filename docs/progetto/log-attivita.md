# Log attività

Registro cronologico di ciò che fanno gli agenti (una riga per attività: `AAAA-MM-GG · agente · cosa · esito`). Il diario tecnico dettagliato è in `diario.md`.

<!-- formato: AAAA-MM-GG · agente · cosa · esito -->
| 2026-10-24 | Promozione automatica staging -> main (T-18): job `unione` in `promozione.yml`, script `promuovi-staging.sh`, `promozione-pr.sh`, `prova-promozione.sh` | Fatto, non provato su GitHub | 39 casi simulati in locale (gh finto, repository git vero); `actionlint` pulito; seconda lettura indipendente da fare; vedi `registro-decisioni.md` |
| 2026-10-24 | T-18 correzioni dopo il RESPINTO del validatore: filtro PR di fork, jq fail-closed, stop se le regole Firestore differiscono, dimensione del salto nella PR, rischio CODEOWNERS dichiarato, runbook prima promozione | Fatto, non provato su GitHub | 57 casi simulati in locale con mutazioni di controllo; actionlint e shellcheck puliti; nuova seconda lettura da fare |
