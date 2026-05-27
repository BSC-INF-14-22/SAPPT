# Testing USSD with Africa's Talking

## Prerequisites

Before testing with Africa's Talking, you need:

1. **Africa's Talking Account**
   - Sign up at https://africastalking.com
   - Verify your phone number
   - Add credits to your account (USSD tests are usually free or very cheap)

2. **Deployed Backend**
   - Your backend must be publicly accessible (not localhost)
   - Options: Heroku, Railway, Render, DigitalOcean, or any cloud hosting
   - You'll need a public URL like: https://your-app.herokuapp.com/ussd

3. **Firebase Configuration**
   - Ensure your Firebase credentials are set in the deployed environment
   - Firestore collections (`prices`, `markets`) should have test data

## Step 1: Deploy Your Backend

### Option A: Heroku (Easiest for Beginners)

1. Install Heroku CLI: https://devcenter.heroku.com/articles/heroku-cli
2. Login to Heroku:
   ```bash
   heroku login
   ```
3. Create a new app:
   ```bash
   heroku create your-app-name
   ```
4. Deploy:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   heroku git:remote -a your-app-name
   git push heroku main
   ```
5. Set environment variables:
   ```bash
   heroku config:set PORT=3000
   heroku config:set FIREBASE_PROJECT_ID=your-project-id
   heroku config:set FIREBASE_SERVICE_ACCOUNT_PATH=./smart-agri-price-tracker-firebase-adminsdk-fbsvc-ac2746a0eb.json
   ```
6. Upload your Firebase service account JSON file to Heroku:
   ```bash
   heroku config:add FIREBASE_PRIVATE_KEY="$(cat smart-agri-price-tracker-firebase-adminsdk-fbsvc-ac2746a0eb.json)"
   ```

### Option B: Railway (Simple Alternative)

1. Go to https://railway.app
2. Click "New Project" → "Deploy from GitHub repo"
3. Connect your GitHub repository
4. Add environment variables in Railway dashboard
5. Railway will give you a public URL automatically

### Option C: Ngrok (Quick Testing, Not Production)

For quick testing without full deployment:

1. Download ngrok: https://ngrok.com/download
2. Extract and run:
   ```bash
   ngrok http 3000
   ```
3. Ngrok will give you a temporary public URL like: `https://abc123.ngrok.io`
4. Use this URL for Africa's Talking testing
5. **Note**: Ngrok URLs change every time you restart, so this is only for temporary testing

## Step 2: Configure Africa's Talking USSD

1. Log in to Africa's Talking dashboard: https://account.africastalking.com
2. Navigate to **USSD** → **Create USSD Service**
3. Fill in the details:
   - **Service Name**: SAPPT Price Tracker
   - **USSD Code**: Choose a short code (e.g., *284#)
   - **Callback URL**: `https://your-deployed-url.com/ussd`
   - **Default Response**: (optional, your server handles this)
4. Click **Create Service**

## Step 3: Test with Africa's Talking Simulator

Africa's Talking provides a simulator for testing without a real phone:

1. In Africa's Talking dashboard, go to **USSD** → **Your Services**
2. Find your service and click **Test**
3. Enter a phone number (can be any format)
4. Click **Start Simulation**
5. You'll see the USSD menu in the simulator
6. Test all menu options:
   - Press 1 (View Prices)
   - Press 2 (Select Commodity) → then 1 (Maize)
   - Press 3 (Select Market) → then 1 (First market)
   - Press 4 (Exit)
   - Test 0 (Back) option

## Step 4: Test with Real Phone (Optional)

Once simulator testing works:

1. Ensure you have Africa's Talking credits
2. Dial your USSD code from a real phone on a supported network
3. Test the full menu flow
4. Verify responses match expected behavior

## Step 5: Monitor Logs

Check your backend logs to see incoming requests:

### Heroku
```bash
heroku logs --tail --app your-app-name
```

### Railway
Check the Railway dashboard logs section

### Ngrok
Ngrok shows requests in its console output

## Common Issues

### Issue: "Callback URL not reachable"
- **Cause**: Your backend is not deployed or URL is wrong
- **Solution**: Deploy backend and verify URL is accessible from browser

### Issue: "No price data available"
- **Cause**: Firestore has no data or credentials are wrong
- **Solution**: Add test data to Firestore, check Firebase credentials

### Issue: Session not working
- **Cause**: In-memory session storage doesn't work across multiple server instances
- **Solution**: For production, use Redis or database for session storage

### Issue: USSD response too long
- **Cause**: Response exceeds ~182 character limit
- **Solution**: Reduce number of items shown per screen

## Quick Test with Ngrok (Fastest Method)

If you want to test quickly without full deployment:

1. Start your backend locally:
   ```bash
   cd backend
   npm start
   ```

2. In another terminal, start ngrok:
   ```bash
   ngrok http 3000
   ```

3. Copy the ngrok HTTPS URL (e.g., `https://abc123.ngrok.io`)

4. Set this as your Africa's Talking callback URL:
   `https://abc123.ngrok.io/ussd`

5. Test with Africa's Talking simulator

6. **Important**: Ngrok URL changes when you restart, so you'll need to update Africa's Talking each time

## Environment Variables for Deployment

Make sure these are set in your deployment platform:

```
PORT=3000
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_SERVICE_ACCOUNT_PATH=./your-service-account.json
```

For platforms that don't support file uploads, you may need to:

1. Convert the JSON file to environment variables
2. Or use a secret management service
3. Or base64 encode the JSON and decode it in your code

## Verification Checklist

Before going live:

- [ ] Backend deployed and accessible via public URL
- [ ] Firebase credentials configured correctly
- [ ] Firestore has test data (prices and markets)
- [ ] Africa's Talking USSD service created
- [ ] Callback URL set correctly
- [ ] Simulator testing passes for all menu options
- [ ] Real phone testing passes (optional but recommended)
- [ ] Error handling works (invalid inputs, no data, etc.)
- [ ] Logs show incoming requests from Africa's Talking

## Next Steps After Testing

Once testing is successful:

1. Consider adding session storage (Redis) for production
2. Add analytics/logging for USSD usage
3. Set up monitoring for the backend
4. Consider adding more features (price alerts, market trends, etc.)
5. Document the USSD code for users
