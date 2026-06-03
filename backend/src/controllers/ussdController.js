const { db } = require('../config/firebase');

const CURRENCY = 'MWK';
const DEFAULT_UNIT = 'kg';
const RANGE_PERCENT = 0.30;
const MAX_MENU_ITEMS = 30;
const PAGE_SIZE = 4;
const CACHE_TTL_MS = 2 * 60 * 1000;
const cacheStore = new Map();

const LANGUAGES = {
  1: 'en',
  2: 'ny',
};

const messages = {
  en: {
    languageTitle: 'Choose language',
    languageOptionOne: 'English',
    languageOptionTwo: 'Chichewa',
    welcome: 'Welcome to SAPPT',
    viewPrices: 'View Prices',
    exit: 'Exit',
    selectProduct: 'Select Product Category',
    selectMarket: 'Select Market',
    more: 'More',
    back: 'Back',
    thanks: 'Thank you for using SAPPT.',
    invalid: 'Invalid input. Please dial again.',
    invalidLanguage: 'Invalid language. Please dial again.',
    invalidProduct: 'Invalid product. Please dial again.',
    invalidMarket: 'Invalid market. Please dial again.',
    noProducts: 'No products available yet.',
    noMarkets: 'No markets available yet.',
    noPrices: 'No approved prices found.',
    pricesIn: (product, market) => `${product} prices in ${market}:`,
    priceRange: (min, max, unit) => `${CURRENCY} ${min} to ${max} per ${unit}`,
  },
  ny: {
    languageTitle: 'Sankhani chilankhulo',
    languageOptionOne: 'English',
    languageOptionTwo: 'Chichewa',
    welcome: 'Takulandirani ku SAPPT',
    viewPrices: 'Onani Mitengo',
    exit: 'Tulukani',
    selectProduct: 'Sankhani Mtundu wa Mbewu',
    selectMarket: 'Sankhani Msika',
    more: 'Zina',
    back: 'Bwererani',
    thanks: 'Zikomo pogwiritsa ntchito SAPPT.',
    invalid: 'Mwasankha molakwika. Yambaninso.',
    invalidLanguage: 'Chilankhulo cholakwika. Yambaninso.',
    invalidProduct: 'Mbewu yolakwika. Yambaninso.',
    invalidMarket: 'Msika wolakwika. Yambaninso.',
    noProducts: 'Palibe mbewu zomwe zilipo panopa.',
    noMarkets: 'Palibe misika yomwe ilipo panopa.',
    noPrices: 'Palibe mitengo yovomerezeka yomwe yapezeka.',
    pricesIn: (product, market) => `Mitengo ya ${product} ku ${market}:`,
    priceRange: (min, max, unit) => `${CURRENCY} ${min} mpaka ${max} pa ${unit}`,
  },
};

const tr = (language) => messages[language] || messages.en;

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

const languageMenu = () => {
  const label = tr('en');
  return (
    `CON ${label.languageTitle}\n` +
    `1. ${label.languageOptionOne}\n` +
    `2. ${label.languageOptionTwo}`
  );
};

const mainMenu = (language) => {
  const label = tr(language);
  return (
    `CON ${label.welcome}\n` +
    `1. ${label.viewPrices}\n` +
    `2. ${label.exit}`
  );
};

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

const fetchProducts = async () => cached('ussd-products-approved-only', async () => {
  const approvedPrices = await fetchApprovedPrices();
  const productNames = approvedPrices
    .map((price) => toText(price.cropName || price.productName || price.name))
    .filter(Boolean);

  return uniqueByKey(productNames
    .map((name) => ({
      label: name,
      aliases: productAliases(name),
    }))
    .sort((a, b) => a.label.localeCompare(b.label)), (product) => normalize(product.label))
    .slice(0, MAX_MENU_ITEMS);
});

const fetchLocations = async (product) => cached(`ussd-locations-approved-only:${normalize(product.label)}`, async () => {
  const locations = (await fetchApprovedPrices())
    .filter((price) => productMatches(firstText(price.cropName, price.productName, price.name), product))
    .map((price) => firstText(price.district, price.region, price.location))
    .filter(Boolean);

  return uniqueByKey(
    locations.sort((a, b) => a.localeCompare(b)),
    (location) => normalize(location),
  ).slice(0, MAX_MENU_ITEMS);
});

const shorten = (value, max = 24) => {
  const text = toText(value);
  return text.length > max ? `${text.slice(0, max - 3)}...` : text;
};

