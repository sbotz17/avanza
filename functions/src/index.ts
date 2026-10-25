import { onRequest } from 'firebase-functions/v2/https';
import { githubWebhookHandler } from './githubWebhook';

/**
 * Cloud Function: githubWebhook
 *
 * Receives GitHub webhook events (push, pull_request, pull_request_review, repository)
 * and automatically updates the corresponding task in Firestore. T-20: events from the personal GitHub App
 * are accepted too, and the project of an unknown repository can be created automatically (switch and
 * settings in the Firestore document githubCollegamento/config; off by default).
 *
 * Deployed region: us-central1
 * Secrets (Secret Manager, read at runtime, never in code or logs):
 *   GITHUB_WEBHOOK_SECRET      per-repository webhooks (required)
 *   GITHUB_APP_WEBHOOK_SECRET  GitHub App (optional until created; see docs/progetto/configurazioni-da-fare.md, section 9)
 *
 * Setup:
 *   1. Create secret: gcloud secrets create GITHUB_WEBHOOK_SECRET --data-file=-
 *   2. Grant secretmanager.secretAccessor to the runtime service account.
 *   3. firebase deploy --only functions
 *   4. Copy the function URL to the GitHub repository webhook settings.
 *      Content type must be application/json.
 *      Secret must match GITHUB_WEBHOOK_SECRET.
 */
export const githubWebhook = onRequest(
  {
    region: 'us-central1',
    serviceAccount: 'firebase-adminsdk-fbsvc@avanza-b62d7.iam.gserviceaccount.com',
  },
  githubWebhookHandler
);
