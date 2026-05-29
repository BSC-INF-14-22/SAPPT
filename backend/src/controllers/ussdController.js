const { db } = require('../config/firebase');

const DEFAULT_PRODUCTS = ['Maize', 'Soybean', 'Groundnuts', 'Wheat', 'Rice'];
const DEFAULT_UNIT = 'kg';
const CURRENCY = 'MK';

const toText = (value, fallback = '') => (
  value === undefined || value === null ? fallback : String(value).trim()
);

const toNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const toMillis = (value) => {
  if (!value) return 0;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? 0 : parsed;
};

const slugify = (value) => toText(value, 'unknown')
  .toLowerCase()
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/^-|-$/g, '') || 'unknown';

const normalizePrice = (doc) => {
  const data = typeof doc.data === 'function' ? doc.data() : doc;
  const productName = toText(data.productName || data.cropName || data.name, 'Unknown');
  const marketName = toText(data.marketName || data.market || data.marketId, 'Unknown market');
  const district = toText(data.district || data.region || data.location);
  const unit = toText(data.unit || data.measurementUnit || data.measurement, DEFAULT_UNIT);
  const updatedAt = data.submittedAt || data.updatedAt || data.createdAt || data.publishedAt;

  return {
    id: doc.id,
    ...data,
    productName,
    cropName: productName,
    price: toNumber(data.price),
    unit,
    marketId: toText(data.marketId) || slugify(`${marketName}-${district}`),
    marketName,
    market: marketName,
    district,
    updatedAt,
    sortTime: toMillis(updatedAt),
  };
};

const isVisiblePrice = (price) => {
  const status = toText(price.status).toLowerCase();
  return price.price !== null && (!status || status === 'approved' || status === 'verified');
};

const getRecentPrices = async (limit = 100) => {
  const snapshot = await db.collection('prices').limit(limit).get();
  return snapshot.docs
    .map(normalizePrice)
    .filter(isVisiblePrice)
    .sort((a, b) => b.sortTime - a.sortTime);
};

const fetchProducts = async () => {
  const readCollection = async (collectionName) => {
    try {
      const snapshot = await db.collection(collectionName).limit(20).get();
      return snapshot.docs
        .map((doc) => ({ id: doc.id, ...doc.data() }))
        .map((item) => ({
          name: toText(item.name || item.cropName || item.productName),
          unit: toText(item.unit || item.measurementUnit || item.measurement, DEFAULT_UNIT),
        }))
        .filter((item) => item.name);
    } catch (err) {
      console.error(`Firestore fetch ${collectionName} error:`, err.message);
      return [];
    }
  };

  const products = await readCollection('products');
  if (products.length > 0) return products;

  const commodities = await readCollection('commodities');
  if (commodities.length > 0) return commodities;

  return DEFAULT_PRODUCTS.map((name) => ({ name, unit: DEFAULT_UNIT }));
};

const fetchLatestPriceForProduct = async (productName) => {
  const prices = await getRecentPrices(150);
  return prices.find(
    (price) => price.productName.toLowerCase() === productName.toLowerCase()
  ) || null;
};

const fetchLatestPrices = async () => {
  const prices = await getRecentPrices(100);
  return prices.slice(0, 5);
};

const fetchMarkets = async () => {
  try {
    const snapshot = await db.collection('markets').limit(20).get();
    const markets = snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((market) => market.isActive !== false)
      .map((market) => ({
        id: market.id,
        name: toText(market.name || market.market || market.marketName, 'Unknown market'),
        district: toText(market.district || market.region || market.location),
      }))
      .filter((market) => market.name !== 'Unknown market')
      .sort((a, b) => a.name.localeCompare(b.name));

    if (markets.length > 0) return markets.slice(0, 5);
  } catch (err) {
    console.error('Firestore fetchMarkets error:', err.message);
  }

  const prices = await getRecentPrices(150);
  const byMarket = new Map();

  for (const price of prices) {
    const key = price.marketId || slugify(`${price.marketName}-${price.district}`);
    if (!byMarket.has(key)) {
      byMarket.set(key, {
        id: key,
        name: price.marketName,
        district: price.district,
      });
    }
  }

  return [...byMarket.values()]
    .sort((a, b) => a.name.localeCompare(b.name))
    .slice(0, 5);
};

const fetchPricesForMarket = async (market) => {
  const prices = await getRecentPrices(150);
  return prices
    .filter((price) => (
      price.marketId === market.id
      || price.marketName.toLowerCase() === market.name.toLowerCase()
      || slugify(`${price.marketName}-${price.district}`) === market.id
    ))
    .slice(0, 3);
};

const fetchCooperativePrices = async (productName) => {
  const prices = await getRecentPrices(150);
  return prices
    .filter((price) => price.productName.toLowerCase() === productName.toLowerCase())
    .filter((price) => price.sourceType === 'manual' || price.uploadedBy || price.source === 'backend-seed')
    .map((price) => price.price)
    .filter((price) => price !== null);
};

const mainMenu = () => (
  'CON Welcome to SAPPT Market Prices\n' +
  'Select an option:\n' +
  '1. View Prices\n' +
  '2. Select Commodity\n' +
  '3. Select Market\n' +
  '4. Exit\n' +
  '5. Estimate Selling Price'
);

const formatPriceLine = (price) => (
  `${price.productName}: ${CURRENCY}${price.price}/${price.unit}`
);

const formatMarketName = (market) => (
  market.district ? `${market.name}, ${market.district}` : market.name
);

