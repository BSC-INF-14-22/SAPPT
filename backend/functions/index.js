// backend/functions/index.js
// ---------------------------------------------------------------
// Firebase Cloud Function that runs the FAO price sync daily.
// ---------------------------------------------------------------
// This function uses the existing syncFAOPrices controller so the
// same validation, logging and Firestore writes are reused.
// It is scheduled with Cloud Scheduler via `functions.pubsub.schedule`.
// ---------------------------------------------------------------

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { syncFAOPrices } = require('../src/controllers/faoSyncController');

// Ensure Firebase Admin is initialized (idempotent)
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Daily FAO price sync.
 * Runs every 24 hours (UTC). Adjust the cron expression if you need a
 * different timezone or frequency.
 */
exports.dailyFaoSync = functions.pubsub.schedule('every 24 hours')
  .timeZone('Africa/Blantyre') // Malawi timezone (UTC+2)
  .onRun(async (context) => {
    // Create mock Express req/res objects compatible with the controller.
    const req = { query: {}, body: {} };
    const res = {
      status: (code) => {
        return {
          json: (obj) => {
            console.log('[FAO Scheduler] Response:', obj);
            return obj;
          },
        };
      },
    };
    const next = (err) => {
      if (err) console.error('[FAO Scheduler] Error:', err);
    };

    console.log('[FAO Scheduler] Starting daily sync');
    await syncFAOPrices(req, res, next);
    console.log('[FAO Scheduler] Completed');
    return null; // Functions require a return value (void)
  });
