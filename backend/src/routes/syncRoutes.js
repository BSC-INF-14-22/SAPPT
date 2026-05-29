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
const { syncFAOPrices } = require('../controllers/faoSyncController');
const { importAcePrices } = require('../controllers/aceImportController');
const { seedMay16Prices } = require('../controllers/seedController');
const { syncCatalogFromPrices } = require('../controllers/catalogSyncController');
const apiKeyMiddleware = require('../middleware/apiKeyMiddleware');

// ─────────────────────────────────────────────────────────────
//  POST /api/sync/world-bank
//  Triggers a pull of indicators from the World Bank API
// ─────────────────────────────────────────────────────────────
router.post('/world-bank', syncWorldBankData);
router.post('/fao-prices', apiKeyMiddleware, syncFAOPrices);
router.post('/ace-import', apiKeyMiddleware, importAcePrices);
router.post('/seed-may16-prices', apiKeyMiddleware, seedMay16Prices);
router.post('/catalog-from-prices', apiKeyMiddleware, syncCatalogFromPrices);
module.exports = router;
