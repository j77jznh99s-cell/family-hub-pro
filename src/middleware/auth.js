const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const { ACCESS_TOKEN, PRESENTER_TOKEN } = require('../config');

// Constant-time comparison, so response timing can't leak how much of a guess was right.
function tokensMatch(provided, expected) {
  if (typeof provided !== 'string' || !expected) return false;
  const a = crypto.createHash('sha256').update(provided).digest();
  const b = crypto.createHash('sha256').update(expected).digest();
  return crypto.timingSafeEqual(a, b);
}

// Slows down token guessing: after 30 rejected (401) requests from one IP in 15 minutes,
// further requests get 429 until the window passes. Successful requests don't count.
function authFailureLimiter({ limit = 30, windowMs = 15 * 60 * 1000 } = {}) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    requestWasSuccessful: (req, res) => res.statusCode !== 401,
    skipSuccessfulRequests: true,
    message: { error: 'Too many failed attempts - try again later' },
  });
}

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
  if (tokensMatch(provided, ACCESS_TOKEN)) return next();

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
    if (tokensMatch(provided, expected)) return next();
    return res.status(401).json({ error: 'Unauthorized' });
  };
}

module.exports = { requireAccessToken, makePresenterAuth, tokensMatch, authFailureLimiter };
