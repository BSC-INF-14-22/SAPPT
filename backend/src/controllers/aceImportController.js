// backend/src/controllers/aceImportController.js
// ---------------------------------------------------------------
// Controller that invokes the ACE market‑price CSV import script.
// It can be called via an HTTP endpoint to bring the latest 2024
// prices into the Firestore `prices` collection.
// ---------------------------------------------------------------

const { importAceCsv } = require('../../scripts/importAceCsv');

/**
 * POST /api/sync/ace-import
 * Optional: protect with API‑key middleware if desired.
 */
async function importAcePrices(req, res, next) {
  try {
    await importAceCsv();
    res.status(200).json({
      success: true,
      message: 'ACE market prices imported successfully',
    });
  } catch (err) {
    console.error('[ACE Import] Error:', err);
    next(err);
  }
}

module.exports = { importAcePrices };
