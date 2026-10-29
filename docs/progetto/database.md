# Database — Avanza (Firestore)

Lo schema completo (collezioni, campi, accessi) sta in `docs/database.md`: è il documento da mantenere aggiornato a ogni modifica.
Regole di sicurezza in `firestore.rules`, indici in `firestore.indexes.json`, pubblicazione con il workflow "Setup Firestore".

## Collezioni
| Collezione | Contenuto | Chi la legge |
|---|---|---|
| `users/{uid}` | profilo e ruolo (`admin` o `client`) | l'utente stesso |
| `users/{uid}/clientProjects/{projectId}` | progetti collegati a un cliente col codice progetto | l'utente stesso |
| `clientAccess/{codice}` | codice progetto → progetto (lettura solo per ID) | utenti autenticati, per ID |
| `projects/{id}` | progetti (nome, indirizzo GitHub, codice cliente, proprietario) | proprietario e clienti collegati |
| `projects/{id}/tasks/{taskId}` | task: stato, fasi, note, codice `T-N` (nessun costo) | proprietario e clienti collegati |
| `projects/{id}/taskCosts/{taskId}` | ore stimate, ore reali, tariffa del task | solo admin |
| `projects/{id}/timeEntries/{id}` | registro ore (membro, fase, ore, tariffe congelate) | solo admin |
| `teamMembers/{id}` | membri della squadra (agenti e persone) con tariffe | solo admin |
| `githubCollegamento/config`, `githubCollegamento/giorno-AAAA-MM-GG` | [T-20] configurazione del collegamento automatico e contatore giornaliero dei progetti creati | nessun client (solo Admin SDK; nessuna regola = negato) |
| `githubRepos/{idRepository}` | [T-20] registro dei repository noti (tracciato / escluso / riammesso) | nessun client (solo Admin SDK) |

## Regole
- Modifiche sempre additive e idempotenti; nessuna cancellazione di dati reali (limite invalicabile).
- Backup verificato prima di ogni modifica ai dati di produzione (export su bucket con blocco di conservazione: da configurare, vedi `registro-decisioni.md`).
- Il database `(default)` di produzione è in `eur3` (regione definitiva). Esiste anche un database vuoto `avanza`, non usato.
