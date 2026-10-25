---
description: "Censisce gli oggetti del progetto in un catalogo ordinato per categoria e segnala i duplicati"
agent: coordinatore
---

Costruisci o aggiorna `docs/progetto/catalogo.md` e segnala i duplicati. $ARGUMENTS

1. `architetto`: leggi la struttura del progetto (e `architettura.md`, se esiste) e definisci le categorie e le convenzioni di nome (es. Widget condivisi, Tema e costanti, Modelli, Repository/Servizi, Schermate, Regole di sicurezza Firestore, Cloud Functions, Script di amministrazione, Utilità).
2. Scansiona il codice (Flutter in `lib/`, Cloud Functions in `functions/`, regole in `firestore.rules`, script in `scripts/`) e per ogni oggetto riutilizzabile registra: nome, categoria, percorso, a cosa serve, dove è usato.
3. Cerca duplicati e quasi-duplicati (stesso widget in più versioni, stesse query o funzioni, stesse policy riscritte tabella per tabella, costanti e testi ripetuti, regole di business implementate due volte). Per ciascuno: percorsi, differenze reali, proposta di unificazione (oggetto condiviso, nome, cartella).
4. Scrivi in coda al catalogo la sezione "Duplicati da unificare", in ordine di beneficio e basso rischio.
5. NON modificare il codice in questo comando: scrivi un riepilogo breve (quanti oggetti, quanti duplicati, i 3-5 più utili da unificare) in registro-decisioni.md e riferiscilo ad Andrea. L'unificazione si farà poi a piccoli passi con `/sviluppo`, con test prima e dopo.
