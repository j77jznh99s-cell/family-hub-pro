const express = require('express');
const { OUTPUT_DIR } = require('../presenter');
const runs = require('../presenter/runs');
const calendar = require('../presenter/calendar');

// Read-only view of presenter runs for the dashboard. Nothing here posts or publishes.
function presenterRouter(outputDir = OUTPUT_DIR) {
  const router = express.Router();

  router.get('/runs', async (req, res, next) => {
    try {
      res.json(await runs.listRuns(outputDir));
    } catch (err) {
      next(err);
    }
  });

  router.get('/runs/:id', async (req, res, next) => {
    try {
      const run = await runs.getRun(outputDir, req.params.id);
      if (!run) return res.status(404).json({ error: 'Run not found' });
      res.json(run);
    } catch (err) {
      next(err);
    }
  });

  router.get('/runs/:id/video', async (req, res, next) => {
    try {
      const file = await runs.videoPath(outputDir, req.params.id);
      if (!file) return res.status(404).json({ error: 'No video for this run' });
      res.sendFile(file); // handles Range requests, so the <video> element can seek
    } catch (err) {
      next(err);
    }
  });

  router.get('/calendar', async (req, res, next) => {
    try {
      const slots = calendar.planWeek({ days: 7, perDay: 1, times: process.env.PRESENTER_POST_TIMES });
      res.json(await calendar.attachRuns(slots, outputDir));
    } catch (err) {
      next(err);
    }
  });

  return router;
}

module.exports = { presenterRouter };
