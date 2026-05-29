// src/middleware/apiKeyMiddleware.js
// ----------------------------------------------------------
// Optional API‑key guard for routes that may be public.
// If an environment variable FAO_API_KEY is defined, the request
// must include the same value in the `x-api-key` header. If the env
// variable is not set, the middleware simply calls `next()` – making
// the route effectively unrestricted.
// ----------------------------------------------------------
module.exports = (req, res, next) => {
  const expected = process.env.FAO_API_KEY || '';
  // If no key is configured, allow all requests.
  if (!expected) return next();

  const supplied = req.header('x-api-key') || '';
  if (supplied !== expected) {
    return res.status(401).json({
      success: false,
      message: 'Invalid API key',
    });
  }
  return next();
};
