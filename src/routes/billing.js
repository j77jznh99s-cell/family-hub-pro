const express = require('express');
const { createCheckoutSession } = require('../services/billing');
const { STRIPE_SUCCESS_URL, STRIPE_CANCEL_URL } = require('../config');
const db = require('../db');

const router = express.Router();

router.post('/checkout', async (req, res, next) => {
  try {
    const { accountId, quantity } = req.body || {};
    const qty = parseInt(quantity, 10);

    if (!accountId || typeof accountId !== 'string') {
      return res.status(400).json({ error: 'accountId is required' });
    }
    if (!Number.isInteger(qty) || qty < 1) {
      return res.status(400).json({ error: 'quantity must be a positive integer' });
    }

    const origin = `${req.protocol}://${req.get('host')}`;
    const session = await createCheckoutSession({
      accountId,
      quantity: qty,
      successUrl: STRIPE_SUCCESS_URL || `${origin}/?checkout=success`,
      cancelUrl: STRIPE_CANCEL_URL || `${origin}/?checkout=cancel`,
    });

    res.json({ url: session.url });
  } catch (err) {
    next(err);
  }
});

router.get('/balance', async (req, res, next) => {
  try {
    const accountId = req.query.accountId;
    if (!accountId) return res.status(400).json({ error: 'accountId is required' });
    const account = await db.getOrCreateAccount(accountId);
    res.json({ accountId: account.id, credits: account.credits });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
