---
description: Correzione urgente in corsia prioritaria (stessa strada sicura delle correzioni, mai direttamente in produzione)
argument-hint: <descrizione dell'emergenza>
---
Gestisci un'URGENZA. Situazione: $ARGUMENTS

Urgenza vera = servizio fermo, perdita di dati in corso, falla di sicurezza, blocco totale degli utenti. L'urgenza accorcia i tempi, mai le verifiche. Gli agenti non lavorano mai direttamente nel repository o nel database di produzione.

0. Se il problema è comparso subito dopo un rilascio: controlla che la CI abbia già riportato il codice alla versione precedente (job `torna-indietro`). È la prima difesa.
1. Verifica che il malfunzionamento sia reale (riprodotto o osservato direttamente dalla squadra, mai solo segnalato da terzi). Se non è urgente, usa `/ritorno`.
2. Avvisa subito Andrea in poche righe (problema, correzione minima prevista, rischi per i dati) e scrivi la decisione e il motivo dell'urgenza in registro-decisioni.md (il commit fa partire l'avviso WhatsApp). Non attendere risposta.
3. `gestore-ritorni` registra il ritorno come urgente; metti in pausa gli altri lavori.
4. `risolutore-bug` corregge su `hotfix/R-<n>` con la modifica minima e un test che dimostra il problema; `tester` e `validatore` con priorità.
5. Pull request con `R-<n>` nel titolo ed etichetta `tipo:correzione`: con i controlli verdi entra e la CI la rilascia da sola (backup, copia esterna, prova su copia, verifica finale, ritorno automatico se qualcosa va storto).
6. Se la correzione richiede una modifica a regole di sicurezza, indici, dati o una zona protetta, è sviluppo: prepara tutto, scrivi la voce in `da-validare.md` indicando URGENTE e chiedi ad Andrea il tocco immediato su GitHub.
7. Se non esiste una correzione sicura per questa strada (es. serve intervenire sui dati), NON improvvisare: prepara analisi e passi per Andrea (decisione in sospeso URGENTE).
8. Resoconto breve ad Andrea a cose fatte: cosa è stato corretto, verifiche e risultati.
