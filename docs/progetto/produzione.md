# Produzione — Avanza

## Inventario produzione

| Componente | Dettaglio |
|---|---|
| Firebase project | `avanza-b62d7` |
| Hosting URL | https://avanza-b62d7.web.app |
| Cloud Functions | `githubWebhook` — **deployata** (gen2, `us-central1`, Node.js 22, via `gcloud` in CI) |
| Firestore | `us-central1`, dati reali degli utenti |
| Auth | Firebase Auth email/password |

## Stato attuale (2026-10-23)

**Flutter web (Hosting)**: in produzione — versione con badge taskCode (T-N) visibile.
Nota: il badge taskCode è una nuova funzionalità non ancora formalmente validata da Andrea (vedi `da-validare.md`), ma è già in produzione perché la CI deployava da `claude/epic-galileo-e9a406` a `channelId: live`. Le correzioni R-2 (spinner infinito) e R-3 (logout al refresh) sono anch'esse già in produzione.

**Cloud Functions**: deployata il 2026-10-23 (CI run #44, step "Deploy Cloud Functions" riuscito). Il deploy usa `gcloud functions deploy --gen2` e non `firebase-tools`, che avrebbe richiesto il ruolo Cloud Functions Admin. Il segreto `GITHUB_WEBHOOK_SECRET` è letto a runtime da Secret Manager.
Non ancora verificato: risposta HTTP della funzione e configurazione dei webhook GitHub sui repository.

## Requisiti IAM per deploy Cloud Functions

Service account: `firebase-adminsdk-...@avanza-b62d7.iam.gserviceaccount.com`

Ruoli necessari (da aggiungere su Google Cloud Console → IAM):
- `Cloud Functions Developer`
- `Cloud Run Admin`
- `Service Account User`
- `Artifact Registry Writer` (per Gen 2)

## Backup

Avanza usa Firebase/Firestore — i backup automatici di Firestore non sono attivati per impostazione predefinita.
**Prima di qualsiasi migrazione dati, attivare export Firestore su Cloud Storage** (da configurare).

## Registro operazioni

| Data | Operazione | Esito | Note |
|---|---|---|---|
| 2026-10-22 | Deploy Flutter web (CI automatica) | OK | Branch `claude/epic-galileo-e9a406` → live. Include badge taskCode, R-2, R-3 |
| 2026-10-22 | Deploy Cloud Functions | FALLITO (IAM mancanti) | La CI ha tentato ma mancano i ruoli IAM sul service account |
| 2026-10-23 | Deploy Cloud Functions (firebase-tools, run #37 e #40) | FALLITO | Prima API Cloud Billing, poi permesso `cloudfunctions.functions.setIamPolicy` |
| 2026-10-23 | Deploy Cloud Functions `githubWebhook` (gcloud, run #44) | OK | Gen2, Node.js 22, `--allow-unauthenticated`; la firma HMAC protegge l'endpoint. Risposta HTTP non verificata |

## Piano di rollback

**Flutter web**: Firebase Hosting mantiene versioni precedenti → `firebase hosting:rollback --project avanza-b62d7` (da fare con il CLI di Andrea).

**Cloud Functions**: versioni precedenti visibili su Google Cloud Console → Cloud Functions → seleziona funzione → "Revisioni".

**Dati Firestore**: nessuna migrazione eseguita finora. Le scritture della Cloud Function sono solo additive (aggiunge note e aggiorna campi nullable).
