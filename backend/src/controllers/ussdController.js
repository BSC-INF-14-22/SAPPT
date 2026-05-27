// ============================================================
//  src/controllers/ussdController.js
//
//  WHAT IS USSD?
//  USSD (Unstructured Supplementary Service Data) is a protocol
//  used by mobile phones. When you dial *123#, your phone sends
//  a USSD request through the mobile network.
//
//  Africa's Talking (AT) intercepts that request and forwards
//  it to YOUR server as an HTTP POST request. Your server reads
//  the user's input, queries Firestore, and sends back a text
//  response. AT then displays that text on the user's phone.
//
//  KEY CONCEPTS:
//  ─────────────────────────────────────────────────────────
//  sessionId   → A unique ID for each phone call to the USSD code.
//                It CHANGES every time the user dials.
//
//  phoneNumber → The user's phone number (e.g. +260971234567)
//
//  text        → The ACCUMULATED input from the user so far.
//                - When user first dials *XXX#:         text = ""
//                - After user presses 1:               text = "1"
//                - After user presses 1, then 2:       text = "1*2"
//                - After user presses 1, 2, then 3:    text = "1*2*3"
//
//  CON vs END:
//  ─────────────────────────────────────────────────────────
//  "CON Some message"  → Continue: show the message and KEEP session open
//  "END Some message"  → End: show the message and CLOSE the session
//
//  MENU FLOW FOR SAPPT (Linear Flow):
//  ─────────────────────────────────────────────────────────
//  Dial *XXX#
//  └── Welcome Menu (text = "")
//      ├── 1. View Prices
//      ├── 2. Select Commodity
//      ├── 3. Select Market
//      └── 4. Exit
//
//  Flow 1: View Prices (text = "1")
//      └── Shows latest prices from all markets
//
//  Flow 2: Select Commodity (text = "2")
//      └── Pick commodity (text = "2*X")
//          └── Shows prices for selected commodity
//
//  Flow 3: Select Market (text = "3")
//      └── Pick market (text = "3*X")
//          └── Shows prices at selected market
//
//  Flow 4: Exit (text = "4")
//      └── Ends session
// ============================================================

const { db } = require('../config/firebase');

// ─────────────────────────────────────────────────────────────
//  PRODUCTS LIST
//  Hardcoded for speed — no Firestore read needed for the menu.
//  The numbers map to the menu options the user presses.
// ─────────────────────────────────────────────────────────────
const PRODUCTS = ['Maize', 'Soybean', 'Groundnuts', 'Wheat', 'Rice'];

// ─────────────────────────────────────────────────────────────
//  HELPER: Fetch latest price from Firestore for a product
//
//  This queries the 'prices' collection filtered by productName,
//  ordered newest first, and returns the top result.
// ─────────────────────────────────────────────────────────────
const fetchLatestPriceForProduct = async (productName) => {
  try {
    const snapshot = await db
      .collection('prices')
      .where('productName', '==', productName)
      .orderBy('submittedAt', 'desc')
      .limit(1)       // Only get the most recent price
      .get();

    if (snapshot.empty) {
      return null; // No price data for this product
    }

    // .docs[0] = the first (most recent) document
    return snapshot.docs[0].data();
  } catch (err) {
    console.error('Firestore fetchLatestPriceForProduct error:', err.message);
    return null;
  }
};

// ─────────────────────────────────────────────────────────────
//  HELPER: Fetch all latest prices from Firestore
//
//  This queries the 'prices' collection ordered newest first,
//  and returns the top 5 prices across all markets.
// ─────────────────────────────────────────────────────────────
const fetchLatestPrices = async () => {
  try {
    const snapshot = await db
      .collection('prices')
      .orderBy('submittedAt', 'desc')
      .limit(5)       // Show at most 5 prices (USSD screens are small!)
      .get();

    return snapshot.docs.map((doc) => doc.data());
  } catch (err) {
    console.error('Firestore fetchLatestPrices error:', err.message);
    return [];
  }
};

