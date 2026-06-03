const { db } = require('../config/firebase');

const CURRENCY = 'MWK';
const DEFAULT_UNIT = 'kg';
const RANGE_PERCENT = 0.30;
const MAX_MENU_ITEMS = 30;
const PAGE_SIZE = 4;
const CACHE_TTL_MS = 2 * 60 * 1000;
const cacheStore = new Map();

const toText = (value, fallback = '') => (
  value === undefined || value === null || typeof value === 'object'
    ? fallback
    : String(value).trim()
);

const firstText = (...values) => {
  for (const value of values) {
    const text = toText(value);
    if (text) return text;
  }
  return '';
};

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

const cached = async (key, loader) => {
  const now = Date.now();
  const cachedValue = cacheStore.get(key);

  if (cachedValue && cachedValue.expiresAt > now) {
    return cachedValue.value;
  }

  const value = await loader();
  cacheStore.set(key, {
    value,
    expiresAt: now + CACHE_TTL_MS,
  });

  return value;
};

const mainMenu = () => (
  'CON Welcome to SAPPT\n' +
  '1. View Prices\n' +
  '2. Exit'
);

const uniqueByKey = (items, keySelector) => {
  const map = new Map();
  for (const item of items) {
    const key = keySelector(item);
    if (key && !map.has(key)) map.set(key, item);
  }
  return [...map.values()];
};

const productAliases = (name) => {
  const normalized = normalize(name);
  const aliases = new Set([normalized]);

  if (normalized.includes('-')) aliases.add(normalized.split('-')[0]);
  if (normalized.includes(' ')) aliases.add(normalized.split(' ')[0]);
  if (normalized === 'maize') aliases.add('corn');
  if (normalized === 'corn') aliases.add('maize');
  if (normalized.includes('rice')) aliases.add('rice');
  if (normalized.includes('bean') || normalized.includes('cowpea')) {
    aliases.add('beans');
    aliases.add('bean');
    aliases.add('cowpeas');
    aliases.add('cow peas');
  }
  if (normalized.includes('groundnut') || normalized.includes('peanut')) {
    aliases.add('groundnuts');
    aliases.add('groundnut');
    aliases.add('peanuts');
    aliases.add('peanut');
  }

  return [...aliases];
};

const fetchApprovedPrices = async (limit = 500) => cached(`approved-prices:${limit}`, async () => {
  const snapshot = await db
    .collection('prices')
    .where('status', '==', 'approved')
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => doc.data()).filter(isVisiblePrice);
});

const fetchProducts = async () => cached('ussd-products', async () => {
  const readProductCollection = async (collectionName) => {
    try {
      const snapshot = await db.collection(collectionName).limit(50).get();
      return snapshot.docs
        .map((doc) => doc.data())
        .map((item) => firstText(item.name, item.cropName, item.productName))
        .filter(Boolean);
    } catch (error) {
      console.error(`USSD fetch ${collectionName} failed:`, error.message);
      return [];
    }
  };

  const fromProducts = await readProductCollection('products');
  const fromCommodities = fromProducts.length > 0
    ? []
    : await readProductCollection('commodities');

  const catalogNames = [...fromProducts, ...fromCommodities];
  const fallbackPrices = catalogNames.length > 0 ? [] : await fetchApprovedPrices();
  const fallbackNames = fallbackPrices
    .map((price) => toText(price.cropName || price.productName || price.name))
    .filter(Boolean);

  return uniqueByKey([...catalogNames, ...fallbackNames]
    .map((name) => ({
      label: name,
      aliases: productAliases(name),
    }))
    .sort((a, b) => a.label.localeCompare(b.label)), (product) => normalize(product.label))
    .slice(0, MAX_MENU_ITEMS);
});

const fetchLocations = async () => cached('ussd-locations', async () => {
  let locations = [];

  try {
    const snapshot = await db.collection('markets').limit(80).get();
    locations = snapshot.docs
      .map((doc) => doc.data())
      .filter((market) => market.isActive !== false)
      .map((market) => firstText(
        market.district,
        market.region,
        market.location,
        market.name,
        market.marketName,
      ))
      .filter(Boolean);
  } catch (error) {
    console.error('USSD fetch markets failed:', error.message);
  }

  if (locations.length === 0) {
    const prices = await fetchApprovedPrices();
    locations = prices
      .map((price) => firstText(price.district, price.region, price.location))
      .filter(Boolean);
  }

  return uniqueByKey(
    locations.sort((a, b) => a.localeCompare(b)),
    (location) => normalize(location),
  ).slice(0, MAX_MENU_ITEMS);
});

const shorten = (value, max = 24) => {
  const text = toText(value);
  return text.length > max ? `${text.slice(0, max - 3)}...` : text;
};