const pagedMenu = (title, items, page, language, formatter = (item) => item) => {
  const label = tr(language);
  const start = page * PAGE_SIZE;
  const pageItems = items.slice(start, start + PAGE_SIZE);
  const hasNext = start + PAGE_SIZE < items.length;
  const lines = pageItems.map((item, index) => (
    `${index + 1}. ${shorten(formatter(item))}`
  ));

  if (hasNext) lines.push(`${pageItems.length + 1}. ${label.more}`);
  lines.push(`${pageItems.length + (hasNext ? 2 : 1)}. ${label.back}`);

  return `CON ${title}\n${lines.join('\n')}`;
};

const resolvePagedSelection = (title, items, tokens, language, formatter = (item) => item) => {
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
      return { type: 'menu', menu: pagedMenu(title, items, page, language, formatter) };
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

const productMenu = (products, language, page = 0) => pagedMenu(
  tr(language).selectProduct,
  products,
  page,
  language,
  (product) => product.label,
);

const locationMenu = (locations, language, page = 0) => pagedMenu(
  tr(language).selectMarket,
  locations,
  page,
  language,
);

const resolveProductSelection = (products, tokens, language) => {
  return resolvePagedSelection(
    tr(language).selectProduct,
    products,
    tokens,
    language,
    (product) => product.label,
  );
};

const resolveLocationSelection = (locations, tokens, language) => {
  return resolvePagedSelection(tr(language).selectMarket, locations, tokens, language);
};

const exitMessage = (language) => `END ${tr(language).thanks}`;

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

const priceResultMenu = async (product, market, language) => {
  const range = await fetchAverageSellingPrice(product, market);
  const label = tr(language);

  if (!range) {
    return (
      `CON ${label.pricesIn(product.label, market)}\n` +
      `${label.noPrices}\n` +
      `1. ${label.back}\n` +
      `2. ${label.exit}`
    );
  }

  return (
    `CON ${label.pricesIn(product.label, market)}\n` +
    `${label.priceRange(range.min, range.max, range.unit)}\n` +
    `1. ${label.back}\n` +
    `2. ${label.exit}`
  );
};

const handleUSSD = async (req, res) => {
  const { sessionId = 'unknown', phoneNumber = 'unknown', text = '' } = req.body || {};
  console.log(`USSD | Session: ${sessionId} | Phone: ${phoneNumber} | Input: "${text}"`);

  const inputs = text.split('*').filter((item) => item !== '');
  const [languageChoice, menuChoice] = inputs;

  if (inputs.length === 0) {
    return res.type('text/plain').send(languageMenu());
  }

  const language = LANGUAGES[languageChoice];
  if (!language) {
    return res.type('text/plain').send(`END ${tr('en').invalidLanguage}`);
  }

  if (inputs.length === 1) {
    return res.type('text/plain').send(mainMenu(language));
  }

  if (menuChoice === '2') {
    return res.type('text/plain').send(exitMessage(language));
  }

  if (menuChoice !== '1') {
    return res.type('text/plain').send(`END ${tr(language).invalid}`);
  }

  const products = await fetchProducts();
  if (products.length === 0) {
    return res.type('text/plain').send(`END ${tr(language).noProducts}`);
  }

  const productResult = resolveProductSelection(products, inputs.slice(2), language);
  if (productResult.type === 'menu') {
    return res.type('text/plain').send(productResult.menu);
  }
  if (productResult.type === 'back') {
    return res.type('text/plain').send(mainMenu(language));
  }
  if (productResult.type !== 'selected') {
    return res.type('text/plain').send(`END ${tr(language).invalidProduct}`);
  }

  const product = productResult.item;

  const locations = await fetchLocations(product);
  if (locations.length === 0) {
    return res.type('text/plain').send(`END ${tr(language).noMarkets}`);
  }

  const locationResult = resolveLocationSelection(
    locations,
    inputs.slice(2 + productResult.nextIndex),
    language,
  );
  if (locationResult.type === 'menu') {
    return res.type('text/plain').send(locationResult.menu);
  }
  if (locationResult.type === 'back') {
    return res.type('text/plain').send(productMenu(products, language));
  }
  if (locationResult.type !== 'selected') {
    return res.type('text/plain').send(`END ${tr(language).invalidMarket}`);
  }

  const market = locationResult.item;
  const resultChoice = inputs[2 + productResult.nextIndex + locationResult.nextIndex];

  if (!resultChoice) {
    return res.type('text/plain').send(await priceResultMenu(product, market, language));
  }

  if (resultChoice === '1') {
    return res.type('text/plain').send(locationMenu(locations, language));
  }

  if (resultChoice === '2') {
    return res.type('text/plain').send(exitMessage(language));
  }

  return res.type('text/plain').send(`END ${tr(language).invalid}`);
};

module.exports = { handleUSSD };
