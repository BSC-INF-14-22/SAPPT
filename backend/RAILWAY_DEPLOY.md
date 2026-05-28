# Deploy to Railway for Africa's Talking Testing

## Why Railway?
- Free tier available
- No ngrok authentication issues
- Permanent public URL (doesn't change like ngrok)
- Easy deployment from GitHub
- Perfect for Africa's Talking USSD testing

## Step 1: Prepare Your Repository

1. Ensure your backend code is committed to GitHub
2. Make sure `.env` is in `.gitignore` (it should be)
3. Create a `railway.json` file in the backend folder:

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "npm start",
    "healthcheckPath": "/",
    "healthcheckTimeout": 100,
    "restartPolicyType": "ON_FAILURE"
  }
}
```

## Step 2: Deploy to Railway

### Option A: Via Railway Website (Easiest)

1. Go to https://railway.app
2. Click **"New Project"** → **"Deploy from GitHub repo"**
3. Connect your GitHub account if needed
4. Select your SAPPT repository
5. Railway will detect it's a Node.js project automatically
6. Click **"Deploy"**

### Option B: Via Railway CLI

1. Install Railway CLI:
   ```bash
   npm install -g @railway/cli
   ```

2. Login:
   ```bash
   railway login
   ```

3. Initialize:
   ```bash
   cd backend
   railway init
   ```

4. Deploy:
   ```bash
   railway up
   ```

## Step 3: Add Environment Variables

After deployment, add your Firebase credentials:

1. Go to your Railway project dashboard
2. Click on your project
3. Click **"Variables"** tab
4. Add these variables:

```
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"..."}
```

5. Recommended Railway setup:

   - Open your Firebase service account JSON file.
   - Copy the entire JSON object into one Railway variable named `FIREBASE_SERVICE_ACCOUNT_JSON`.
   - Keep the `\n` sequences inside `private_key` exactly as they appear in the JSON.
   - Do not set `FIREBASE_SERVICE_ACCOUNT_PATH` on Railway unless you also ship the JSON file inside the deployment.
   - Do not manually set `PORT`; Railway provides it automatically.

   Alternative split-variable setup:
   ```
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n
   FIREBASE_CLIENT_EMAIL=your-service-account-email
   ```

## Step 4: Get Your Public URL

1. After deployment, Railway will show your project URL
2. It looks like: `https://your-app-name.up.railway.app`
3. Your USSD endpoint will be: `https://your-app-name.up.railway.app/ussd`

## Step 5: Test the Deployed Endpoint

Test with PowerShell:
```powershell
Invoke-WebRequest -Uri "https://your-app-name.up.railway.app/ussd" -Method POST -Body "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text="
```

You should see the same response as localhost:
```
CON Welcome to SAPPT Market Prices 🌾
Select an option:
1. View Prices
2. Select Commodity
3. Select Market
4. Exit
```

## Step 6: Configure Africa's Talking

1. Log in to Africa's Talking dashboard
2. Go to **USSD** → **Create USSD Service**
3. Set callback URL to: `https://your-app-name.up.railway.app/ussd`
4. Test with Africa's Talking simulator

## Troubleshooting

### Issue: Build fails
- **Solution**: Check Railway build logs for errors
- Make sure `package.json` has correct start script

### Issue: Firebase connection fails
- **Solution**: Verify environment variables are set correctly
- Check that the Firebase project ID matches

### Issue: USSD endpoint returns 404
- **Solution**: Ensure the route is mounted correctly in `server.js`
- Check that Railway is running on port 3000

### Issue: No data from Firestore
- **Solution**: Verify Firestore has test data
- Check Firebase credentials are correct

## Advantages Over Ngrok

✅ Permanent URL (doesn't change)
✅ No authentication required
✅ Free tier available
✅ Better for production testing
✅ Automatic HTTPS
✅ Built-in logging
✅ Easy to redeploy with code changes

## Next Steps

Once Railway deployment is working:
1. Test all USSD menu options
2. Monitor Railway logs for incoming requests
3. Consider adding a database for session storage
4. Set up monitoring and alerts
