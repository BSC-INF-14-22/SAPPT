require('dotenv').config();
const { db } = require('../src/config/firebase');

const phoneComparisonKeys = (phone) => {
  const digitsOnly = String(phone || '').replace(/\D/g, '');
  const keys = new Set();

  if (!digitsOnly) return keys;

  keys.add(digitsOnly);

  if (digitsOnly.startsWith('00') && digitsOnly.length > 2) {
    keys.add(digitsOnly.slice(2));
  }

  if (digitsOnly.startsWith('265') && digitsOnly.length > 3) {
    const local = digitsOnly.slice(3);
    keys.add(local);
    keys.add(`0${local}`);
    keys.add(`265${local}`);
  } else if (digitsOnly.startsWith('0') && digitsOnly.length > 1) {
    const local = digitsOnly.slice(1);
    keys.add(local);
    keys.add(`0${local}`);
    keys.add(`265${local}`);
  } else if (digitsOnly.length === 9) {
    keys.add(`0${digitsOnly}`);
    keys.add(`265${digitsOnly}`);
  }

  return keys;
};

const normalizePhoneForStorage = (phone) => {
  const [first] = phoneComparisonKeys(phone);
  return first || String(phone || '').trim();
};

const main = async () => {
  const usersSnapshot = await db.collection('users').get();
  const batch = db.batch();
  let indexed = 0;
  let skipped = 0;

  usersSnapshot.forEach((doc) => {
    const data = doc.data();
    const phone = data.phone || data.phoneNumber || data.mobile;
    const email = data.email;

    if (!phone || !email) {
      skipped += 1;
      return;
    }

    const normalizedPhone = normalizePhoneForStorage(phone);
    if (!normalizedPhone) {
      skipped += 1;
      return;
    }

    const ref = db.collection('phone_login').doc(normalizedPhone);
    batch.set(
      ref,
      {
        email,
        uid: data.uid || doc.id,
        phone,
        normalizedPhone,
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
    indexed += 1;
  });

  if (indexed > 0) {
    await batch.commit();
  }

  console.log(`Phone login index backfill complete. Indexed=${indexed}, skipped=${skipped}`);
};

main().catch((error) => {
  console.error('Phone login index backfill failed:', error);
  process.exit(1);
});
