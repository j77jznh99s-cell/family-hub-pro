const express = require('express');
const db = require('../db');

const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    res.json(await db.getStats());
  } catch (err) {
    next(err);
  }
});

module.exports = router;
