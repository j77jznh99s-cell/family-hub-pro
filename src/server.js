require('dotenv').config();

const express = require('express');
const cors = require('cors');
const path = require('path');

const { PORT } = require('./config');
const { requireAccessToken } = require('./middleware/auth');
const uploadRouter = require('./routes/upload');
const jobsRouter = require('./routes/jobs');
const clipsRouter = require('./routes/clips');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/healthz', (req, res) => res.json({ ok: true }));

app.use('/api/jobs/:jobId/clips', requireAccessToken, clipsRouter);
app.use('/api/jobs', requireAccessToken, jobsRouter);
app.use('/api/upload', requireAccessToken, uploadRouter);

app.use(express.static(path.join(__dirname, '..', 'public')));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Clip detection MVP listening on port ${PORT}`);
});
