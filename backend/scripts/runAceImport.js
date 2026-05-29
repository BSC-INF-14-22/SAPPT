// backend/scripts/runAceImport.js
// ---------------------------------------------------------------
// Simple runner that executes the ACE CSV import.
// ---------------------------------------------------------------
const { importAceCsv } = require('./importAceCsv');

(async () => {
  try {
    await importAceCsv();
    console.log('✅ ACE market prices imported successfully');
    process.exit(0);
  } catch (err) {
    console.error('❌ Import failed:', err);
    process.exit(1);
  }
})();