// ─────────────────────────────────────────────────────────────
//  HELPER: Fetch all markets from Firestore
// ─────────────────────────────────────────────────────────────
const fetchMarkets = async () => {
  try {
    const snapshot = await db
      .collection('markets')
      .where('isActive', '==', true)
      .orderBy('name', 'asc')
      .limit(5)   // Show at most 5 markets (USSD screens are small!)
      .get();

    return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  } catch (err) {
    console.error('Firestore fetchMarkets error:', err.message);
    return [];
  }
};

// ─────────────────────────────────────────────────────────────
//  HELPER: Fetch prices for a specific market
// ─────────────────────────────────────────────────────────────
const fetchPricesForMarket = async (marketId) => {
  try {
    const snapshot = await db
      .collection('prices')
      .where('marketId', '==', marketId)
      .orderBy('submittedAt', 'desc')
      .limit(3)   // Only show 3 prices — USSD screens are tiny
      .get();

    return snapshot.docs.map((doc) => doc.data());
  } catch (err) {
    console.error('Firestore fetchPricesForMarket error:', err.message);
    return [];
  }
};

// ─────────────────────────────────────────────────────────────
//  MAIN USSD HANDLER
//
//  Africa's Talking calls POST /ussd with this body:
//  {
//    sessionId:   "ATUid_xxxx",
//    serviceCode: "*XXX#",
//    phoneNumber: "+260971234567",
//    text:        "1*2"          ← user pressed 1 then 2
//  }
//
//  Your response MUST be plain text starting with CON or END.
//  Do NOT send JSON. Africa's Talking only reads plain text.
// ─────────────────────────────────────────────────────────────
const handleUSSD = async (req, res) => {
  // Extract the USSD fields from the request body
  const { sessionId, serviceCode, phoneNumber, text } = req.body;

  console.log(`📱 USSD | Session: ${sessionId} | Phone: ${phoneNumber} | Input: "${text}"`);

  // Split the accumulated text by '*' to get each individual choice
  // "1*2" becomes ['1', '2']
  // ""    becomes ['']
  const userInputs = text.split('*');

  // The FIRST input is the main menu choice
  const level1 = userInputs[0]; // e.g. '1', '2', '3', '4' or ''

  // The SECOND input (if any) is the submenu choice
  const level2 = userInputs[1]; // e.g. '1', '2', '0'

  // ── LEVEL 0: No input yet → Show Welcome Menu ──────────
  if (text === '') {
    return res.send(
      'CON Welcome to SAPPT Market Prices 🌾\n' +
      'Select an option:\n' +
      '1. View Prices\n' +
      '2. Select Commodity\n' +
      '3. Select Market\n' +
      '4. Exit'
    );
  }

  // ── LEVEL 1, Option 1: View Prices ─────────────────────
  if (level1 === '1') {
    // Fetch latest prices from Firestore
    const prices = await fetchLatestPrices();

    if (prices.length === 0) {
      return res.send(
        'END No price data available.\n' +
        'Please check back later.'
      );
    }

    // Build a compact price list (USSD max ~182 characters per screen)
    const priceLines = prices
      .map((p) => `${p.productName}: ZMW${p.price}/${p.unit}`)
      .join('\n');

    return res.send(
      'END Latest Prices:\n' +
      priceLines + '\n' +
      'Source: SAPPT'
    );
  }

  // ── LEVEL 1, Option 2: Select Commodity ────────────────
  if (level1 === '2' && !level2) {
    // Build the product menu dynamically from the PRODUCTS array
    // Result: "1. Maize\n2. Soybean\n3. Groundnuts\n..."
    const productMenu = PRODUCTS
      .map((name, index) => `${index + 1}. ${name}`)
      .join('\n');

    return res.send(
      'CON Select a commodity:\n' +
      productMenu + '\n' +
      '0. Back'
    );
  }

  // ── LEVEL 2, Option 2→X: Show price for chosen commodity ─
  if (level1 === '2' && level2) {
    if (level2 === '0') {
      // User pressed 0 = go back to main menu
      return res.send(
        'CON Welcome to SAPPT Market Prices 🌾\n' +
        'Select an option:\n' +
        '1. View Prices\n' +
        '2. Select Commodity\n' +
        '3. Select Market\n' +
        '4. Exit'
      );
    }

    const productIndex = parseInt(level2, 10) - 1; // Convert to 0-based index

    // Validate the choice
    if (isNaN(productIndex) || productIndex < 0 || productIndex >= PRODUCTS.length) {
      return res.send('END Invalid selection. Please dial again.');
    }

    const selectedProduct = PRODUCTS[productIndex];

    // Fetch the latest price from Firestore
    const priceData = await fetchLatestPriceForProduct(selectedProduct);

    if (!priceData) {
      return res.send(
        `END No price data found for ${selectedProduct}.\n` +
        'Please check back later.'
      );
    }

    // Format the price for the small USSD screen
    const price     = priceData.price;
    const unit      = priceData.unit;
    const marketId  = priceData.marketId;

    return res.send(
      `END ${selectedProduct} Price:\n` +
      `ZMW ${price} per ${unit}\n` +
      `Market: ${marketId}\n` +
      'Source: SAPPT System'
    );
  }

  // ── LEVEL 1, Option 3: Select Market ────────────────────
  if (level1 === '3' && !level2) {
    // Fetch active markets from Firestore
    const markets = await fetchMarkets();

    if (markets.length === 0) {
      return res.send('END No markets available at this time.');
    }

    // Build market menu: "1. Lusaka Market\n2. Kitwe Market\n..."
    const marketMenu = markets
      .map((m, index) => `${index + 1}. ${m.name}`)
      .join('\n');

    // Store markets in a simple in-memory way using the session
    // NOTE: For production, use a database/cache keyed by sessionId
    req.app.locals[sessionId] = markets; // Temporarily store for level 2

    return res.send(
      'CON Select a market:\n' +
      marketMenu + '\n' +
      '0. Back'
    );
  }

  // ── LEVEL 2, Option 3→X: Show prices for chosen market ─
  if (level1 === '3' && level2) {
    if (level2 === '0') {
      return res.send(
        'CON Welcome to SAPPT Market Prices 🌾\n' +
        'Select an option:\n' +
        '1. View Prices\n' +
        '2. Select Commodity\n' +
        '3. Select Market\n' +
        '4. Exit'
      );
    }

    // Retrieve the markets we stored at level 1
    const markets = req.app.locals[sessionId] || await fetchMarkets();
    const marketIndex = parseInt(level2, 10) - 1;

    if (isNaN(marketIndex) || marketIndex < 0 || marketIndex >= markets.length) {
      return res.send('END Invalid market selection. Please dial again.');
    }

    const selectedMarket = markets[marketIndex];

    // Fetch latest prices for this market
    const prices = await fetchPricesForMarket(selectedMarket.id);

    if (prices.length === 0) {
      return res.send(
        `END No prices found for\n${selectedMarket.name}.\n` +
        'Please check back later.'
      );
    }

    // Build a compact price list (USSD max ~182 characters per screen)
    const priceLines = prices
      .map((p) => `${p.productName}: ZMW${p.price}/${p.unit}`)
      .join('\n');

    // Clean up the stored session data
    delete req.app.locals[sessionId];

    return res.send(
      `END Prices at ${selectedMarket.name}:\n` +
      priceLines + '\n' +
      'Source: SAPPT'
    );
  }

  // ── LEVEL 1, Option 4: Exit ─────────────────────────────
  if (level1 === '4') {
    return res.send(
      'END Thank you for using SAPPT! 🌾\n' +
      'Helping farmers get fair prices.'
    );
  }

  // ── Fallback: Unknown input ─────────────────────────────
  return res.send('END Invalid input. Please dial again.');
};

module.exports = { handleUSSD };
