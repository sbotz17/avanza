---
description: Realizza o aggiorna il modulo Assistente del progetto (manuale, bot, segnalazioni, novità e problemi risolti)
argument-hint: <fase 1 | fase 2 | aggiorna>
---
Realizza il MODULO ASSISTENTE per questo progetto. $ARGUMENTS

Leggi prima `.claude/modelli/modulo-assistente/SPECIFICA.md` (e gli altri file della cartella). Lavora SOLO nel repository di sviluppo, con il flusso standard (analisi, sviluppo, test, validazione) e la regola di riuso.

1. `analista`: requisiti del modulo adattati al prodotto; usa i valori predefiniti della specifica (avvisi WhatsApp ad Andrea per ogni segnalazione e per ogni rilascio, con testo fisso; fase 2 con tetto di costo basso) e registrali in registro-decisioni.md. Ricorda: la sezione serve SOLO a segnalare malfunzionamenti, mai a chiedere nuove funzioni.
2. `architetto`: integrazione nel progetto e struttura; `dba`: schema delle nuove collezioni Firestore adattato dalla specifica (solo aggiunte) con test delle regole di sicurezza (da definire: la specifica in `.claude/modelli/modulo-assistente/` è scritta per Supabase e va tradotta per Firestore); `designer-frontend`: schermate; `sviluppatore-backend` e `sviluppatore-frontend`: Cloud Functions e schermate Flutter.
3. `redattore-manuale`: manuale iniziale in `docs/progetto/manuale/` dalle funzioni già presenti.
4. `tester` e `validatore` con i criteri di accettazione della specifica (in particolare isolamento fra utenti, rifiuto delle richieste di nuove funzioni, limiti di lunghezza e frequenza, esiti da elenco chiuso).
5. Prepara in `docs/progetto/` le istruzioni di installazione una tantum per Andrea: creazione della routine "Verifica segnalazioni" da `prompt-routine-segnalazioni.md` (SENZA credenziali di produzione), workflow `invia-esiti.yml`, secrets da impostare e limiti di frequenza. La routine e i secrets li crea lui nel suo account (una volta sola).
6. Il rilascio del modulo in produzione passa da `/rilascio` (le modifiche allo schema sono solo aggiunte, ma il protocollo vale comunque).
