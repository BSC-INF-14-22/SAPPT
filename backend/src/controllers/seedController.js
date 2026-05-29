// backend/src/controllers/seedController.js
// ---------------------------------------------------------------
// Controller to trigger backend seed operations for test/demo data.
// ---------------------------------------------------------------
const { runSeed } = require('../../scripts/seedMay16Prices');

const seedMay16Prices = async (req, res, next) => {
  try {
    await runSeed();
    res.status(200).json({
      success: true,
      message: 'May 16 2026 seed data imported successfully.',
    });
  } catch (error) {
    console.error('[Seed Controller] Error:', error);
    next(error);
  }
};

module.exports = { seedMay16Prices };
