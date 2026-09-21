// Optional Stripe-backed credits system. When STRIPE_SECRET_KEY is unset, billing is
// simply off - uploads aren't gated (see routes/upload.js), matching the "manual
// invoicing" mode this app shipped with in Phase 1.
const Stripe = require('stripe');
const { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_CREDIT_PRICE_CENTS } = require('../config');

let client = null;
function getClient() {
  if (!client) client = new Stripe(STRIPE_SECRET_KEY);
  return client;
}

async function createCheckoutSession({ accountId, quantity, successUrl, cancelUrl }) {
  const stripe = getClient();
  return stripe.checkout.sessions.create({
    mode: 'payment',
    line_items: [
      {
        price_data: {
          currency: 'usd',
          product_data: { name: 'Clip Studio processing credit' },
          unit_amount: STRIPE_CREDIT_PRICE_CENTS,
        },
        quantity,
      },
    ],
    metadata: { accountId, quantity: String(quantity) },
    success_url: successUrl,
    cancel_url: cancelUrl,
  });
}

// Verifies the webhook signature and returns the parsed event, or throws if invalid -
// this is the actual security boundary for the webhook endpoint (it has no ACCESS_TOKEN
// of ours to check; Stripe proves itself via this signature instead).
function verifyWebhookSignature(rawBody, signatureHeader) {
  const stripe = getClient();
  return stripe.webhooks.constructEvent(rawBody, signatureHeader, STRIPE_WEBHOOK_SECRET);
}

module.exports = { createCheckoutSession, verifyWebhookSignature };
