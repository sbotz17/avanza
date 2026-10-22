# Ambienti — Avanza

## Piattaforma
- **Frontend**: Flutter web (unica piattaforma, nessuna app mobile/store)
- **Backend**: Firebase (Firestore, Auth, Cloud Functions, Hosting)
- **Progetto Firebase**: `avanza-b62d7`
- **Repository**: `sbotz17/avanza` (un repository, due rami)

## Regime rami (un repository, due rami)
| Ramo | Ambiente | URL | Deploy |
|---|---|---|---|
| `main` | Produzione | https://avanza-b62d7.web.app | automatico via CI (`channelId: live`) |
| `claude/epic-galileo-e9a406` e rami `fix/`, `feature/` | Sviluppo/Preview | canale Firebase preview (non live) | automatico via CI (`channelId: preview`) |

> **Regola**: solo `main` va su `live`. I rami di sviluppo usano canali preview temporanei.

## Firestore (produzione)
- Progetto: `avanza-b62d7`
- Regione: `us-central1` (implicita)
- Collezioni principali: `projects`, `projects/{id}/tasks`, `users`

## Firestore (sviluppo/test)
- Stesso progetto Firebase (Avanza non ha un progetto separato di staging)
- Dati di test separati per prefisso o collection distinta (da implementare)

## Cloud Functions
- Runtime: Node.js 20, Gen 2
- Regione: `us-central1`
- Funzione deployata: `githubWebhook` (in attesa validazione Andrea — non ancora in produzione)

## Hosting Firebase
- Public dir: `build/web`
- URL produzione: https://avanza-b62d7.web.app
- Firebase service account deploy: `FIREBASE_SERVICE_ACCOUNT` (segreto GitHub)

## Segreti necessari (GitHub Secrets)
| Nome | Dove | Usato per |
|---|---|---|
| `GITHUB_TOKEN` | automatico GitHub | Firebase Hosting repoToken |
| `FIREBASE_SERVICE_ACCOUNT` | GitHub Secrets | deploy Hosting + Functions |

## Segreti necessari (Firebase Secret Manager)
| Nome | Dove | Usato per |
|---|---|---|
| `GITHUB_WEBHOOK_SECRET` | Firebase Secret Manager (avanza-b62d7) | verifica firma webhook GitHub (Cloud Function) |

## Note
- Nessun ambiente Supabase — il progetto usa esclusivamente Firebase.
- Non ci sono build Android/iOS/Windows — solo Flutter web.
- Il deploy di Cloud Functions richiede ruoli IAM aggiuntivi sul service account (vedi `docs/progetto/produzione.md`).
