# Beginner's Guide: World Bank API Integration with Node.js and Firestore

This guide explains how to fetch global agricultural indicators and statistics from the public **World Bank API**, clean the data, and store it in your **Firebase Firestore** database.

---

## 1. World Bank API Structure Explained

Unlike private APIs, the World Bank API is free and does not require an API key to access public datasets.

### API Request Structure (URL breakdown)
To get data, we build a specific URL endpoint using this structure:
`http://api.worldbank.org/v2/country/{country_code}/indicator/{indicator_id}`

Where:
* **`country_code`**: The region we want data for. Use `MWI` for Malawi, or `WLD` for World averages.
* **`indicator_id`**: The specific ID of the statistic we want. For example:
  * `NV.AGR.TOTL.ZS`: Agriculture, forestry, and fishing value added (% of GDP)
  * `AG.LND.AGRI.ZS`: Agricultural land (% of land area)

### Query Parameters (Filtering the Data)
We add filters at the end of the URL using a `?` symbol:
* `?format=json`: By default, the World Bank returns data in XML format. We add `format=json` so we get clean JSON that Node.js can parse.
* `?date=2020:2024`: Filters the data to only return data between the years 2020 and 2024.

---

## 2. World Bank API Integration Script (Node.js & Firestore)

This Node.js script fetches the **Agriculture % of GDP** indicator for Malawi (`MWI`) from 2018 to 2024, cleans the results to remove empty records, and saves them to Firestore.

```javascript
const admin = require('firebase-admin');

// 1. Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Main function to fetch and sync data
async function syncWorldBankData() {
  const country = 'MWI';                  // Malawi
  const indicator = 'NV.AGR.TOTL.ZS';     // Agriculture % of GDP
  const dateRange = '2018:2024';          // Filter years

  // Build the request URL
  const url = `http://api.worldbank.org/v2/country/${country}/indicator/${indicator}?format=json&date=${dateRange}`;

  try {
    console.log(`Fetching World Bank data from: ${url}`);
    
    // 2. Fetch the data from the World Bank REST API
    const response = await fetch(url);
    const rawData = await response.json();

    // Note: World Bank API returns an array containing two items:
    // rawData[0] -> metadata details (page size, total results)
    // rawData[1] -> the actual data array we need
    const records = rawData[1];

    if (!records || records.length === 0) {
      console.log("No records found.");
      return;
    }

    console.log(`Found ${records.length} records. Beginning data cleaning...`);

    // 3. Loop through records, clean them, and store in Firestore
    for (const record of records) {
      
      // --- Data Cleaning ---
      // The World Bank frequently returns null values for years where statistics are missing.
      // We check if the value is null. If it is, we skip it!
      if (record.value === null) {
        console.log(`Skipping year ${record.date} because value is null.`);
        continue; 
      }

      // Format the cleaned record to fit our Firestore schema
      const formattedRecord = {
        indicatorName: record.indicator.value, // e.g. "Agriculture, forestry, and fishing, value added (% of GDP)"
        indicatorId: record.indicator.id,     // e.g. "NV.AGR.TOTL.ZS"
        countryCode: record.countryiso3code,   // e.g. "MWI"
        countryName: record.country.value,     // e.g. "Malawi"
        year: parseInt(record.date),           // Convert year string "2022" to integer 2022
        value: parseFloat(record.value.toFixed(2)), // Standardize percentage to 2 decimal places
        sourceType: "automated",
        dataSourceId: "world_bank_api",
        createdAt: admin.firestore.FieldValue.serverTimestamp() // Timestamp of when we stored it
      };

      // 4. Save to Firestore
      // We use a custom document ID like "MWI_2022_NV.AGR.TOTL.ZS" to prevent duplicates
      const docId = `${formattedRecord.countryCode}_${formattedRecord.year}_${formattedRecord.indicatorId}`;
      
      await db.collection('national_statistics')
        .doc(docId)
        .set(formattedRecord, { merge: true }); // 'merge: true' updates the doc if it exists

      console.log(`Saved record for year ${formattedRecord.year}: ${formattedRecord.value}%`);
    }

    console.log("World Bank sync job completed successfully!");

  } catch (error) {
    console.error("Failed to sync World Bank data:", error);
  }
}

syncWorldBankData();
```

---

## 3. Explanation of Data Cleaning Actions in Code

1. **Handling Empty Values (`null` checks)**: The World Bank database has placeholder slots for historical records, meaning it might return `{ "date": "2024", "value": null }`. Our code does `if (record.value === null) continue;` to avoid cluttering Firestore with empty/meaningless documents.
2. **Formatting Numbers (`toFixed`)**: Raw values from APIs can be overly detailed due to decimal float errors (e.g. `22.4503928182%`). We use `parseFloat(value.toFixed(2))` to round it to a clean percentage number like `22.45`.
3. **Smart Document IDs (`set()` with `merge`)**: Instead of using Firestore's auto-generated IDs which create new files every time the sync runs, we generate our own: `Country_Year_IndicatorId`. This ensures that if the script runs again tomorrow, it updates existing records instead of writing duplicates!
