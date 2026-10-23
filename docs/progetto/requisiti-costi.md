# Costi di sviluppo, preventivo e produttività

Richiesta di Andrea (2026-10-23): compilare i dati di impiego di sviluppo per ogni task e ricavarne
preventivo (stime), costi reali per fatturare e produttività di ogni elemento della squadra.

## Decisioni (scelte da Andrea)
- **Squadra**: registro unico di agenti e persone, ognuno con tariffa di costo (interna) e di vendita (al cliente).
- **Ore**: dichiarate dalla squadra a fine fase. Sono stime oneste, **non tempi misurati**: gli agenti non hanno un cronometro affidabile.
- **Costo**: ore x tariffa del membro; si distinguono costo reale e importo da fatturare, quindi il margine.

## Dati
- `teamMembers/{id}`: `ownerId`, `name`, `kind` (`agent`|`person`), `role`, `costRate`, `billRate`, `active`, `createdAt`.
- `projects/{p}/timeEntries/{id}`: `taskId`, `taskCode`, `memberId`, `memberName`, `phase`, `hours`, `costRate`, `billRate`
  (congelate alla registrazione), `date`, `note`, `source` (`manual`|`squad`).
- Ogni registrazione incrementa `actualHours` del task in modo atomico.
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
