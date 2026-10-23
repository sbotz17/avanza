---
description: Prova o esegue il ripristino del database da un backup, dimostrando che è una fotocopia esatta
argument-hint: <prova | reale> [quale backup]
---
Ripristino del database. $ARGUMENTS

Obiettivo: poter tornare all'ESATTA fotocopia del database com'era al momento del backup, in tempi rapidi e con la prova che nulla manca.

**Prova su copia (sicura, si può fare sempre)**
1. Leggi docs/progetto/ambienti.md e produzione.md (progetto Firebase, bucket dei backup, database di PROVA da usare come copia).
2. Scegli il backup (default: l'ultimo in INDICE-BACKUP.log).
3. Esegui `.claude/scripts/ripristina-firestore.sh --verifica <percorso-backup>` (importa il backup in un database Firestore COPIA, mai nella produzione, e confronta l'impronta dei conteggi e degli hash per collezione).
4. Riferisci nel resoconto: backup integro sì/no, risultato IDENTICO/DIFFERENTE, tempo di ripristino misurato. Annota tutto in produzione.md.

**Ripristino reale (emergenza: dati mancanti o alterati in modo VERIFICATO)**
La squadra lo esegue da sola solo se TUTTE queste condizioni sono vere; altrimenti scrive la decisione in sospeso in registro-decisioni.md, avvisa Andrea e non ripristina:
(a) alterazione/mancanza dei dati dimostrata (confronto con l'impronta o conteggi del backup); (b) esiste una copia di sicurezza fresca dello stato attuale; (c) la prova `--verifica` sul backup scelto ha dato IDENTICO; (d) il ripristino reale di Firestore sovrascrive i dati di produzione: nel progetto Firebase di produzione (`avanza-b62d7`) è SEMPRE una decisione di Andrea (lo script rifiuta e spiega); la squadra prepara analisi, backup scelto, prova IDENTICO sulla copia e passi, e lo avvisa subito.
1. Avvisa subito Andrea (cosa è successo, quale backup, perché le condizioni sono soddisfatte). Non aspettare risposta.
2. `.claude/scripts/ripristina-firestore.sh --ripristina <percorso-backup> --conferma "RIPRISTINA <nome-db>"` (solo su database NON di produzione, o su produzione solo se Andrea lo ha deciso). Lo script fa prima una copia di sicurezza dello stato attuale (nulla va perso, nemmeno lo stato rotto), poi ripristina e confronta l'impronta con quella del backup.
3. Se il risultato non è IDENTICO: fermati, non ritentare alla cieca, riferisci subito le differenze ad Andrea.
4. Registra l'evento in produzione.md e in ritorni.md.