const pagedMenu = (title, items, page, formatter = (item) => item) => {
  const start = page * PAGE_SIZE;
  const pageItems = items.slice(start, start + PAGE_SIZE);
  const hasNext = start + PAGE_SIZE < items.length;
  const lines = pageItems.map((item, index) => (
    `${index + 1}. ${shorten(formatter(item))}`
  ));

  if (hasNext) lines.push(`${pageItems.length + 1}. More`);
  lines.push(`${pageItems.length + (hasNext ? 2 : 1)}. Back`);

  return `CON ${title}\n${lines.join('\n')}`;
};

const resolvePagedSelection = (title, items, tokens, formatter = (item) => item) => {
  let page = 0;
  let tokenIndex = 0;

  while (true) {
    const start = page * PAGE_SIZE;
    const pageItems = items.slice(start, start + PAGE_SIZE);
    const hasNext = start + PAGE_SIZE < items.length;
    const backOption = pageItems.length + (hasNext ? 2 : 1);
    const moreOption = hasNext ? pageItems.length + 1 : null;
    const token = tokens[tokenIndex];

    if (!token) {
      return { type: 'menu', menu: pagedMenu(title, items, page, formatter) };
    }

    const choice = parseInt(token, 10);
    if (Number.isNaN(choice)) return { type: 'invalid' };

    if (hasNext && choice === moreOption) {
      page += 1;
      tokenIndex += 1;
      continue;
    }

    if (choice === backOption) {
      return { type: 'back' };
    }

    if (choice >= 1 && choice <= pageItems.length) {
      return {
        type: 'selected',
        item: pageItems[choice - 1],
        nextIndex: tokenIndex + 1,
      };
    }

    return { type: 'invalid' };
  }
};

const productMenu = (products, page = 0) => pagedMenu(
  'Select Product Category',
  products,
  page,
  (product) => product.label,
);

const locationMenu = (locations, page = 0) => pagedMenu('Select Market', locations, page);

const resolveProductSelection = (products, tokens) => {
  return resolvePagedSelection(
    'Select Product Category',
    products,
    tokens,
    (product) => product.label,
  );
};

const resolveLocationSelection = (locations, tokens) => {
  return resolvePagedSelection('Select Market', locations, tokens);
};

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
  const thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000);
  const matchingPrices = (await fetchApprovedPrices())
    .filter((data) => productMatches(firstText(data.cropName, data.productName, data.name), product))
    .filter((data) => districtMatches(firstText(data.district, data.region, data.location), market))
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

const handleUSSD = async (req, res) => {
  const { sessionId = 'unknown', phoneNumber = 'unknown', text = '' } = req.body || {};
  console.log(`USSD | Session: ${sessionId} | Phone: ${phoneNumber} | Input: "${text}"`);

  const inputs = text.split('*').filter((item) => item !== '');
  const [menuChoice] = inputs;

  if (inputs.length === 0) {
    return res.type('text/plain').send(mainMenu());
  }

  if (menuChoice === '2') {
    return res.type('text/plain').send(exitMessage());
  }

  if (menuChoice !== '1') {
    return res.type('text/plain').send('END Invalid input. Please dial again.');
  }

  const products = await fetchProducts();
  if (products.length === 0) {
    return res.type('text/plain').send('END No products available yet.');
  }

  const productResult = resolveProductSelection(products, inputs.slice(1));
  if (productResult.type === 'menu') {
    return res.type('text/plain').send(productResult.menu);
  }
  if (productResult.type === 'back') {
    return res.type('text/plain').send(mainMenu());
  }
  if (productResult.type !== 'selected') {
    return res.type('text/plain').send('END Invalid product. Please dial again.');
  }

  const product = productResult.item;

  const locations = await fetchLocations();
  if (locations.length === 0) {
    return res.type('text/plain').send('END No markets available yet.');
  }

  const locationResult = resolveLocationSelection(
    locations,
    inputs.slice(1 + productResult.nextIndex),
  );
  if (locationResult.type === 'menu') {
    return res.type('text/plain').send(locationResult.menu);
  }
  if (locationResult.type === 'back') {
    return res.type('text/plain').send(productMenu(products));
  }
  if (locationResult.type !== 'selected') {
    return res.type('text/plain').send('END Invalid market. Please dial again.');
  }

  const market = locationResult.item;
  const resultChoice = inputs[1 + productResult.nextIndex + locationResult.nextIndex];

  if (!resultChoice) {
    return res.type('text/plain').send(await priceResultMenu(product, market));
  }

  if (resultChoice === '1') {
    return res.type('text/plain').send(locationMenu(locations));
  }

  if (resultChoice === '2') {
    return res.type('text/plain').send(exitMessage());
  }

  return res.type('text/plain').send('END Invalid input. Please dial again.');
};

module.exports = { handleUSSD };
