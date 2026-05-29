require('dotenv').config();
const { db } = require('../src/config/firebase');

const main = async () => {
  const pricesSnapshot = await db.collection('prices').get();
  const userCache = new Map();
  const batch = db.batch();
  let updated = 0;
  let skipped = 0;

  for (const doc of pricesSnapshot.docs) {
    const price = doc.data();
    if (price.cooperativeName || price.uploadedByName || !price.uploadedBy) {
      skipped += 1;
      continue;
    }

    let userData = userCache.get(price.uploadedBy);
    if (!userData) {
      const userDoc = await db.collection('users').doc(price.uploadedBy).get();
      userData = userDoc.data();
      userCache.set(price.uploadedBy, userData);
    }

    const cooperativeName = String(
      userData?.fullName || userData?.displayName || 'Cooperative Officer',
    ).trim();

    batch.update(doc.ref, {
      cooperativeName,
      uploadedByName: cooperativeName,
      cooperativeEmail: userData?.email || null,
    });
    updated += 1;
  }

  if (updated > 0) {
    await batch.commit();
  }

  console.log(`Price cooperative names backfill complete. Updated=${updated}, skipped=${skipped}`);
};

main().catch((error) => {
  console.error('Price cooperative names backfill failed:', error);
  process.exit(1);
});
