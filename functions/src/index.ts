import { onRequest } from 'firebase-functions/v2/https';
import { githubWebhookHandler } from './githubWebhook';

/**
 * Cloud Function: githubWebhook
 *
 * Receives GitHub webhook events (push, pull_request, pull_request_review)
 * and automatically updates the corresponding task in Firestore.
 *
 * Deployed region: us-central1
 * Secret: GITHUB_WEBHOOK_SECRET (Secret Manager, read at runtime)
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
