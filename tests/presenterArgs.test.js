const { test } = require('node:test');
const assert = require('node:assert/strict');

const { parseArgs, parseCount } = require('../src/presenter/args');
const { MAX_DAYS, MAX_PER_DAY } = require('../src/presenter/calendar');

test('parseArgs keeps the defaults when --days / --per-day are absent', () => {
  const args = parseArgs(['--calendar']);
  assert.equal(args.calendar, true);
  assert.equal(args.days, undefined);
  assert.equal(args.perDay, undefined);
  assert.equal(args.niche, 'auto');
  assert.equal(args.render, true);
});

test('parseArgs accepts valid --days and --per-day', () => {
  assert.deepEqual(
    parseArgs(['--calendar', '--days', '7', '--per-day', '2', '--times', '12:00,18:00']),
    { niche: 'auto', render: true, calendar: true, days: 7, perDay: 2, times: '12:00,18:00' }
  );
  assert.equal(parseArgs(['--fill-week', '--days', '1']).days, 1);
  assert.equal(parseArgs(['--days', String(MAX_DAYS)]).days, MAX_DAYS);
  assert.equal(parseArgs(['--per-day', String(MAX_PER_DAY)]).perDay, MAX_PER_DAY);
});

test('parseArgs rejects bad --days instead of falling back to the default', () => {
  for (const bad of ['0', '-1', 'abc', '2.5', '3x', '', String(MAX_DAYS + 1), '100000']) {
    assert.throws(() => parseArgs(['--calendar', '--days', bad]), /--days must be a whole number from 1 to 31/, bad);
  }
  assert.throws(() => parseArgs(['--calendar', '--days']), /--days must be a whole number/); // value missing
});

test('parseArgs rejects bad --per-day instead of falling back to the default', () => {
  for (const bad of ['0', 'abc', '1.5', String(MAX_PER_DAY + 1)]) {
    assert.throws(() => parseArgs(['--fill-week', '--per-day', bad]), /--per-day must be a whole number from 1 to 6/, bad);
  }
});

test('parseCount names the bad value in its error', () => {
  assert.throws(() => parseCount('--days', 'abc', { max: 31 }), /got "abc"/);
  assert.equal(parseCount('--days', ' 5 ', { max: 31 }), 5);
});

test('parseArgs still rejects unknown arguments', () => {
  assert.throws(() => parseArgs(['--dayz', '3']), /Unknown argument: --dayz/);
});
