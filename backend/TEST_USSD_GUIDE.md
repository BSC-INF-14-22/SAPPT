# Beginner Guide to Test USSD Changes

## Prerequisites
- Node.js installed on your computer
- Firebase project with Firestore data (prices and markets collections)
- Terminal/Command Prompt access

## Step 1: Set Up Environment Variables

1. Navigate to the backend folder:
   ```bash
   cd backend
   ```

2. Copy the example environment file:
   ```bash
   copy .env.example .env
   ```

3. Open `.env` in a text editor and fill in your Firebase credentials:
   ```
   PORT=3000
   FIREBASE_SERVICE_ACCOUNT_PATH=./smart-agri-price-tracker-firebase-adminsdk-fbsvc-ac2746a0eb.json
   FIREBASE_PROJECT_ID=your-actual-project-id
   ```

4. Save the file

## Step 2: Install Dependencies

If you haven't installed dependencies yet:
```bash
npm install
```

## Step 3: Start the Backend Server

1. In the backend folder, run:
   ```bash
   npm start
   ```

2. You should see:
   ```
   🌾 ─────────────────────────────────────────────────
   ✅  SAPPT API Server running on port 3000
   🔗  Local:    http://localhost:3000
   🔗  USSD:     http://localhost:3000/ussd
   🌾 ─────────────────────────────────────────────────
   ```

3. Keep this terminal window open

## Step 4: Test USSD with cURL (Easiest Method)

Open a NEW terminal window and test each menu option:

### Test 1: Initial Menu
```bash
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text="
```

**Expected Response:**
```
CON Welcome to SAPPT Market Prices 🌾
Select an option:
1. View Prices
2. Select Commodity
3. Select Market
4. Exit
```

### Test 2: View Prices (Option 1)
```bash
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=1"
```

**Expected Response:**
```
END Latest Prices:
Maize: ZMW35.50/50kg
Soybean: ZMW42.00/50kg
...
Source: SAPPT
```

### Test 3: Select Commodity Menu (Option 2)
```bash
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=2"
```

**Expected Response:**
```
CON Select a commodity:
1. Maize
2. Soybean
3. Groundnuts
4. Wheat
5. Rice
0. Back
```

### Test 4: View Specific Commodity Price (Option 2 → 1)
```bash
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=2*1"
```

**Expected Response:**
```
END Maize Price:
ZMW 35.50 per 50kg
Market: Lusaka Central
Source: SAPPT System
```

### Test 5: Select Market Menu (Option 3)
```bash
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=3"
```

**Expected Response:**
```
CON Select a market:
1. Lusaka Central
2. Kitwe Main
...
0. Back
```

### Test 6: View Market Prices (Option 3 → 1)
```bash
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=3*1"
```

**Expected Response:**
```
END Prices at Lusaka Central:
Maize: ZMW35.50/50kg
Soybean: ZMW42.00/50kg
...
Source: SAPPT
```

### Test 7: Exit (Option 4)
```bash
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=4"
```

**Expected Response:**
```
END Thank you for using SAPPT! 🌾
Helping farmers get fair prices.
```

### Test 8: Back to Main Menu (Option 2 → 0)
```bash
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=2*0"
```

**Expected Response:**
```
CON Welcome to SAPPT Market Prices 🌾
Select an option:
1. View Prices
2. Select Commodity
3. Select Market
4. Exit
```

## Step 5: Troubleshooting

### Server won't start
- Check if port 3000 is already in use
- Try a different port: change `PORT=3001` in `.env`

### "No price data available" error
- Ensure your Firestore has data in the `prices` collection
- Check that the Firebase credentials in `.env` are correct

### "No markets available" error
- Ensure your Firestore has data in the `markets` collection
- Check that markets have `isActive: true` field

### Connection refused
- Make sure the backend server is running
- Check that you're testing on the correct port (default 3000)

## Step 6: Test with Postman (Optional, More Visual)

If you prefer a graphical interface:

1. Download and install Postman (free)
2. Create a new POST request
3. URL: `http://localhost:3000/ussd`
4. Go to the "Body" tab
5. Select "x-www-form-urlencoded"
6. Add these key-value pairs:
   - `sessionId`: test123
   - `serviceCode`: *123#
   - `phoneNumber`: +260971234567
   - `text`: (leave empty for initial menu, or use "1", "2", "2*1", etc.)
7. Click "Send"

## Step 7: Verify All Menu Paths

Check that each path works:
- ✅ Initial menu displays
- ✅ View Prices shows data
- ✅ Select Commodity shows commodity list
- ✅ Selecting a commodity shows its price
- ✅ Select Market shows market list
- ✅ Selecting a market shows its prices
- ✅ Exit works
- ✅ Back navigation works (option 0)
- ✅ Invalid input shows error message

## Next Steps After Local Testing

Once local testing passes:
1. Deploy your backend to a hosting service (Heroku, Railway, etc.)
2. Get the public URL (e.g., https://your-app.herokuapp.com/ussd)
3. Configure Africa's Talking USSD service with that URL
4. Test with a real mobile phone

## Quick Reference: cURL Commands

Copy and paste these for quick testing:

```bash
# Menu
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text="

# View Prices
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=1"

# Commodity Menu
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=2"

# Specific Commodity (Maize)
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=2*1"

# Market Menu
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=3"

# Specific Market
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=3*1"

# Exit
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=4"

# Back
curl -X POST http://localhost:3000/ussd -d "sessionId=test123&serviceCode=*123#&phoneNumber=+260971234567&text=2*0"
```
