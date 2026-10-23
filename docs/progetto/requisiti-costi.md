# Costi di sviluppo, preventivo e produttività

Richiesta di Andrea (2026-10-23): compilare i dati di impiego di sviluppo per ogni task e ricavarne
preventivo (stime), costi reali per fatturare e produttività di ogni elemento della squadra.

## Decisioni (scelte da Andrea)
- **Squadra**: registro unico di agenti e persone, ognuno con tariffa di costo (interna) e di vendita (al cliente).
- **Ore**: dichiarate dalla squadra a fine fase. Sono stime oneste, **non tempi misurati**: gli agenti non hanno un cronometro affidabile.
- **Costo**: ore x tariffa del membro; si distinguono costo reale e importo da fatturare, quindi il margine.

## Ruoli e visibilità (richiesta di Andrea, 2026-10-23)
- **Cliente** (accede con il codice cliente): vede solo lo stato dei task e il loro dettaglio. Niente costi, tariffe, ore, squadra.
- **Admin** (proprietario, accede con email e password): vede tutto.
- Implementazione (le regole Firestore sono l'unica difesa vera: nascondere i pulsanti nell'interfaccia non basta):
  - le stime, le ore reali e le tariffe stanno in `projects/{p}/taskCosts/{taskId}`, leggibile solo dall'admin;
  - il documento `tasks` contiene solo stato e dettaglio ed è l'unico leggibile dal cliente;
  - il codice cliente è l'ID di un documento `clientAccess/{codice}` che indica il progetto: si legge solo per ID, non si può elencare;
  - l'elenco dei progetti è consentito solo al proprietario: nessuno può enumerare i progetti degli altri;
  - `teamMembers` e `timeEntries` sono solo admin.
- Limite residuo: il documento del progetto resta leggibile da chi ne conosce l'ID (serve al cliente) e contiene anche `githubUrl` e `ownerId`.

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
