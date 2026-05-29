const { db, admin } = require('../config/firebase');

const toText = (value, fallback = '') => (
  value === undefined || value === null ? fallback : String(value).trim()
);

const toNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const slugify = (value) => toText(value, 'unknown')
  .toLowerCase()
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/^-|-$/g, '') || 'unknown';

const normalizePriceFields = (data) => {
  const productName = toText(data.productName || data.cropName || data.name);
  const unit = toText(data.unit || data.measurementUnit || data.measurement, 'kg');
  const marketName = toText(data.marketName || data.market || data.marketId);
  const district = toText(data.district || data.region || data.location);
  const marketId = toText(data.marketId) || slugify(`${marketName}-${district}`);
  const price = toNumber(data.price);
  const submittedAt = data.submittedAt || data.updatedAt || data.createdAt || admin.firestore.FieldValue.serverTimestamp();

  return {
    productName,
    cropName: productName,
    unit,
    marketName,
    market: marketName,
    district,
    marketId,
    price,
    submittedAt,
  };
};

const syncCatalogFromPrices = async (req, res, next) => {
  try {
    const pricesSnapshot = await db.collection('prices').limit(500).get();

    if (pricesSnapshot.empty) {
      return res.status(200).json({
        success: true,
        message: 'No price documents found to sync.',
        counts: {
          scannedPrices: 0,
          updatedPrices: 0,
          markets: 0,
          products: 0,
          commodities: 0,
        },
      });
    }

    const markets = new Map();
    const products = new Map();
    let updatedPrices = 0;
    let batch = db.batch();
    let operations = 0;

    const commitIfNeeded = async (force = false) => {
      if (operations > 0 && (force || operations >= 400)) {
        await batch.commit();
        batch = db.batch();
        operations = 0;
      }
    };

    for (const doc of pricesSnapshot.docs) {
      const original = doc.data();
      const normalized = normalizePriceFields(original);

      if (!normalized.productName || !normalized.marketName || normalized.price === null) {
        continue;
      }

      const productId = slugify(normalized.productName);
      const marketId = normalized.marketId;

      products.set(productId, {
        name: normalized.productName,
        cropName: normalized.productName,
        unit: normalized.unit,
        measurementUnit: normalized.unit,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      markets.set(marketId, {
        name: normalized.marketName,
        marketName: normalized.marketName,
        district: normalized.district,
        region: normalized.district,
        location: normalized.district || normalized.marketName,
        isActive: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const patch = {};
      for (const [key, value] of Object.entries(normalized)) {
        if (
          value !== undefined
          && value !== null
          && value !== ''
          && (original[key] === undefined || original[key] === null || original[key] === '')
        ) {
          patch[key] = value;
        }
      }

      if (Object.keys(patch).length > 0) {
        patch.normalizedForUSSD = true;
        patch.normalizedAt = admin.firestore.FieldValue.serverTimestamp();
        batch.set(doc.ref, patch, { merge: true });
        operations += 1;
        updatedPrices += 1;
        await commitIfNeeded();
      }
    }

    for (const [id, market] of markets) {
      batch.set(db.collection('markets').doc(id), market, { merge: true });
      operations += 1;
      await commitIfNeeded();
    }

    for (const [id, product] of products) {
      batch.set(db.collection('products').doc(id), product, { merge: true });
      operations += 1;
      await commitIfNeeded();

      batch.set(db.collection('commodities').doc(id), product, { merge: true });
      operations += 1;
      await commitIfNeeded();
    }

    await commitIfNeeded(true);

    return res.status(200).json({
      success: true,
      message: 'Catalog synced from prices. USSD can now read markets and commodities.',
      counts: {
        scannedPrices: pricesSnapshot.size,
        updatedPrices,
        markets: markets.size,
        products: products.size,
        commodities: products.size,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { syncCatalogFromPrices };
