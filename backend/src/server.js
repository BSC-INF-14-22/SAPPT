// ============================================================
//  src/server.js  ← THE ENTRY POINT OF YOUR API
//
//  This is where everything comes together.
//  Node.js starts here when you run: node src/server.js
//
//  THE ORDER MATTERS in Express:
//  1. Load environment variables FIRST (before anything else)
//  2. Initialize Firebase
//  3. Create the Express app
//  4. Attach global middleware (cors, json parsing, logging)
//  5. Mount routes
//  6. Attach error handler LAST
//  7. Start listening for requests
// ============================================================

// ── STEP 1: Load environment variables from .env file ──────
// This MUST be the very first line so all other files can
// access process.env.PORT, process.env.FIREBASE_PROJECT_ID, etc.
require('dotenv').config();

// ── STEP 2: Import required packages ───────────────────────
const express = require('express'); // The web framework
const cors    = require('cors');    // Allows Flutter/web apps to call this API
const morgan  = require('morgan');  // Logs every request to the terminal

// ── STEP 3: Import our own files ───────────────────────────
// This triggers Firebase initialization (runs firebase.js once)
require('./config/firebase');

// The central router that connects all route files
const apiRoutes   = require('./routes/index');

// The USSD route (Africa's Talking calls this directly)
const ussdRoutes  = require('./routes/ussdRoutes');

// The global error handler (must be registered last)
const errorHandler = require('./middleware/errorHandler');

// ── STEP 4: Create the Express application ─────────────────
const app = express();

// ── STEP 5: Register Global Middleware ─────────────────────
// Middleware runs for EVERY request, in the order it's registered.

/**
 * CORS (Cross-Origin Resource Sharing)
 * Without this, browsers and mobile apps on different URLs
 * would be BLOCKED from calling your API for security reasons.
 * 
 * In production, replace '*' with your actual domain:
 * origin: 'https://your-app.com'
 */
app.use(cors({ origin: '*' }));

/**
 * JSON Body Parser
 * This lets Express read the body of POST/PUT requests.
 * Without this, req.body would be undefined.
 * 
 * When Flutter sends: { "productName": "Maize", "price": 35.5 }
 * This middleware parses it into a JavaScript object you can use.
 */
app.use(express.json());

/**
 * URL-encoded Body Parser
 * Handles form submissions (not usually needed for REST APIs,
 * but good practice to include).
 */
app.use(express.urlencoded({ extended: true }));

/**
 * Morgan Request Logger
 * Prints a line to the terminal for every request received.
 * Example output:
 *   GET /api/prices 200 45ms - 312
 *   POST /api/prices 201 120ms - 178
 * 
 * 'dev' format: method url status response-time content-length
 */
app.use(morgan('dev'));

// ── STEP 6: Mount All API Routes ───────────────────────────
// All routes defined in routes/index.js will be accessible
// under the /api prefix.
//
// Examples:
//   GET  http://localhost:3000/api/health
//   GET  http://localhost:3000/api/prices
//   POST http://localhost:3000/api/prices
//   GET  http://localhost:3000/api/markets
app.use('/api', apiRoutes);

// ── USSD Route (Africa's Talking Webhook) ──────────────────
// Africa's Talking sends POST requests to /ussd
// This is NOT under /api because AT calls it directly
app.use('/ussd', ussdRoutes);

// ── STEP 7: Root Route (for browser access) ─────────────────
// If someone visits http://localhost:3000 directly
app.get('/', (req, res) => {
  res.status(200).json({
    message: '🌾 Welcome to the SAPPT Agricultural Market Price API',
    documentation: 'See /api/health for status, or /api/prices and /api/markets for data.',
    version: '1.0.0',
  });
});

// ── STEP 8: Global Error Handler ───────────────────────────
// IMPORTANT: This MUST be registered AFTER all routes.
// Express identifies error handlers by their 4 parameters (err, req, res, next).
// Any error passed via next(error) anywhere in the app ends up here.
app.use(errorHandler);

// ── STEP 9: Start the Server ───────────────────────────────
const PORT = process.env.PORT || 3000;

// Save the server instance so we can listen for errors on it
const server = app.listen(PORT, () => {
  console.log('');
  console.log('🌾 ─────────────────────────────────────────────────');
  console.log(`✅  SAPPT API Server running on port ${PORT}`);
  console.log(`🔗  Local:    http://localhost:${PORT}`);
  console.log(`🔗  Health:   http://localhost:${PORT}/api/health`);
  console.log(`🔗  Prices:   http://localhost:${PORT}/api/prices`);
  console.log(`🔗  Markets:  http://localhost:${PORT}/api/markets`);
  console.log(`🔗  USSD:     http://localhost:${PORT}/ussd`);
  console.log('🌾 ─────────────────────────────────────────────────');
  console.log('');
});

// ── Handle port-in-use error gracefully ────────────────────
// Without this, Node.js just crashes with a confusing error.
// With this, you get a clear message telling you what to do.
server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error('');
    console.error(`❌  PORT ${PORT} IS ALREADY IN USE!`);
    console.error('');
    console.error('   Another process is already running on this port.');
    console.error('   Fix it by running this command in PowerShell:');
    console.error('');
    console.error(`   $p = Get-NetTCPConnection -LocalPort ${PORT} | Select-Object -ExpandProperty OwningProcess -Unique; Stop-Process -Id $p -Force`);
    console.error('');
    console.error('   Then run: npm run dev');
    console.error('');
    process.exit(1); // Stop Node.js cleanly
  } else {
    // For any other server error, still show a message
    console.error('❌ Server error:', err.message);
    process.exit(1);
  }
});

// ── Process-level error handlers to improve stability and logging
// These catch crashes, log them, and exit so the platform (Railway)
// can restart the process. They also make debugging easier by
// ensuring stack traces appear in logs.
process.on('unhandledRejection', (reason, promise) => {
  console.error('🚨 Unhandled Rejection at:', promise, 'reason:', reason);
  // Graceful shutdown: stop accepting new connections then exit
  try {
    server.close(() => {
      console.error('Server closed after unhandled rejection. Exiting.');
      process.exit(1);
    });
    // Fallback in case server.close hangs
    setTimeout(() => process.exit(1), 10000).unref();
  } catch (err) {
    console.error('Error during graceful shutdown:', err);
    process.exit(1);
  }
});

process.on('uncaughtException', (err) => {
  console.error('🚨 Uncaught Exception:', err && err.stack ? err.stack : err);
  try {
    server.close(() => {
      console.error('Server closed after uncaught exception. Exiting.');
      process.exit(1);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  } catch (e) {
    console.error('Error during shutdown after uncaught exception:', e);
    process.exit(1);
  }
});

// ── Lightweight periodic health/log output to aid in diagnosing crashes
// Logs memory usage and uptime every 10 minutes. Useful to detect leaks
// or repeated restarts in the Railway logs.
setInterval(() => {
  const mem = process.memoryUsage();
  console.log(`🩺 Health: uptime=${process.uptime().toFixed(0)}s rss=${Math.round(mem.rss/1024/1024)}MB heapUsed=${Math.round(mem.heapUsed/1024/1024)}MB`);
}, 10 * 60 * 1000).unref();

// Export the app (useful for testing with tools like Jest/Supertest)
module.exports = app;
