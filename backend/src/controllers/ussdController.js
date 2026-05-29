const { db } = require('../config/firebase');

const CURRENCY = 'MWK';
const DEFAULT_UNIT = 'kg';
const RANGE_PERCENT = 0.30;

const PRODUCTS = [
  { label: 'Maize', aliases: ['maize', 'corn'] },
  { label: 'Rice', aliases: ['rice', 'rice-polished', 'rice-unpolished'] },
  { label: 'Beans', aliases: ['beans', 'bean', 'cowpeas', 'cow peas'] },
  { label: 'Groundnuts', aliases: ['groundnuts', 'groundnut', 'peanuts', 'peanut'] },
];

const MARKETS = ['Zomba', 'Lilongwe', 'Blantyre', 'Mzuzu'];

const toText = (value, fallback = '') => (
  value === undefined || value === null ? fallback : String(value).trim()
);

const toNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const normalize = (value) => toText(value)
  .toLowerCase()
  .replace(/[_/]+/g, '-')
  .replace(/\s*-\s*/g, '-')
  .replace(/\s+/g, ' ');

const toMillis = (value) => {
  if (!value) return 0;
  if (typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? 0 : parsed;
};

const roundToNearest10 = (value) => Math.round(value / 10) * 10;

const mainMenu = () => (
  'CON Welcome to SAPPT\n' +
  '1. View Prices\n' +
  '2. Exit'
);

const productMenu = () => (
  'CON Select Product Category\n' +
  PRODUCTS.map((product, index) => `${index + 1}. ${product.label}`).join('\n') +
  '\n5. Back'
);

const marketMenu = () => (
  'CON Select Market\n' +
  MARKETS.map((market, index) => `${index + 1}. ${market}`).join('\n') +
  '\n5. Back'
);

const exitMessage = () => 'END Thank you for using SAPPT.';

const isVisiblePrice = (data) => {
  const price = toNumber(data.price);
  const status = normalize(data.status);
  return price !== null && price > 0 && (!status || status === 'approved' || status === 'verified');
};

const productMatches = (priceProductName, product) => {
  const normalizedPriceProduct = normalize(priceProductName);
  return product.aliases.some((alias) => {
    const normalizedAlias = normalize(alias);
    return normalizedPriceProduct === normalizedAlias
      || normalizedPriceProduct.startsWith(`${normalizedAlias}-`)
      || normalizedPriceProduct.startsWith(`${normalizedAlias} `);
  });
};

const districtMatches = (priceDistrict, market) => (
  normalize(priceDistrict) === normalize(market)
);

const fetchAverageSellingPrice = async (product, market) => {
  const snapshot = await db
    .collection('prices')
    .where('status', '==', 'approved')
    .limit(500)
    .get();

  const thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000);
  const matchingPrices = snapshot.docs
    .map((doc) => doc.data())
    .filter(isVisiblePrice)
    .filter((data) => productMatches(data.cropName || data.productName || data.name, product))
    .filter((data) => districtMatches(data.district || data.region || data.location, market))
    .map((data) => ({
      price: toNumber(data.price),
      unit: toText(data.unit || data.measurementUnit || data.measurement, DEFAULT_UNIT),
      sortTime: toMillis(data.submittedAt || data.updatedAt || data.createdAt),
    }))
    .filter((item) => item.price !== null);

  const recentPrices = matchingPrices.filter((item) => item.sortTime >= thirtyDaysAgo);
  const prices = recentPrices.length > 0 ? recentPrices : matchingPrices;

  if (prices.length === 0) return null;

  const average = prices.reduce((sum, item) => sum + item.price, 0) / prices.length;
  const unit = prices[0].unit || DEFAULT_UNIT;
  const halfRange = RANGE_PERCENT / 2;

  return {
    unit,
    average,
    min: roundToNearest10(average * (1 - halfRange)),
    max: roundToNearest10(average * (1 + halfRange)),
  };
};

const priceResultMenu = async (product, market) => {
  const range = await fetchAverageSellingPrice(product, market);

  if (!range) {
    return (
      `CON ${product.label} prices in ${market}:\n` +
      'No approved prices found.\n' +
      '1. Back\n' +
      '2. Exit'
    );
  }

  return (
    `CON ${product.label} prices in ${market}:\n` +
    `${CURRENCY} ${range.min} to ${range.max} per ${range.unit}\n` +
    '1. Back\n' +
    '2. Exit'
  );
};

const parseSelection = (value, max) => {
  const index = parseInt(value, 10) - 1;
  if (Number.isNaN(index) || index < 0 || index >= max) return null;
  return index;
};

const handleUSSD = async (req, res) => {
  const { sessionId = 'unknown', phoneNumber = 'unknown', text = '' } = req.body;
  console.log(`USSD | Session: ${sessionId} | Phone: ${phoneNumber} | Input: "${text}"`);

  const inputs = text.split('*').filter((item) => item !== '');
  const [menuChoice, productChoice, marketChoice, resultChoice] = inputs;

  if (inputs.length === 0) {
    return res.type('text/plain').send(mainMenu());
  }

  if (menuChoice === '2') {
    return res.type('text/plain').send(exitMessage());
  }

  if (menuChoice !== '1') {
    return res.type('text/plain').send('END Invalid input. Please dial again.');
  }

  if (!productChoice) {
    return res.type('text/plain').send(productMenu());
  }

  if (productChoice === '5') {
    return res.type('text/plain').send(mainMenu());
  }

  const productIndex = parseSelection(productChoice, PRODUCTS.length);
  if (productIndex === null) {
    return res.type('text/plain').send('END Invalid product. Please dial again.');
  }

  const product = PRODUCTS[productIndex];

  if (!marketChoice) {
    return res.type('text/plain').send(marketMenu());
  }

  if (marketChoice === '5') {
    return res.type('text/plain').send(productMenu());
  }

  const marketIndex = parseSelection(marketChoice, MARKETS.length);
  if (marketIndex === null) {
    return res.type('text/plain').send('END Invalid market. Please dial again.');
  }

  const market = MARKETS[marketIndex];

  if (!resultChoice) {
    return res.type('text/plain').send(await priceResultMenu(product, market));
  }

  if (resultChoice === '1') {
    return res.type('text/plain').send(marketMenu());
  }

  if (resultChoice === '2') {
    return res.type('text/plain').send(exitMessage());
  }

  return res.type('text/plain').send('END Invalid input. Please dial again.');
};

module.exports = { handleUSSD };
