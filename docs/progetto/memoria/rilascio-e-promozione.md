# Nodo: Rilascio e promozione staging → main

Ultima revisione: 2026-10-25

- Due rami: `staging` (test, progetto Firebase `avanza-test-c33ef`) e `main` (produzione `avanza-b62d7`). Si lavora su `feature/`, `fix/`, `hotfix/` con PR verso `staging`; mai push/PR verso `main` degli agenti.
- Protezioni (ruleset, applicate il 25/10): `staging` con controlli obbligatori (controlli, zone-protette, regole, nessun-segreto, blocco); `main` solo PR/no force/no cancellazione (senza controlli obbligatori: la PR di promozione la apre la CI). Volty: nessuna protezione (repository privato senza GitHub Pro: scelta di Andrea).
- `promozione.yml`: job `pr` apre/aggiorna la PR staging→main (oggi la #27); job `unione` (T-18) unisce da solo e avvia `rilascio-produzione.yml` SOLO con CI, deploy e controlli verdi e regole/indici Firestore uguali (altrimenti "serve una persona"). `SQUADRA_CI_ATTIVA=si` su Avanza; il job `unione` non è su `main`, quindi la PRIMA promozione è manuale.
- `rilascio-produzione.yml`: controlli, classificazione, backup, prova del sito, ritorno automatico al tag `ultimo-rilascio-ok` (oggi NON esiste). Variabili: `PRODUZIONE_CONTROLLI_COMPLETI=true`, `BUCKET_BACKUP_FIRESTORE`, `SVILUPPI_RICHIEDONO_APPROVAZIONE=no`. Ambiente `produzione` con revisore: da TENERE per la prima promozione.
- Prima promozione: salto di 74 commit / 163 file, regole Firestore diverse (chat). Procedura in `configurazioni-da-fare.md` sezione 7: backup + prova di ripristino IDENTICO, tag di ritorno, audit-completa (`squadra-audit`), unione manuale con merge commit in fascia tranquilla, poi Setup Firestore da `main` e prove a mano (login, chat, Squadra).
- Leve di fermo: `BLOCCO_SQUADRA=ATTIVO` (di Andrea), `SQUADRA_CI_ATTIVA=no`, `BLOCCO-SQUADRA.md`.
- Configurazioni: `scripts/applica-configurazioni.sh` (idempotente; esito 25/10: ruleset ok, variabili ok; webhook Commerciali e budget Google non fatti per mancanza di `gcloud`).
- Documenti: `produzione.md`, `ambienti.md`, `rilasci.md`, `.github/README-CI.md`.
