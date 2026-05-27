// ============================================================
//  src/routes/index.js  (The "Root Router" / API Index)
//
//  WHAT THIS FILE DOES:
//  This is the CENTRAL HUB that connects all route files.
//  Instead of defining every route in server.js, we organize
//  them into groups (prices, markets) and mount each group here.
//
//  HOW MOUNTING WORKS:
//  app.use('/api/prices', priceRoutes)
//  means: "For any request starting with /api/prices,
//           hand it off to the priceRoutes router."
//
//  So inside priceRoutes.js, router.get('/') actually means
//  the full path is: GET /api/prices/
//
//  This keeps server.js clean and routes organized by feature.
// ============================================================

const express = require('express');
const router  = express.Router();

// Import each feature's router
const priceRoutes  = require('./priceRoutes');
const marketRoutes = require('./marketRoutes');
const syncRoutes   = require('./syncRoutes');

// ─────────────────────────────────────────────────────────────
//  Health Check Route
//  GET /api/health
//  PURPOSE: Lets you quickly check if the API is running.
//  Try it: open your browser at http://localhost:3000/api/health
// ─────────────────────────────────────────────────────────────
router.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: '✅ SAPPT API is running.',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

// ─────────────────────────────────────────────────────────────
//  Mount Feature Routers
//
//  All price routes:  /api/prices  → priceRoutes.js
//  All market routes: /api/markets → marketRoutes.js
//  All sync routes:   /api/sync    → syncRoutes.js
// ─────────────────────────────────────────────────────────────
router.use('/prices',  priceRoutes);
router.use('/markets', marketRoutes);
router.use('/sync',    syncRoutes);

// ─────────────────────────────────────────────────────────────
//  404 Handler for unknown /api/... routes
//  If a request reaches here, no route matched it
// ─────────────────────────────────────────────────────────────
router.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
    hint: 'Available routes: /api/health, /api/prices, /api/markets',
  });
});

module.exports = router;
