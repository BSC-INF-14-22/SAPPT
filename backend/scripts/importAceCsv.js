// backend/scripts/importAceCsv.js
// ---------------------------------------------------------------
// Imports ACE market‑price CSV (2024 column) into Firestore "prices"
// collection. Intended to be run as a Cloud Function or via CLI.
// ---------------------------------------------------------------
const admin = require('firebase-admin');
const https = require('https');
const { parse } = require('csv-parse/sync'); // sync parser (installed via npm i csv-parse)

// URL of the public CSV export (Google Sheets)
const CSV_URL = 'https://docs.google.com/spreadsheets/d/1_YdKO4UEvqZHuRyR1mq96jI9l_vzfF1-wM-8DgZlhc4/export?format=csv&gid=325879878';

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

async function fetchCsv() {
  return new Promise((resolve, reject) => {
    https.get(CSV_URL, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

function cleanPrice(raw) {
  // Remove surrounding quotes, commas, and possible spaces
  if (!raw) return null;
  const stripped = raw.replace(/"/g, '').replace(/,/g, '').trim();
  const num = parseFloat(stripped);
  return isNaN(num) ? null : num;
}

async function importAceCsv() {
  console.log('[ACE Import] Fetching CSV');
  const csvText = await fetchCsv();
  // Parse CSV, treating empty first column as optional
  const records = parse(csvText, {
    trim: true,
    skip_empty_lines: true,
  });

  // Find header row (contains "COMMODITY")
  const headerIdx = records.findIndex((r) => r.includes('COMMODITY'));
  if (headerIdx === -1) throw new Error('Header row not found');
  const header = records[headerIdx];
  const year2024Idx = header.findIndex((c) => c && c.includes('2024'));
  const commodityIdx = header.findIndex((c) => c && c.toUpperCase().includes('COMMODITY'));
  if (year2024Idx === -1 || commodityIdx === -1) {
    throw new Error('Required columns not found');
  }

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  // Process rows after header
  for (let i = headerIdx + 1; i < records.length; i++) {
    const row = records[i];
    const commodity = row[commodityIdx];
    const priceRaw = row[year2024Idx];
    const price = cleanPrice(priceRaw);
    if (!commodity || price === null) continue; // skip incomplete rows

    const docRef = db.collection('prices').doc();
    batch.set(docRef, {
      name: commodity,
      price: price,
      year: 2024,
      source: 'ACE',
      importedAt: now,
    });
  }

  console.log('[ACE Import] Writing', batch._ops.length, 'documents');
  await batch.commit();
  console.log('[ACE Import] Completed');
}

// Export for Cloud Function use
module.exports = { importAceCsv };
