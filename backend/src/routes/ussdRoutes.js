// ============================================================
//  src/routes/ussdRoutes.js
//
//  This file defines the single route that Africa's Talking
//  will call when a user dials your USSD code.
//
//  IMPORTANT:
//  Africa's Talking sends a POST request (not GET).
//  The body is URL-encoded (like a web form), NOT JSON.
//  That's why server.js includes express.urlencoded() middleware.
//
//  Your Africa's Talking dashboard → USSD → Callback URL:
//  Set it to: https://your-server.com/ussd
//  (or http://localhost:3000/ussd for local testing)
// ============================================================

const express       = require('express');
const router        = express.Router();
const { handleUSSD } = require('../controllers/ussdController');

/**
 * POST /ussd
 *
 * Africa's Talking sends:
 *   sessionId=ATUid_xxx
 *   serviceCode=*XXX#
 *   phoneNumber=+260971234567
 *   text=1*2
 *
 * We respond with plain text:
 *   "CON ..." → keep session alive
 *   "END ..." → close session
 */
router.post('/', async (req, res, next) => {
  try {
    await handleUSSD(req, res);
  } catch (error) {
    console.error('USSD request failed:', error && error.stack ? error.stack : error);

    if (!res.headersSent) {
      res
        .type('text/plain')
        .send('END SAPPT is temporarily unavailable. Please try again shortly.');
      return;
    }

    next(error);
  }
});

module.exports = router;
