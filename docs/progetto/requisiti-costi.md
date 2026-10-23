# Costi di sviluppo, preventivo e produttività

Richiesta di Andrea (2026-10-23): compilare i dati di impiego di sviluppo per ogni task e ricavarne
preventivo (stime), costi reali per fatturare e produttività di ogni elemento della squadra.

## Decisioni (scelte da Andrea)
- **Squadra**: registro unico di agenti e persone, ognuno con tariffa di costo (interna) e di vendita (al cliente).
- **Ore**: dichiarate dalla squadra a fine fase. Sono stime oneste, **non tempi misurati**: gli agenti non hanno un cronometro affidabile.
- **Costo**: ore x tariffa del membro; si distinguono costo reale e importo da fatturare, quindi il margine.

## Ruoli e visibilità (richiesta di Andrea, 2026-10-23)
- **Un solo login** (email e password). Dopo l'accesso il ruolo (`users/{uid}.role`) decide cosa si vede.
- **Admin**: vede tutto. Il ruolo si assegna solo da script (workflow "Registra ore squadra", azione `admin`) o da console: le regole impediscono ai client di auto-promuoversi.
- **Cliente**: si registra dalla pagina di accesso; al primo accesso inserisce il **codice progetto**, che resta legato al suo account (`users/{uid}/clientProjects/{projectId}`) e non va reinserito. Vede solo i suoi progetti e, per ognuno, stato e dettaglio dei task. Niente costi, tariffe, ore, squadra.
- Il vecchio accesso anonimo con solo codice è **rimosso**: non esiste più alcun accesso senza account.
- Implementazione (le regole Firestore sono l'unica difesa vera: nascondere i pulsanti nell'interfaccia non basta; il router protegge comunque le pagine admin):
  - stime, ore reali e tariffe stanno in `projects/{p}/taskCosts/{taskId}`, leggibile solo dall'admin;
  - il documento `tasks` contiene solo stato e dettaglio: lo leggono proprietario e clienti collegati;
  - il codice progetto è l'ID di `clientAccess/{codice}` (lettura solo per ID, solo utenti autenticati, mai elenco); il collegamento è valido solo se il codice corrisponde al progetto (verificato dalle regole);
  - l'elenco dei progetti è consentito solo al proprietario;
  - `teamMembers` e `timeEntries` sono solo admin.
- Limiti noti: il codice progetto ha 6 caratteri e un utente registrato potrebbe provare a indovinarlo (rischio basso, si può allungare); l'admin non può ancora scollegare un cliente da un progetto (si scollega solo il cliente); il documento del progetto contiene anche `githubUrl` e `ownerId` ed è leggibile ai clienti collegati.

## Dati
- `teamMembers/{id}`: `ownerId`, `name`, `kind` (`agent`|`person`), `role`, `costRate`, `billRate`, `active`, `createdAt`.
- `projects/{p}/timeEntries/{id}`: `taskId`, `taskCode`, `memberId`, `memberName`, `phase`, `hours`, `costRate`, `billRate`
  (congelate alla registrazione), `date`, `note`, `source` (`manual`|`squad`).
- `projects/{p}/taskCosts/{taskId}`: `estimatedHours`, `actualHours`, `hourlyRate` (solo admin).
- Ogni registrazione incrementa `actualHours` in `taskCosts` in modo atomico.
- Accesso: solo il proprietario (contengono tariffe e costi). Regole in `firestore.rules`.

## Calcoli (pagina Costi sviluppo, sezione "Registro ore e produttività")
- **Preventivo** = somma di ore stimate x tariffa del task (come già in uso).
- **Costo reale** = somma ore x tariffa di costo del membro.
- **Da fatturare** = somma ore x tariffa di vendita del membro.
- **Margine** = da fatturare - costo reale. **Scostamento** = da fatturare - preventivo.
- **Produttività di un membro** = ore stimate attribuite / ore reali. La stima di ogni task è ripartita tra i membri in
  proporzione alle ore lavorate su quel task; si considerano solo i task con stima. Sopra 100% = più veloce della stima.

## Come entrano le ore
- **Squadra**: workflow GitHub "Registra ore squadra" (`scripts/registra-ore.mjs`), azioni `membro` e `ore`.
- **Persone**: pulsante "Registra ore" nell'app.

## Limiti noti
- Non esistono stime per fase: la produttività è calcolata per task, non per fase.
- Il campo "ore effettive" del form di modifica task può sovrascrivere il totale delle ore registrate.
- Le tariffe dei membri vanno inserite da Andrea (la squadra le crea a 0 finché non sono decise).
