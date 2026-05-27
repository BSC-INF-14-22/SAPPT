// ============================================================
//  src/cronSimulator.js
//
//  WHAT IS THIS FILE?
//  This script simulates an automated Cloud Function Cron Job.
//  
//  In a production cloud environment (like Firebase / GCP / Railway):
//  - You would deploy a "Cloud Function" triggered by a Cloud Scheduler
//    (e.g., set to run "every morning at 6:00 AM" using cron syntax: `0 6 * * *`).
//  
//  For local development, we simulate this by running a continuous
//  Node.js script that uses `setInterval` to wake up every 60 seconds,
//  perform our database updates, and report back.
//
//  HOW TO RUN IT:
//  Open a terminal in the backend directory and run:
//    node src/cronSimulator.js
// ============================================================

require('dotenv').config();
const { db, admin } = require('./config/firebase');

// Re-use our sync logic directly to avoid code duplication
const { syncWorldBankData } = require('./controllers/syncController');

// Define how often the simulator wakes up (60,000 milliseconds = 1 minute)
const TICK_INTERVAL_MS = 60000;

console.log('🌾 ─────────────────────────────────────────────────');
console.log('⏰  Agricultural Cron Job Simulator Started');
console.log(`⏰  Checking for scheduled sync tasks every ${TICK_INTERVAL_MS / 1000}s...`);
console.log('🌾 ─────────────────────────────────────────────────\n');

// The function that gets executed at every interval tick
async function executeScheduledSync() {
  console.log(`\n[${new Date().toLocaleTimeString()}] ⏰ Cron Alarm Triggered! Starting data synchronization...`);

  // We mock the Express parameters (req, res, next) because we are running
  // the controller function directly in Node, rather than through an HTTP call.
  const mockReq = {
    query: {
      country: 'MWI',
      indicator: 'NV.AGR.TOTL.ZS',
      date: '2020:2025' // Keep historical queries short and fast
    },
    body: {}
  };

  const mockRes = {
    status: (code) => {
      return {
        json: (data) => {
          console.log(`[${new Date().toLocaleTimeString()}] ✅ Sync completed with status ${code}:`, JSON.stringify(data.details));
        }
      };
    }
  };

  const mockNext = (err) => {
    console.error(`[${new Date().toLocaleTimeString()}] ❌ Sync failed during execution:`, err.message);
  };

  // Run the sync function we implemented in syncController.js
  await syncWorldBankData(mockReq, mockRes, mockNext);
}

// 1. Run it immediately upon starting the script so we don't have to wait 60s
executeScheduledSync();

// 2. Set the interval to repeat the execution indefinitely
setInterval(() => {
  executeScheduledSync();
}, TICK_INTERVAL_MS);
