const { ACCESS_TOKEN } = require('../config');

let warned = false;

function requireAccessToken(req, res, next) {
  if (!ACCESS_TOKEN) {
    if (!warned) {
      console.warn(
        '[auth] ACCESS_TOKEN is not set - the API and dashboard are unprotected. Set ACCESS_TOKEN before sharing this with clients.'
      );
      warned = true;
    }
    return next();
  }

  const provided = req.get('x-access-token') || req.query.token;
  if (provided === ACCESS_TOKEN) return next();

  return res.status(401).json({ error: 'Unauthorized' });
}

module.exports = { requireAccessToken };
