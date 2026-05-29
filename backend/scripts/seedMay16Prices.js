// backend/scripts/seedMay16Prices.js
// ---------------------------------------------------------------
// Seed the Firestore prices collection with trusted cooperative
// uploads dated 16 May 2026. This script also ensures the
// required products and a cooperative officer user exist.
// ---------------------------------------------------------------
require('dotenv').config();
const { db, admin } = require('../src/config/firebase');
const fixedDate = new Date(Date.UTC(2026, 4, 16, 0, 0, 0));
const publishedAt = admin.firestore.Timestamp.fromDate(fixedDate);
const createdAt = publishedAt;

const coopOfficerUid = 'seed-coop-officer-20260516';
const coopOfficer = {
  fullName: 'Seed Cooperative Officer',
  email: 'seedcoop@backend.local',
  role: 'Cooperative Officer',
  district: 'Lilongwe',
  status: 'approved',
  createdAt,
};

const entries = [
  { cropName: 'Cassava-dried', district: 'Nkhotakota', market: 'Benga Market', price: 1200 },
  { cropName: 'Cassava-dried', district: 'Nkhata Bay', market: 'Chintheche Market', price: 1200 },
  { cropName: 'Cassava-dried', district: 'Karonga', market: 'Chilumba Market', price: 1200 },
  { cropName: 'Cassava-dried', district: 'Salima', market: 'Chipoka Market', price: 1200 },
  { cropName: 'Cassava-dried', district: 'Mangochi', market: 'Monkey Bay Market', price: 1200 },
  { cropName: 'Cassava-dried', district: 'Chikwawa', market: 'Ngabu Market', price: 1200 },
  { cropName: 'Cassava-wet', district: 'Nkhata Bay', market: 'Chintheche Market', price: 900 },
  { cropName: 'Cassava-wet', district: 'Nkhotakota', market: 'Benga Market', price: 900 },
  { cropName: 'Cassava-wet', district: 'Karonga', market: 'Wovwe Market', price: 900 },
  { cropName: 'Cassava-wet', district: 'Salima', market: 'Salima Boma Market', price: 900 },
  { cropName: 'Cassava-wet', district: 'Mangochi', market: 'Mangochi Market', price: 900 },
  { cropName: 'Cassava-wet', district: 'Zomba', market: 'Mbulumbuzi Market', price: 900 },
  { cropName: 'Irish potatoes', district: 'Dedza', market: 'Bembeke Market', price: 1200 },
  { cropName: 'Irish potatoes', district: 'Dedza', market: 'Golomoti Market', price: 1200 },
  { cropName: 'Irish potatoes', district: 'Dedza', market: 'Mayani Market', price: 1200 },
  { cropName: 'Irish potatoes', district: 'Ntcheu', market: 'Tsangano Market', price: 1200 },
  { cropName: 'Irish potatoes', district: 'Ntchisi', market: 'Ntchisi Boma Market', price: 1200 },
  { cropName: 'Irish potatoes', district: 'Mulanje', market: 'Luchenza Market', price: 1200 },
  { cropName: 'Sweet potatoes', district: 'Mchinji', market: 'Mchemani Market', price: 800 },
  { cropName: 'Sweet potatoes', district: 'Lilongwe', market: 'Mitundu Market', price: 800 },
  { cropName: 'Sweet potatoes', district: 'Lilongwe', market: 'Kasiya Market', price: 800 },
  { cropName: 'Sweet potatoes', district: 'Kasungu', market: 'Santhe Market', price: 800 },
  { cropName: 'Sweet potatoes', district: 'Mangochi', market: 'Mangochi Market', price: 800 },
  { cropName: 'Sweet potatoes', district: 'Zomba', market: 'Zomba Central Market', price: 800 },
  { cropName: 'Bananas', district: 'Mulanje', market: 'Luchenza Market', price: 700 },
  { cropName: 'Bananas', district: 'Thyolo', market: 'Limbe Market', price: 700 },
  { cropName: 'Bananas', district: 'Phalombe', market: 'Migowi Market', price: 700 },
  { cropName: 'Bananas', district: 'Mzimba', market: 'Mzuzu Market', price: 700 },
  { cropName: 'Bananas', district: 'Nkhata Bay', market: 'Chintheche Market', price: 700 },
  { cropName: 'Bananas', district: 'Zomba', market: 'Zomba Central Market', price: 700 },
  { cropName: 'Tomatoes', district: 'Lilongwe', market: 'Mitundu Market', price: 2500 },
  { cropName: 'Tomatoes', district: 'Blantyre', market: 'Limbe Market', price: 2500 },
  { cropName: 'Tomatoes', district: 'Zomba', market: 'Zomba Central Market', price: 2500 },
  { cropName: 'Tomatoes', district: 'Mzuzu', market: 'Mzuzu Market', price: 2500 },
  { cropName: 'Tomatoes', district: 'Dedza', market: 'Bembeke Market', price: 2500 },
  { cropName: 'Tomatoes', district: 'Mangochi', market: 'Mangochi Market', price: 2500 },
  { cropName: 'Onions', district: 'Dedza', market: 'Bembeke Market', price: 3000 },
  { cropName: 'Onions', district: 'Ntcheu', market: 'Tsangano Market', price: 3000 },
  { cropName: 'Onions', district: 'Lilongwe', market: 'Kasiya Market', price: 3000 },
  { cropName: 'Onions', district: 'Kasungu', market: 'Santhe Market', price: 3000 },
  { cropName: 'Onions', district: 'Mchinji', market: 'Mchemani Market', price: 3000 },
  { cropName: 'Onions', district: 'Blantyre', market: 'Limbe Market', price: 3000 },
  { cropName: 'Garlic', district: 'Dedza', market: 'Mayani Market', price: 5000 },
  { cropName: 'Garlic', district: 'Ntcheu', market: 'Tsangano Market', price: 5000 },
  { cropName: 'Garlic', district: 'Lilongwe', market: 'Mitundu Market', price: 5000 },
  { cropName: 'Garlic', district: 'Mzimba', market: 'Mzuzu Market', price: 5000 },
  { cropName: 'Garlic', district: 'Blantyre', market: 'Limbe Market', price: 5000 },
  { cropName: 'Garlic', district: 'Zomba', market: 'Zomba Central Market', price: 5000 },
  { cropName: 'Cabbage', district: 'Dedza', market: 'Bembeke Market', price: 1000 },
  { cropName: 'Cabbage', district: 'Ntcheu', market: 'Tsangano Market', price: 1000 },
  { cropName: 'Cabbage', district: 'Lilongwe', market: 'Mitundu Market', price: 1000 },
  { cropName: 'Cabbage', district: 'Kasungu', market: 'Santhe Market', price: 1000 },
  { cropName: 'Cabbage', district: 'Blantyre', market: 'Limbe Market', price: 1000 },
  { cropName: 'Cabbage', district: 'Mzuzu', market: 'Mzuzu Market', price: 1000 },
];

