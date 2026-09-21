// Dispatches to postgres.js when DATABASE_URL is set, sqlite.js otherwise. Both drivers
// export the same async function names, so nothing outside src/db needs to know which
// one is active.
const { DATABASE_URL } = require('../config');

module.exports = DATABASE_URL ? require('./postgres') : require('./sqlite');