const handleUSSD = async (req, res) => {
  const { sessionId = 'unknown', phoneNumber = 'unknown', text = '' } = req.body;

  console.log(`USSD | Session: ${sessionId} | Phone: ${phoneNumber} | Input: "${text}"`);

  const userInputs = text.split('*');
  const level1 = userInputs[0];
  const level2 = userInputs[1];

  if (text === '') {
    return res.type('text/plain').send(mainMenu());
  }

  if (level1 === '1') {
    const prices = await fetchLatestPrices();

    if (prices.length === 0) {
      return res.type('text/plain').send('END No approved price data available.\nPlease check back later.');
    }

    return res.type('text/plain').send(
      'END Latest Prices:\n' +
      prices.map(formatPriceLine).join('\n') +
      '\nSource: SAPPT'
    );
  }

  if (level1 === '2' && !level2) {
    const products = await fetchProducts();
    req.app.locals[`products:${sessionId}`] = products;

    return res.type('text/plain').send(
      'CON Select a commodity:\n' +
      products.map((item, index) => `${index + 1}. ${item.name}`).join('\n') +
      '\n0. Back'
    );
  }

  if (level1 === '2' && level2) {
    if (level2 === '0') return res.type('text/plain').send(mainMenu());

    const products = req.app.locals[`products:${sessionId}`] || await fetchProducts();
    const productIndex = parseInt(level2, 10) - 1;

    if (Number.isNaN(productIndex) || productIndex < 0 || productIndex >= products.length) {
      return res.type('text/plain').send('END Invalid selection. Please dial again.');
    }

    const selectedProduct = products[productIndex];
    const priceData = await fetchLatestPriceForProduct(selectedProduct.name);

    if (!priceData) {
      return res.type('text/plain').send(
        `END No price data found for ${selectedProduct.name}.\nPlease check back later.`
      );
    }

    delete req.app.locals[`products:${sessionId}`];

    return res.type('text/plain').send(
      `END ${selectedProduct.name} Price:\n` +
      `${CURRENCY} ${priceData.price} per ${priceData.unit || selectedProduct.unit}\n` +
      `Market: ${priceData.marketName}\n` +
      'Source: SAPPT'
    );
  }

  if (level1 === '3' && !level2) {
    const markets = await fetchMarkets();

    if (markets.length === 0) {
      return res.type('text/plain').send('END No markets available at this time.');
    }

    req.app.locals[`markets:${sessionId}`] = markets;

    return res.type('text/plain').send(
      'CON Select a market:\n' +
      markets.map((market, index) => `${index + 1}. ${formatMarketName(market)}`).join('\n') +
      '\n0. Back'
    );
  }

  if (level1 === '3' && level2) {
    if (level2 === '0') return res.type('text/plain').send(mainMenu());

    const markets = req.app.locals[`markets:${sessionId}`] || await fetchMarkets();
    const marketIndex = parseInt(level2, 10) - 1;

    if (Number.isNaN(marketIndex) || marketIndex < 0 || marketIndex >= markets.length) {
      return res.type('text/plain').send('END Invalid market selection. Please dial again.');
    }

    const selectedMarket = markets[marketIndex];
    const prices = await fetchPricesForMarket(selectedMarket);

    if (prices.length === 0) {
      return res.type('text/plain').send(
        `END No prices found for\n${selectedMarket.name}.\nPlease check back later.`
      );
    }

    delete req.app.locals[`markets:${sessionId}`];

    return res.type('text/plain').send(
      `END Prices at ${formatMarketName(selectedMarket)}:\n` +
      prices.map(formatPriceLine).join('\n') +
      '\nSource: SAPPT'
    );
  }

  if (level1 === '4') {
    return res.type('text/plain').send(
      'END Thank you for using SAPPT!\nHelping farmers get fair prices.'
    );
  }

  if (level1 === '5' && !level2) {
    const products = await fetchProducts();
    req.app.locals[`products:${sessionId}`] = products;

    return res.type('text/plain').send(
      'CON Estimate selling price - select commodity:\n' +
      products.map((item, index) => `${index + 1}. ${item.name}`).join('\n') +
      '\n0. Back'
    );
  }

  if (level1 === '5' && level2) {
    if (level2 === '0') return res.type('text/plain').send(mainMenu());

    const products = req.app.locals[`products:${sessionId}`] || await fetchProducts();
    const productIndex = parseInt(level2, 10) - 1;

    if (Number.isNaN(productIndex) || productIndex < 0 || productIndex >= products.length) {
      return res.type('text/plain').send('END Invalid selection. Please dial again.');
    }

    const selectedProduct = products[productIndex];
    const coopPrices = await fetchCooperativePrices(selectedProduct.name);

    if (coopPrices.length === 0) {
      return res.type('text/plain').send(
        `END No cooperative price reports found for ${selectedProduct.name}.\nPlease check back later.`
      );
    }

    coopPrices.sort((a, b) => a - b);
    const min = coopPrices[0];
    const max = coopPrices[coopPrices.length - 1];
    const mean = coopPrices.reduce((sum, value) => sum + value, 0) / coopPrices.length;
    const suggested = (mean * 1.05).toFixed(2);

    delete req.app.locals[`products:${sessionId}`];

    return res.type('text/plain').send(
      `END Estimate for ${selectedProduct.name}:\n` +
      `Suggested: ${CURRENCY} ${suggested}/${selectedProduct.unit || DEFAULT_UNIT}\n` +
      `Range: ${min}-${max}\n` +
      'Source: SAPPT'
    );
  }

  return res.type('text/plain').send('END Invalid input. Please dial again.');
};

module.exports = { handleUSSD };
