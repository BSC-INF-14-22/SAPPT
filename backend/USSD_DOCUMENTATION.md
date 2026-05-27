# USSD Menu Flow Documentation

## Overview
This document describes the beginner-friendly USSD menu flow for the SAPPT Agricultural Market Price Tracker, using Africa's Talking format with dynamic Firestore data and proper session handling.

## Menu Structure

```
Dial *XXX#
└── Welcome Menu
    ├── 1. View Prices
    ├── 2. Select Commodity
    ├── 3. Select Market
    └── 4. Exit
```

## Flow Details

### Flow 1: View Prices
- **User Input**: `1`
- **Action**: Fetches latest 5 prices from Firestore across all markets
- **Response**: Shows compact price list and ends session

### Flow 2: Select Commodity
- **User Input**: `2`
- **Action**: Displays commodity selection menu
- **Sub-menu**: User selects specific commodity (1-5)
- **Response**: Shows latest price for selected commodity and ends session

### Flow 3: Select Market
- **User Input**: `3`
- **Action**: Fetches active markets from Firestore and displays market selection menu
- **Sub-menu**: User selects specific market
- **Response**: Shows prices at selected market and ends session

### Flow 4: Exit
- **User Input**: `4`
- **Action**: Ends session with thank you message

## Africa's Talking Format

### Request Format
Africa's Talking sends POST requests to your webhook URL with URL-encoded body:

```
POST /ussd
Content-Type: application/x-www-form-urlencoded

sessionId=ATUid_xxx&serviceCode=*XXX#&phoneNumber=+260971234567&text=1*2
```

### Response Format
Your server responds with plain text (NOT JSON):

- **CON** - Continue session: `CON Your message here`
- **END** - End session: `END Your message here`

## Example Requests and Responses

### Example 1: Initial Menu Display

**Request:**
```http
POST /ussd HTTP/1.1
Host: your-server.com
Content-Type: application/x-www-form-urlencoded

sessionId=ATUid_123456&serviceCode=*123#&phoneNumber=+260971234567&text=
```

**Response:**
```
CON Welcome to SAPPT Market Prices 🌾
Select an option:
1. View Prices
2. Select Commodity
3. Select Market
4. Exit
```

---

### Example 2: View Prices (Option 1)

**Request:**
```http
POST /ussd HTTP/1.1
Host: your-server.com
Content-Type: application/x-www-form-urlencoded

sessionId=ATUid_123456&serviceCode=*123#&phoneNumber=+260971234567&text=1
```

**Response:**
```
END Latest Prices:
Maize: ZMW35.50/50kg
Soybean: ZMW42.00/50kg
Groundnuts: ZMW55.00/50kg
Wheat: ZMW48.00/50kg
Rice: ZMW38.00/50kg
Source: SAPPT
```

---

### Example 3: Select Commodity (Option 2)

**Request:**
```http
POST /ussd HTTP/1.1
Host: your-server.com
Content-Type: application/x-www-form-urlencoded

sessionId=ATUid_123456&serviceCode=*123#&phoneNumber=+260971234567&text=2
```

**Response:**
```
CON Select a commodity:
1. Maize
2. Soybean
3. Groundnuts
4. Wheat
5. Rice
0. Back
```

---

### Example 4: View Specific Commodity Price (Option 2→1)

**Request:**
```http
POST /ussd HTTP/1.1
Host: your-server.com
Content-Type: application/x-www-form-urlencoded

sessionId=ATUid_123456&serviceCode=*123#&phoneNumber=+260971234567&text=2*1
```

**Response:**
```
END Maize Price:
ZMW 35.50 per 50kg
Market: Lusaka Central
Source: SAPPT System
```

---

### Example 5: Select Market (Option 3)

**Request:**
```http
POST /ussd HTTP/1.1
Host: your-server.com
Content-Type: application/x-www-form-urlencoded

sessionId=ATUid_123456&serviceCode=*123#&phoneNumber=+260971234567&text=3
```

**Response:**
```
CON Select a market:
1. Lusaka Central
2. Kitwe Main
3. Ndola Market
4. Livingstone
5. Kabwe
0. Back
```

---

### Example 6: View Market Prices (Option 3→1)

**Request:**
```http
POST /ussd HTTP/1.1
Host: your-server.com
Content-Type: application/x-www-form-urlencoded

sessionId=ATUid_123456&serviceCode=*123#&phoneNumber=+260971234567&text=3*1
```

**Response:**
```
END Prices at Lusaka Central:
Maize: ZMW35.50/50kg
Soybean: ZMW42.00/50kg
Groundnuts: ZMW55.00/50kg
Source: SAPPT
```

---

### Example 7: Exit (Option 4)

**Request:**
```http
POST /ussd HTTP/1.1
Host: your-server.com
Content-Type: application/x-www-form-urlencoded

sessionId=ATUid_123456&serviceCode=*123#&phoneNumber=+260971234567&text=4
```

