import { onRequest } from 'firebase-functions/v2/https';
import { githubWebhookHandler } from './githubWebhook';

/**
 * Cloud Function: githubWebhook
 *
 * Receives GitHub webhook events (push, pull_request, pull_request_review)
 * and automatically updates the corresponding task in Firestore.
 *
 * Deployed region: us-central1
 * Secret: GITHUB_WEBHOOK_SECRET (Firebase Secret Manager)
 *
 * Setup:
 *   1. firebase secrets:set GITHUB_WEBHOOK_SECRET
 *   2. firebase deploy --only functions
 *   3. Copy the function URL to the GitHub repository webhook settings.
 *      Content type must be application/json.
 *      Secret must match GITHUB_WEBHOOK_SECRET.
 */
export const githubWebhook = onRequest(
  {
    region: 'us-central1',
    secrets: ['GITHUB_WEBHOOK_SECRET'],
  },
  githubWebhookHandler
);
