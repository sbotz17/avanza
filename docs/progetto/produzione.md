# Produzione — Avanza

## Inventario produzione

| Componente | Dettaglio |
|---|---|
| Firebase project | `avanza-b62d7` |
| Hosting URL | https://avanza-b62d7.web.app |
| Cloud Functions | `githubWebhook` — **non ancora deployata** (in attesa validazione Andrea) |
| Firestore | `us-central1`, dati reali degli utenti |
| Auth | Firebase Auth email/password |

## Stato attuale (2026-10-22)

**Flutter web (Hosting)**: in produzione — versione con badge taskCode (T-N) visibile.
Nota: il badge taskCode è una nuova funzionalità non ancora formalmente validata da Andrea (vedi `da-validare.md`), ma è già in produzione perché la CI deployava da `claude/epic-galileo-e9a406` a `channelId: live`. Le correzioni R-2 (spinner infinito) e R-3 (logout al refresh) sono anch'esse già in produzione.

**Cloud Functions**: NON in produzione. Il deploy richiede:
1. Ruoli IAM aggiuntivi sul service account (vedi sotto)
2. Segreto `GITHUB_WEBHOOK_SECRET` in Firebase Secret Manager

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

## Piano di rollback

**Flutter web**: Firebase Hosting mantiene versioni precedenti → `firebase hosting:rollback --project avanza-b62d7` (da fare con il CLI di Andrea).

**Cloud Functions**: versioni precedenti visibili su Google Cloud Console → Cloud Functions → seleziona funzione → "Revisioni".

**Dati Firestore**: nessuna migrazione eseguita finora. Le scritture della Cloud Function sono solo additive (aggiunge note e aggiorna campi nullable).
