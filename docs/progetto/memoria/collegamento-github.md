# Nodo: Collegamento di Avanza ai repository GitHub (T-18)

Ultima revisione: 2026-10-25

- Requisiti e decisioni di Andrea: `requisiti-collegamento.md`. Scelte: GitHub App personale a fasi; tutti i repository (anche privati e futuri) tranne fork, archiviati e topic `avanza-ignora`; **nessun task creato da soli** (li crea la squadra con `importa-task`); task vecchi aggiornati solo con prove.
- Funzione `githubWebhook` (`functions/src/`): firma HMAC con due segreti (storico `GITHUB_WEBHOOK_SECRET` per i webhook per-repository; nuovo `GITHUB_APP_WEBHOOK_SECRET` per l'App, facoltativo). Aggiorna i task con codice `T-N` nel ramo/titolo; log strutturato per ogni evento.
- Creazione del progetto da repository sconosciuto: SOLO con firma dell'App, proprietario coerente e ammesso, tetto 5 al giorno, ID `gh_<id repository>`, mai due volte; progetto eliminato non risorge. **Interruttore SPENTO di default** (`githubCollegamento/config`); lo accende solo Andrea con via libera in chat (azione `collegamento note=attiva`; `spegni` è il freno, solo da `main`).
- Approvazioni: promuovono a Validato solo se l'autore è OWNER/MEMBER/COLLABORATOR (prima: chiunque).
- Segreto dell'App: segreto GitHub `GH_APP_WEBHOOK_SECRET` (ambiente `produzione`) → workflow `imposta-segreto-app.yml` → Secret Manager, solo da `main` (dopo la prima promozione). Il valore lo genera Andrea sul suo computer, mai in chat.
- Guida passo-passo: `configurazioni-da-fare.md` sezione 9 (ordine: segreto → App → ping 200 → log `creazione_spenta` e topic → accensione).
- Rischi noti: `topics` assente = esclusione per topic non scatta (fail-open, mitigato dal controllo dei log prima di accendere); chi possiede il segreto storico può cambiare `githubUrl` di un progetto già agganciato (non creare progetti).
- Stato: sviluppato e collaudato (326 test) in `staging`; mai provato con GitHub reale; non in produzione. Webhook di Commerciali: non creato (lo coprirà l'App).
- Task Avanza: T-18. Architettura: `architettura.md` (sezione collegamento), `docs/architettura-integrazione-github.md` (storico).
