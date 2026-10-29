---
description: Avvia un nuovo progetto da zero con tutta la squadra di agenti
argument-hint: <idea del progetto in parole tue>
---
Avvia un NUOVO PROGETTO seguendo le regole della squadra in CLAUDE.md.

Idea di Andrea: $ARGUMENTS

Passi:
1. Individua dove sono (o dove creare) il repository e i rami di SVILUPPO (`staging`) e di PRODUZIONE (`main`) (se il progetto è già avviato) e quali progetti/database Firebase di test e produzione usa: cerca prima nel repository e nei file di configurazione; se Andrea non lo ha già detto e non si trova, fai UNA sola domanda iniziale (l'unica necessaria: poi si procede da soli). Registra anche le PIATTAFORME del progetto (solo web | web + mobile | web + mobile + Windows | altro) deducendole da `pubspec.yaml`/cartelle `android/ ios/ windows/ web/` o, se non ricavabili, dalla descrizione di Andrea; se c'è il web, va impostata la variabile GitHub `PIATTAFORMA_WEB` = si (lo fa Andrea nella configurazione una tantum). Firebase Hosting serve solo se c'è il web. Con lo stack di Andrea servono: identificativo del progetto Firebase di sviluppo e di quello di produzione (due progetti distinti; se manca quello di sviluppo, proponi di crearlo), database Firestore e regione, rami Git collegati (`staging` e `main`), se l'app è pubblicata sugli store. Mai scrivere chiavi o password nei file: solo i riferimenti. Registra tutto in `docs/progetto/ambienti.md` (nel repository di sviluppo). Se il progetto ha già una produzione, crea in `.claude/produzione.json` (partendo da .claude/produzione.json.esempio) i riferimenti che la guardia automatica usa per riconoscere la produzione e la cartella dei backup, e crea anche `docs/progetto/produzione.md` con l'inventario di ciò che esiste (collezioni e dati principali, configurazioni, file degli utenti, dove sono i backup e come si ripristinano, come si pubblica) e il registro delle operazioni. Lavora poi solo nello sviluppo.
2. Crea (se mancano) `docs/progetto/` con catalogo.md (vuoto, per categoria), requisiti.md, architettura.md, database.md, design.md, diario.md, ritorni.md, registro-decisioni.md e le cartelle test/, esiti/ e marketing/. Inizializza Git se non c'è (branch main, poi lavora su branch dedicati).
3. Lancia l'agente `analista` sull'idea. Dubbi: l'analista sceglie l'opzione più prudente e il Coordinatore la registra in registro-decisioni.md.
4. Lancia l'`architetto` (leggendo .claude/architettura-preferita.md) e, se ci sono dati, il `dba`; se c'è interfaccia, il `designer-frontend`.
5. Includi nel piano il **modulo Assistente** come modulo standard (manuale, assistente, segnalazioni, novità e problemi risolti; si realizza con `/assistente`).
5b. Scrivi un piano riassuntivo in italiano semplice (funzionalità, architettura, fasi) in docs/progetto/ e procedi senza attendere approvazione; Andrea può correggere la rotta quando vuole.
6. Esegui il flusso standard nel repository di sviluppo: sviluppo → tester → validatore.