const productNames = [...new Set(entries.map((item) => item.cropName))];

async function ensureProducts() {
  for (const name of productNames) {
    const query = await db.collection('products').where('name', '==', name).limit(1).get();
    if (query.empty) {
      await db.collection('products').add({
        name,
        createdAt,
      });
      console.log('[Seed] Created product:', name);
    } else {
      console.log('[Seed] Product already exists:', name);
    }
  }
}

async function ensureCooperativeOfficer() {
  await db.collection('users').doc(coopOfficerUid).set(coopOfficer, { merge: true });
  console.log('[Seed] Created/updated cooperative officer user:', coopOfficerUid);
}

async function seedPrices() {
  const batch = db.batch();

  for (const entry of entries) {
    const docRef = db.collection('prices').doc();
    batch.set(docRef, {
      cropName: entry.cropName,
      market: entry.market,
      district: entry.district,
      price: entry.price,
      unit: 'kg',
      status: 'approved',
      uploadedBy: coopOfficerUid,
      notes: 'Seeded from backend for 16 May 2026 data upload.',
      updatedAt: publishedAt,
      createdAt: createdAt,
      source: 'backend-seed',
    });
  }

  await batch.commit();
  console.log('[Seed] Created', entries.length, 'price documents');
}

async function runSeed() {
  console.log('[Seed] Starting May 16 2026 price seed');
  await ensureProducts();
  await ensureCooperativeOfficer();
  await seedPrices();
  console.log('[Seed] Completed successfully');
}

if (require.main === module) {
  runSeed().catch((err) => {
    console.error('[Seed] Error:', err);
    process.exit(1);
  });
}

module.exports = { runSeed };
