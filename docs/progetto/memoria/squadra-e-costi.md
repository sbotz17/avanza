# Nodo: Squadra, ruoli e costi orari

Ultima revisione: 2026-10-25

- Pagina Squadra (`lib/pages/admin/team_page.dart`): elenco dei membri con tipo (Agente/Persona), ruolo, costo e vendita orari. Il ruolo è un menu a tendina con 13 ruoli (`kMemberRoles` in `lib/core/constants.dart`) più "Altro…"; un ruolo già salvato non viene mai perso.
- Dati: collezione `teamMembers` (campo `ownerId`); le regole mostrano a ciascuno SOLO i propri membri.
- Fatto accertato (24/10/2026): i 12 membri erano intestati a `simone370@gmail.com`, i progetti ad Andrea (`bottiandrea83@gmail.com`): pagina vuota. Azione `copia-squadra` (solo aggiunte, backup prima): ora i membri sono 24 (12 di Simone invariati + 12 di Andrea con `copiedFrom`). Annullamento = cancellazione: solo con Andrea.
- Costi orari: tutti a 0 al 25/10. **Li imposta Andrea a mano** dalla pagina Squadra (campo "Costo orario interno"). Il costo viene copiato nelle ore al momento della registrazione: non cambia le ore già registrate a costo 0.
- Effetto noto: nei report la stessa persona può comparire con vecchio e nuovo id; i totali non cambiano.
- Ore: azione `ore` del workflow "Registra ore squadra" (`scripts/registra-ore.mjs`); `findMember` cerca per `ownerId` del progetto. Le ore non sono quasi mai state dichiarate: stime oneste, mai inventate.
- Test: `test/team_page_test.dart`, `test/team_page_tester_test.dart` (report: `test/2026-10-24-t19-squadra-ruolo.md`).
- Manuale utente: `manuale/squadra.md`. Requisiti costi: `requisiti-costi.md`.
