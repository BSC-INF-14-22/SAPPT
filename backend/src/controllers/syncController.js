// ============================================================
//  src/controllers/syncController.js
//
//  WHAT IS A SYNC CONTROLLER?
//  This controller handles automated data integrations from
//  external third-party sources (like the World Bank API).
//  It acts as an automated pipeline:
//    1. Receives the request to sync data
//    2. Calls the external World Bank REST API (Fetch)
//    3. Cleans and structures the data (Parsing & Validating)
//    4. Saves the results to Firestore
//    5. Records the sync event details in 'sync_logs'
// ============================================================

const { db, admin } = require('../config/firebase');

// ─────────────────────────────────────────────────────────────
//  POST /api/sync/world-bank
//  PURPOSE: Sync Agricultural statistics from the World Bank API
//  OPTIONAL QUERY PARAMS / BODY:
//    ?country=MWI         → Filter country (default: Malawi)
//    ?indicator=NV.AGR.TOTL.ZS → Indicator ID (default: Agriculture % of GDP)
//    ?date=2018:2025      → Date range (default: 2018:2025)
// ─────────────────────────────────────────────────────────────
const syncWorldBankData = async (req, res, next) => {
  // Start recording the sync run log
  const startedAt = new Date();
  let syncLogRef = null;

  // Set default values if they are not passed in the request query or body
  const country = req.query.country || req.body.country || 'MWI';
  const indicator = req.query.indicator || req.body.indicator || 'NV.AGR.TOTL.ZS';
  const dateRange = req.query.date || req.body.date || '2018:2025';

  // Construct the World Bank REST API Endpoint
  const apiEndpoint = `http://api.worldbank.org/v2/country/${country}/indicator/${indicator}?format=json&date=${dateRange}`;

  try {
    // 1. Create a "pending" log entry in Firestore first to audit that a sync has started
    syncLogRef = await db.collection('sync_logs').add({
      dataSourceId: 'world_bank_api',
      indicatorId: indicator,
      countryCode: country,
      status: 'pending',
      startedAt: admin.firestore.Timestamp.fromDate(startedAt),
      completedAt: null,
      recordsImported: 0,
      errorMessage: null,
    });

    console.log(`[Sync] Calling World Bank API: ${apiEndpoint}`);

    // 2. Fetch data from World Bank REST API
    const apiResponse = await fetch(apiEndpoint);
    if (!apiResponse.ok) {
      throw new Error(`World Bank API returned HTTP status ${apiResponse.status}`);
    }

    const rawData = await apiResponse.json();

    // The World Bank API returns:
    // rawData[0] -> Page/Query metadata
    // rawData[1] -> Array of records
    const records = rawData[1];

    if (!records || records.length === 0) {
      throw new Error('No records returned from World Bank API.');
    }

    let recordsImportedCount = 0;

    // 3. Process and Clean each record
    for (const record of records) {
      // --- Data Cleaning ---
      // Skip years where the value is missing (null)
      if (record.value === null) {
        console.log(`[Sync] Skipping year ${record.date} because it has no value.`);
        continue;
      }

      const formattedRecord = {
        indicatorName: record.indicator.value, // e.g. "Agriculture, value added (% of GDP)"
        indicatorId: record.indicator.id,     // e.g. "NV.AGR.TOTL.ZS"
        countryCode: record.countryiso3code,   // e.g. "MWI"
        countryName: record.country.value,     // e.g. "Malawi"
        year: parseInt(record.date, 10),       // Ensure year is saved as an integer
        value: parseFloat(record.value.toFixed(2)), // Standardize decimal numbers to two points
        sourceType: 'automated',
        dataSourceId: 'world_bank_api',
        syncLogId: syncLogRef.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // 4. Save to Firestore
      // Generate a unique deterministic Document ID to prevent duplicate entry files
      const docId = `${formattedRecord.countryCode}_${formattedRecord.year}_${formattedRecord.indicatorId}`;
      
      await db.collection('national_statistics')
        .doc(docId)
        .set(formattedRecord, { merge: true });

      recordsImportedCount++;
    }

    const completedAt = new Date();

    // 5. Update the sync log on success
    await syncLogRef.update({
      status: 'success',
      completedAt: admin.firestore.Timestamp.fromDate(completedAt),
      recordsImported: recordsImportedCount,
    });

    res.status(200).json({
      success: true,
      message: 'World Bank indicators synced successfully.',
      syncLogId: syncLogRef.id,
      details: {
        country,
        indicator,
        dateRange,
        recordsProcessed: records.length,
        recordsImported: recordsImportedCount,
      },
    });

  } catch (error) {
    console.error('[Sync Error] Sync failed:', error.message);

    // If we successfully created a sync log doc, update it with the failure status and error message
    if (syncLogRef) {
      await syncLogRef.update({
        status: 'failed',
        completedAt: admin.firestore.Timestamp.now(),
        errorMessage: error.message,
      });
    }

    // Pass the error to the Express global error handler
    next(error);
  }
};

module.exports = { syncWorldBankData };
