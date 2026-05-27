# Beginner's Guide: REST APIs with Node.js and Firebase

If you are new to backend development, this guide explains how **REST APIs** work using simple analogies and realistic code examples featuring Node.js and Firebase.

---

## 1. Core API Concepts Explained Simply

Think of a REST API like a **restaurant service**:

* **API Endpoint (The Menu Item)**: The specific URL address you call. It is like telling the waiter: "I want the number 5 hamburger combo." In web terms, it looks like `https://api.market.com/prices`.
* **GET Request (Placing the Order)**: The method you use to tell the server what you want to do. A `GET` request asks the server to *retrieve* data (like asking a waiter to bring you a plate of food).
* **JSON Response (The Plate of Food)**: The format of the data returned by the server. JSON (JavaScript Object Notation) is a clean, organized text structure that computers can read easily. It is like receiving your hamburger combo neatly arranged on a tray.
* **API Key (Your Member Card / Wallet)**: A secret password that identifies you to the API. It is like showing a VIP club card to the waiter before they let you order. Without it, the server will say "401 Unauthorized".

---

## 2. Code Example 1: Fetching Prices (Node.js)

Below is a simple Node.js script. It uses the modern `fetch` library to request crop prices from a public agricultural portal API using an API key.

```javascript
// Example: Node.js Fetching crop prices
async function getCropPrice() {
  const endpoint = 'https://api.agriportal.com/v1/prices/maize';
  const apiKey = 'secret_agri_key_xyz123'; // Your secret API key

  try {
    // 1. Send the GET request with the API key in the headers
    const response = await fetch(endpoint, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      }
    });

    // 2. Turn the raw network response into a JavaScript object (JSON)
    const data = await response.json();

    // 3. Print the result
    console.log(`The price of ${data.crop} is ${data.price} MK per ${data.unit}`);
  } catch (error) {
    console.error('Error fetching data:', error);
  }
}

getCropPrice();
```

### What the JSON Response Looks Like:
When you call `response.json()`, the server returns a text structure like this:
```json
{
  "crop": "White Maize",
  "price": 450,
  "unit": "kg",
  "currency": "MWK",
  "market": "Lilongwe Central"
}
```

---

## 3. Code Example 2: Saving the API Data to Firestore (Firebase)

Now, let's connect the API fetch to your **Firebase Firestore Database**. We take the data we retrieved from the API and save it as a new document in Firestore.

```javascript
// Import the Firebase Admin SDK
const admin = require('firebase-admin');

// Initialize Firebase (Assuming service account is configured)
admin.initializeApp();
const db = admin.firestore();

// Fetch from API and Save to Firestore
async function importPriceToDatabase() {
  const endpoint = 'https://api.agriportal.com/v1/prices/maize';
  const apiKey = 'secret_agri_key_xyz123';

  try {
    // 1. Fetch data from external REST API
    const response = await fetch(endpoint, {
      headers: { 'Authorization': `Bearer ${apiKey}` }
    });
    const apiData = await response.json();

    // 2. Prepare document format matching our schema
    const newPriceRecord = {
      commodityId: apiData.crop.toLowerCase().replace(" ", "_"), // e.g. "white_maize"
      price: Number(apiData.price),
      unit: apiData.unit,
      currency: apiData.currency,
      marketId: apiData.market.toLowerCase().replace(" ", "_"), // e.g. "lilongwe_central"
      sourceType: "automated",
      dataSourceId: "agri_portal_api",
      validationStatus: "approved",
      priceDate: admin.firestore.Timestamp.now(), // Real-world observation time
      createdAt: admin.firestore.FieldValue.serverTimestamp() // Database write time
    };

    // 3. Write document to 'prices' collection in Firestore
    const docRef = await db.collection('prices').add(newPriceRecord);
    console.log(`Successfully saved price document with ID: ${docRef.id}`);

  } catch (error) {
    console.error('Database write failed:', error);
  }
}

importPriceToDatabase();
```