**Response:**
```
END Thank you for using SAPPT! 🌾
Helping farmers get fair prices.
```

---

### Example 8: Back to Main Menu (Option 2→0)

**Request:**
```http
POST /ussd HTTP/1.1
Host: your-server.com
Content-Type: application/x-www-form-urlencoded

sessionId=ATUid_123456&serviceCode=*123#&phoneNumber=+260971234567&text=2*0
```

**Response:**
```
CON Welcome to SAPPT Market Prices 🌾
Select an option:
1. View Prices
2. Select Commodity
3. Select Market
4. Exit
```

---

### Example 9: Invalid Selection

**Request:**
```http
POST /ussd HTTP/1.1
Host: your-server.com
Content-Type: application/x-www-form-urlencoded

sessionId=ATUid_123456&serviceCode=*123#&phoneNumber=+260971234567&text=9
```

**Response:**
```
END Invalid input. Please dial again.
```

---

## Session Handling

### Session ID
- Each USSD call receives a unique `sessionId` from Africa's Talking
- Session ID changes every time the user dials the USSD code
- Used to track user state across menu levels

### Text Accumulation
- The `text` field accumulates user inputs separated by `*`
- Level 0: `text = ""` (initial menu)
- Level 1: `text = "1"`, `text = "2"`, etc. (main menu selection)
- Level 2: `text = "2*1"`, `text = "3*2"`, etc. (submenu selection)

### Session Storage
- Markets are temporarily stored in `req.app.locals[sessionId]` for level 2 access
- Cleaned up after use to prevent memory leaks
- For production, consider using Redis or a database for session storage

## Firestore Integration

### Collections Used
1. **prices** - Contains price data
   - Fields: `productName`, `price`, `unit`, `marketId`, `submittedAt`
   
2. **markets** - Contains market information
   - Fields: `name`, `isActive`

### Queries
- `fetchLatestPrices()` - Gets top 5 prices ordered by submission time
- `fetchLatestPriceForProduct(productName)` - Gets latest price for specific product
- `fetchMarkets()` - Gets active markets ordered by name
- `fetchPricesForMarket(marketId)` - Gets prices for specific market

## Testing Locally

### Using cURL
```bash
# Test initial menu
curl -X POST http://localhost:3000/ussd \
  -d "sessionId=ATUid_test123&serviceCode=*123#&phoneNumber=+260971234567&text="

# Test view prices
curl -X POST http://localhost:3000/ussd \
  -d "sessionId=ATUid_test123&serviceCode=*123#&phoneNumber=+260971234567&text=1"

# Test select commodity
curl -X POST http://localhost:3000/ussd \
  -d "sessionId=ATUid_test123&serviceCode=*123#&phoneNumber=+260971234567&text=2"

# Test specific commodity
curl -X POST http://localhost:3000/ussd \
  -d "sessionId=ATUid_test123&serviceCode=*123#&phoneNumber=+260971234567&text=2*1"
```

### Using Postman
1. Set method to POST
2. URL: `http://localhost:3000/ussd`
3. Body type: `x-www-form-urlencoded`
4. Add parameters: `sessionId`, `serviceCode`, `phoneNumber`, `text`

## Deployment

### Africa's Talking Setup
1. Log in to Africa's Talking dashboard
2. Navigate to USSD section
3. Create a new USSD service
4. Set callback URL to: `https://your-server.com/ussd`
5. Choose your USSD code (e.g., *123#)
6. Test using a mobile phone on the supported network

### Environment Variables
Ensure these are set in your `.env` file:
```
PORT=3000
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-service-account-email
FIREBASE_PRIVATE_KEY=your-private-key
AFRICASTALKING_USERNAME=your-username
AFRICASTALKING_API_KEY=your-api-key
```

## Best Practices

1. **Keep responses short** - USSD screens have ~182 character limit
2. **Use clear numbering** - Help users navigate easily
3. **Provide back option** - Allow users to return to previous menus
4. **Handle errors gracefully** - Show helpful error messages
5. **Validate inputs** - Prevent invalid selections from causing errors
6. **Log sessions** - Track usage for debugging and analytics
7. **Test thoroughly** - Test all menu paths before deployment

## Troubleshooting

### Common Issues

**Issue**: Session not persisting
- **Solution**: Check that `req.app.locals` is being used correctly

**Issue**: No data from Firestore
- **Solution**: Verify Firestore rules and collection names match

**Issue**: USSD response too long
- **Solution**: Reduce the number of items shown per screen

**Issue**: Invalid input not handled
- **Solution**: Ensure all edge cases have fallback responses

## Support

For issues or questions:
- Check the server logs for detailed error messages
- Verify Africa's Talking webhook configuration
- Ensure Firestore data exists for testing
