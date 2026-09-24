require('dotenv').config();

const express = require('express');
const cors = require('cors');
const path = require('path');

const { PORT, STRIPE_SECRET_KEY, CLIP_ASPECT } = require('./config');
const { requireAccessToken, makePresenterAuth } = require('./middleware/auth');
const uploadRouter = require('./routes/upload');
const jobsRouter = require('./routes/jobs');
const clipsRouter = require('./routes/clips');
const statsRouter = require('./routes/stats');
const billingRouter = require('./routes/billing');
const { presenterRouter } = require('./routes/presenter');
const { stripeWebhookHandler } = require('./routes/stripeWebhook');
const ffmpeg = require('./services/ffmpeg');
const db = require('./db');

const app = express();

app.use(cors());

// Must come before express.json() - Stripe's signature check needs the raw request body.
// Not behind requireAccessToken: Stripe doesn't have our token, the signature is the auth.
if (STRIPE_SECRET_KEY) {
  app.post(
    '/api/billing/webhook',
    express.raw({ type: 'application/json' }),
    stripeWebhookHandler
  );
}

app.use(express.json());

app.get('/healthz', (req, res) => res.json({ ok: true }));

app.use('/api/jobs/:jobId/clips', requireAccessToken, clipsRouter);
app.use('/api/jobs', requireAccessToken, jobsRouter);
app.use('/api/upload', requireAccessToken, uploadRouter);
app.use('/api/stats', requireAccessToken, statsRouter);
app.use('/api/presenter', makePresenterAuth(), presenterRouter());
if (STRIPE_SECRET_KEY) {
  app.use('/api/billing', requireAccessToken, billingRouter);
}

app.use(express.static(path.join(__dirname, '..', 'public')));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

async function start() {
  const missingBinaries = await ffmpeg.checkAvailable();
  if (missingBinaries.length > 0) {
    console.error(
      `FATAL: missing required binaries on PATH: ${missingBinaries.join(', ')}. ` +
        'Every upload will fail until these are installed (see Dockerfile/nixpacks.toml).'
    );
  }

  const recovered = await db.failStaleProcessingJobs();
  if (recovered > 0) {
    console.warn(`Marked ${recovered} job(s) left mid-processing from a prior run as failed.`);
  }

  if (CLIP_ASPECT && !ffmpeg.parseAspect(CLIP_ASPECT)) {
    console.warn(
      `[config] CLIP_ASPECT="${CLIP_ASPECT}" isn't a W:H ratio like 9:16 - ignoring it, clips will keep the source aspect ratio.`
    );
  }

  app.listen(PORT, () => {
    console.log(`Clip detection MVP listening on port ${PORT}`);
  });
}

start();
