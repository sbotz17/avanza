# Variante "un repository, due rami" — modello di Avanza

Avanza tiene sviluppo e produzione nello stesso repository su due rami: `staging` = ambiente di TEST, `main` = PRODUZIONE.
I workflow veri non sono piu' modelli: stanno in `.github/workflows/` e sono descritti in `.github/README-CI.md` (cosa fa ognuno e cosa deve configurare Andrea).

```
lavoro su feature/..., fix/R-n, hotfix/R-n o sul ramo claude/... della sessione  ->  pull request verso staging
  -> ci.yml (analisi, test, build)  +  controlli-pr.yml (blocco, zone protette, regole Firestore, segreti, classificazione)
  -> merge "squash" in staging  ->  deploy.yml pubblica sul progetto di TEST (se configurato)
  -> promozione.yml apre/aggiorna la pull request  staging -> main  con riepilogo e classificazione
        correzione -> Andrea (o la CI con la sua approvazione) la unisce
        sviluppo   -> WhatsApp ad Andrea: prova sul sito di test, poi approva
  -> main avanza -> rilascio-produzione.yml pubblica in produzione (Hosting live + funzione githubWebhook)
        con PRODUZIONE_CONTROLLI_COMPLETI=true: backup, prova su copia, verifica, tag ultimo-rilascio-ok, ritorno automatico
  -> ogni notte (con BUCKET_BACKUP_FIRESTORE): backup-giornaliero.yml
```

Gli script (`.claude/scripts/`) e le regole (`.claude/zone-protette.json`) dei controlli si prendono dal ramo di DESTINAZIONE: una pull request non
puo' indebolire i controlli che la giudicano.
