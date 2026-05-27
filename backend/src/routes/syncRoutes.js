// ============================================================
//  src/routes/syncRoutes.js
//
//  WHAT THIS FILE DOES:
//  This file maps paths related to integration synchronizations
//  to their controller functions.
//
//  Mounted at: /api/sync
// ============================================================

const express = require('express');
const router  = express.Router();

// Import the sync controller
const { syncWorldBankData } = require('../controllers/syncController');

// ─────────────────────────────────────────────────────────────
//  POST /api/sync/world-bank
//  Triggers a pull of indicators from the World Bank API
// ─────────────────────────────────────────────────────────────
router.post('/world-bank', syncWorldBankData);

module.exports = router;
