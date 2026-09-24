const { ACCESS_TOKEN, PRESENTER_TOKEN } = require('../config');

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

// The presenter view holds your own scripts and videos, so it gets its own token: clients
// who share the dashboard's ACCESS_TOKEN must not be able to read it. Falls back to
// ACCESS_TOKEN (with a one-time warning) only when PRESENTER_TOKEN isn't set.
function makePresenterAuth({ presenterToken = PRESENTER_TOKEN, accessToken = ACCESS_TOKEN, warn = console.warn } = {}) {
  const expected = presenterToken || accessToken;
  let warnedFallback = false;
  return function requirePresenterToken(req, res, next) {
    if (!presenterToken && !warnedFallback) {
      warn(
        '[auth] PRESENTER_TOKEN is not set - the presenter view uses ACCESS_TOKEN, so anyone you gave that token to can read your presenter runs.'
      );
      warnedFallback = true;
    }
    if (!expected) return next();
    const provided = req.get('x-presenter-token') || req.query.ptoken || req.get('x-access-token') || req.query.token;
    if (provided === expected) return next();
    return res.status(401).json({ error: 'Unauthorized' });
  };
}

module.exports = { requireAccessToken, makePresenterAuth };
