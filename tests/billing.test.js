// createCheckoutSession is tested against a mocked Stripe API call (no network).
// verifyWebhookSignature is tested against Stripe's own offline signature generator -
// this exercises the real HMAC verification logic, just without a live API key.
const { test } = require('node:test');
const assert = require('node:assert/strict');

process.env.STRIPE_SECRET_KEY = 'sk_test_fake';
process.env.STRIPE_WEBHOOK_SECRET = 'whsec_test_fake';
process.env.STRIPE_CREDIT_PRICE_CENTS = '1000';

const Stripe = require('stripe');
const billing = require('../src/services/billing');

test('createCheckoutSession sends the right line item and metadata', async (t) => {
  // Stripe's session.create is an instance method built from a shared prototype -
  // mocking it there intercepts calls from any Stripe client instance, including the
  // one billing.js constructs internally.
  const probeInstance = new Stripe('sk_test_fake');
  const sessionsCreateMock = t.mock.method(
    Object.getPrototypeOf(probeInstance.checkout.sessions),
    'create',
    async (params) => ({
      id: 'cs_test_123',
      url: 'https://checkout.stripe.com/pay/cs_test_123',
      ...params,
    })
  );

  const session = await billing.createCheckoutSession({
    accountId: 'acct-1',
    quantity: 3,
    successUrl: 'https://app.example/success',
    cancelUrl: 'https://app.example/cancel',
  });

  assert.equal(sessionsCreateMock.mock.calls.length, 1);
  const callArgs = sessionsCreateMock.mock.calls[0].arguments[0];
  assert.equal(callArgs.line_items[0].price_data.unit_amount, 1000);
  assert.equal(callArgs.line_items[0].quantity, 3);
  assert.equal(callArgs.metadata.accountId, 'acct-1');
  assert.equal(callArgs.metadata.quantity, '3');
  assert.equal(callArgs.success_url, 'https://app.example/success');
  assert.match(session.url, /^https:\/\/checkout\.stripe\.com/);
});

test('verifyWebhookSignature accepts a correctly signed payload', () => {
  const payload = JSON.stringify({ id: 'evt_1', type: 'checkout.session.completed' });
  const header = Stripe.webhooks.generateTestHeaderString({
    payload,
    secret: 'whsec_test_fake',
  });

  const event = billing.verifyWebhookSignature(Buffer.from(payload), header);
  assert.equal(event.id, 'evt_1');
  assert.equal(event.type, 'checkout.session.completed');
});

test('verifyWebhookSignature rejects a tampered payload', () => {
  const payload = JSON.stringify({ id: 'evt_1' });
  const header = Stripe.webhooks.generateTestHeaderString({
    payload,
    secret: 'whsec_test_fake',
  });

  const tamperedPayload = JSON.stringify({ id: 'evt_1_hacked' });
  assert.throws(() => billing.verifyWebhookSignature(Buffer.from(tamperedPayload), header));
});

test('verifyWebhookSignature rejects a signature made with the wrong secret', () => {
  const payload = JSON.stringify({ id: 'evt_1' });
  const header = Stripe.webhooks.generateTestHeaderString({
    payload,
    secret: 'whsec_totally_different',
  });

  assert.throws(() => billing.verifyWebhookSignature(Buffer.from(payload), header));
});
