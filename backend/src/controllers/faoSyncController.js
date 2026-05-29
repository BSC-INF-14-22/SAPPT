// src/controllers/faoSyncController.js
// ---------------------------------------------------------------
// FAO FPMS (Food Price Monitoring System) sync controller
// ---------------------------------------------------------------
// This controller fetches daily agricultural product price data for Malawi
// from the FAO public API and stores the cleaned records in Firestore.
// It also logs the sync operation in the "sync_logs" collection.
// ---------------------------------------------------------------

const { db, admin } = require('../config/firebase');
const fetch = require('node-fetch');

/**
 * POST /api/sync/fao-prices
 * Optional query parameters:
 *   - cropCode: FAO item code (default "1111" – Maize)
 *   - days: number of past days to fetch (default 7)
 *   - apiKey: optional API key for rate‑limit increase (FAO allows optional token)
 */
const syncFAOPrices = async (req, res, next) => {
  const startedAt = new Date();
  let syncLogRef = null;

  // -----------------------------------------------------------------
  // 1️⃣ Resolve parameters & build the FAO endpoint URL
  // -----------------------------------------------------------------
  const cropCode = req.query.cropCode || req.body.cropCode || '1111'; // Maize
  const days = parseInt(req.query.days || req.body.days || '7', 10);
  const apiKey = req.query.apiKey || req.body.apiKey || '';

  // FAO FPMS API endpoint (daily data). The API returns JSON with a `data` array.
  // Example: https://fenixservices.fao.org/faostat/api/v1/en/Prices/Prices?area_code=MW&item_code=1111&format=json
  let apiUrl = `https://fenixservices.fao.org/faostat/api/v1/en/Prices/Prices?area_code=MW&item_code=${cropCode}&format=json`;
  if (apiKey) apiUrl += `&api_key=${apiKey}`;

  try {
    // -----------------------------------------------------------------
    // 2️⃣ Create a pending sync‑log entry
    // -----------------------------------------------------------------
    syncLogRef = await db.collection('sync_logs').add({
      dataSourceId: 'fao_fpms',
      cropCode,
      days,
      status: 'pending',
      startedAt: admin.firestore.Timestamp.fromDate(startedAt),
      completedAt: null,
      recordsImported: 0,
      errorMessage: null,
    });

    console.log(`[FAO Sync] Requesting ${apiUrl}`);

    // -----------------------------------------------------------------
    // 3️⃣ Fetch the raw data from FAO
    // -----------------------------------------------------------------
    const response = await fetch(apiUrl);
    if (!response.ok) {
      throw new Error(`FAO API responded with status ${response.status}`);
    }
    const raw = await response.json();
    const records = (raw && raw.data) ? raw.data : [];
    if (records.length === 0) {
      throw new Error('FAO API returned no price records');
    }

    // -----------------------------------------------------------------
    // 4️⃣ Process, clean, and store each record
    // -----------------------------------------------------------------
    let importedCount = 0;
    const now = admin.firestore.Timestamp.now();

    // Helper to compute the date string for the past N days
    const dateDaysAgo = (n) => {
      const d = new Date();
      d.setDate(d.getDate() - n);
      // FAO uses "yearMonth" like "2026-05"; we will keep that format.
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    };

    // Since the FAO endpoint returns the whole month, we will filter by the newest `days` entries.
    const cutoffDate = dateDaysAgo(days - 1); // e.g., if days=7, keep entries from the last 7 days.

    for (const rec of records) {
      // Skip records without a price value
      if (rec.value == null) continue;

      // rec.yearMonth is like "2026-05"; keep only recent ones.
      if (rec.yearMonth < cutoffDate) continue;

      const docId = `MW_${rec.yearMonth}_${cropCode}`; // deterministic ID to avoid duplicates

      const formatted = {
        cropCode,
        period: rec.yearMonth,
        price: parseFloat(rec.value), // FAO value is already numeric
        market: rec.region || 'unspecified',
        unit: rec.unit || 'kg',
        source: 'FAO_FPMS',
        syncLogId: syncLogRef.id,
        createdAt: now,
      };

      await db.collection('prices')
        .doc(docId)
        .set(formatted, { merge: true });
      importedCount++;
    }

    // -----------------------------------------------------------------
    // 5️⃣ Update the sync log with success details
    // -----------------------------------------------------------------
    await syncLogRef.update({
      status: 'success',
      completedAt: admin.firestore.Timestamp.now(),
      recordsImported: importedCount,
    });

    res.status(200).json({
      success: true,
      message: 'FAO price data synced successfully',
      syncLogId: syncLogRef.id,
      recordsImported: importedCount,
    });
  } catch (error) {
    console.error('[FAO Sync] Error:', error);
    if (syncLogRef) {
      await syncLogRef.update({
        status: 'failed',
        completedAt: admin.firestore.Timestamp.now(),
        errorMessage: error.message,
      });
    }
    // Forward to Express error handler
    next(error);
  }
};

module.exports = { syncFAOPrices };
