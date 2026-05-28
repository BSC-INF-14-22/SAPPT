const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const CONFIG_VERSION = 'firebase-config-env-json-v2';

const present = (value) => (
  typeof value === 'string'
  && value.trim() !== ''
  && value.trim().toLowerCase() !== 'undefined'
  && value.trim().toLowerCase() !== 'null'
);

const normalizePrivateKey = (key) => key.replace(/\\n/g, '\n');

const normalizeServiceAccount = (serviceAccount) => {
  if (!serviceAccount || typeof serviceAccount !== 'object' || Array.isArray(serviceAccount)) {
    throw new Error('Firebase service account must be a JSON object.');
  }

  return {
    ...serviceAccount,
    private_key: present(serviceAccount.private_key)
      ? normalizePrivateKey(serviceAccount.private_key)
      : serviceAccount.private_key,
  };
};

const parseServiceAccountJson = (value, envName) => {
  try {
    return normalizeServiceAccount(JSON.parse(value));
  } catch (jsonError) {
    try {
      return normalizeServiceAccount(JSON.parse(Buffer.from(value, 'base64').toString('utf8')));
    } catch (base64Error) {
      throw new Error(`${envName} must be valid service-account JSON or base64-encoded JSON.`);
    }
  }
};

const serviceAccountFromFile = (filePath) => {
  const absolutePath = path.resolve(filePath);

  try {
    const contents = fs.readFileSync(absolutePath, 'utf8');
    return parseServiceAccountJson(contents, 'FIREBASE_SERVICE_ACCOUNT_PATH');
  } catch (err) {
    throw new Error(`Could not load Firebase service account at ${absolutePath}: ${err.message}`);
  }
};

const serviceAccountFromEnvVars = () => {
  if (!present(process.env.FIREBASE_PRIVATE_KEY) || !present(process.env.FIREBASE_CLIENT_EMAIL)) {
    return null;
  }

  return normalizeServiceAccount({
    type: 'service_account',
    project_id: process.env.FIREBASE_PROJECT_ID,
    private_key: process.env.FIREBASE_PRIVATE_KEY,
    client_email: process.env.FIREBASE_CLIENT_EMAIL,
  });
};

const getServiceAccount = () => {
  if (present(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)) {
    return parseServiceAccountJson(
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON,
      'FIREBASE_SERVICE_ACCOUNT_JSON'
    );
  }

  if (present(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64)) {
    return parseServiceAccountJson(
      process.env.FIREBASE_SERVICE_ACCOUNT_BASE64,
      'FIREBASE_SERVICE_ACCOUNT_BASE64'
    );
  }

  if (present(process.env.FIREBASE_SERVICE_ACCOUNT_PATH)) {
    return serviceAccountFromFile(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
  }

  return serviceAccountFromEnvVars();
};

const serviceAccount = getServiceAccount();

if (!serviceAccount) {
  throw new Error(
    'Firebase credentials not found. On Railway, set FIREBASE_SERVICE_ACCOUNT_JSON to the full service account JSON, or set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY.'
  );
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id,
  });

  console.log(`Firebase Admin initialized (${CONFIG_VERSION})`);
}

const db = admin.firestore();

module.exports = { admin, db };
