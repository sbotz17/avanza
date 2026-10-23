# Architettura preferita di Andrea

> Questo file lo legge l'agente `architetto` prima di ogni scelta.
> Andrea: modificalo liberamente (o chiedi a Claude "aggiorna la mia architettura preferita con ...").
> Quello che scrivi qui vince sulle scelte di default dell'architetto.

## Principi generali
- Semplicità prima di tutto: la soluzione più semplice che regge la crescita prevista.
- Codice leggibile e ben separato: interfaccia, logica e dati in livelli distinti.
- Ambienti separati: sviluppo/test e produzione non si mischiano mai durante gli sviluppi. Avanza usa UN repository con DUE rami:
  `staging` (test) e `main` (produzione). Si sviluppa e si correggono i bug solo nello sviluppo (rami `fix/`, `feature/`, `hotfix/` con pull request
  verso `staging`); in produzione si porta tutto con la promozione controllata, dopo test e validazione. Correzioni dirette in produzione (hotfix)
  solo in pochissimi casi di urgenza, e solo passando dalla stessa strada controllata.
- Database (progetto Firebase) separati per sviluppo/test e produzione; mai dati reali nei test.
- Tutto versionato su Git; configurazioni e segreti nei segreti della CI e in Firebase Secret Manager (mai nel codice, mai nel repository).
- Pensato per PMI italiane: lingua italiana, formati data/valuta italiani, attenzione a GDPR.
- Interfacce utilizzabili bene anche da smartphone (mobile-first).

## Stack preferito (di Andrea)
- **Frontend / app: Flutter (Dart).** Per Avanza la piattaforma è solo il **web** (nessuna app mobile né store): è scritto in `docs/progetto/ambienti.md`. Non si sviluppano piattaforme non richieste. Il codice resta unico e condiviso; layout responsive (telefono, tablet, desktop), senza duplicare le schermate. Interfaccia Material 3, testi in italiano.
- **Backend e dati: Firebase** (Firestore, Auth con email e password, Cloud Functions gen2 su Node.js 22, Secret Manager). Le **regole di sicurezza di Firestore** (`firestore.rules`) e gli indici (`firestore.indexes.json`) stanno sotto controllo di versione e sono l'unica difesa vera: nascondere un pulsante nell'app non basta. Ruoli `admin` e `client` in `users/{uid}`. Le credenziali di servizio (service account) non entrano MAI nell'app né nel repository.
- **Web / hosting: Firebase Hosting** (Flutter web). Produzione solo dal ramo `main` tramite la CI; il ramo `staging` pubblica sull'ambiente di test. Niente service worker (`--pwa-strategy=none`) e `Cache-Control: no-cache` per js/css/html/json, così gli aggiornamenti arrivano da soli.
- **Versionamento: Git** (GitHub, repository `sbotz17/avanza`).
- **Ambienti separati anche sui servizi**: due progetti Firebase distinti (test `avanza-test`, produzione `avanza-b62d7`), mai condivisi: database, utenti, funzioni e hosting separati; chiavi e segreti diversi per ciascun ambiente.
- **Compatibilità con le versioni vecchie dell'app (regola chiave):** gli utenti non aggiornano l'app subito e la
  pubblicazione sugli store non è istantanea. Ogni modifica a database e API deve restare compatibile con le versioni
  dell'app già in circolazione (solo aggiunte; rimozioni o rinomine solo in un rilascio successivo, quando le vecchie
  versioni non sono più usate). Per Avanza (solo web, aggiornato a ogni apertura) il rischio è minore, ma resta valida la regola
  di non rimuovere né cambiare significato a campi e collezioni esistenti.

## Decisioni condivise nel tempo
<!-- L'architetto aggiunge qui, con data, le decisioni che Andrea approva e vuole riusare in tutti i progetti. -->
