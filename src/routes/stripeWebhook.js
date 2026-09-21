// Mounted separately in server.js with express.raw() (not express.json()) - Stripe's
// signature verification needs the exact raw request bytes. Not behind requireAccessToken:
// Stripe doesn't have our token, so the signature check IS the auth here.
const { verifyWebhookSignature } = require('../services/billing');
const db = require('../db');

async function stripeWebhookHandler(req, res) {
  let event;
  try {
    event = verifyWebhookSignature(req.body, req.get('stripe-signature'));
  } catch (err) {
    console.error('[stripe webhook] signature verification failed:', err.message);
    return res.status(400).send(`Webhook signature verification failed`);
  }

  try {
    if (event.type === 'checkout.session.completed') {
      const isNew = await db.recordStripeEvent(event.id);
      if (isNew) {
        const session = event.data.object;
        const accountId = session.metadata?.accountId;
        const quantity = parseInt(session.metadata?.quantity || '0', 10);
        if (accountId && quantity > 0) {
          await db.addCredits(accountId, quantity);
        } else {
          console.error(`[stripe webhook] session ${session.id} missing accountId/quantity metadata`);
        }
      }
    }
    res.json({ received: true });
  } catch (err) {
    console.error('[stripe webhook] failed to process event:', err.message);
    // Non-2xx tells Stripe to retry - appropriate here since this is likely transient
    // (e.g. a DB hiccup), not a problem with the event itself.
    res.status(500).json({ error: 'Internal error processing webhook' });
  }
}

module.exports = { stripeWebhookHandler };
