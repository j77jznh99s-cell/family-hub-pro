// storage/local.js is exercised implicitly by the app's default config (no S3_BUCKET),
// so this focuses on storage/s3.js, which needs mocked AWS calls since there's no live
// bucket in CI. Verifies the driver sends the right S3 commands and cleans up the local
// scratch file - not whether AWS itself works.
const { test, mock } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

process.env.S3_BUCKET = 'test-bucket';
process.env.S3_REGION = 'us-east-1';

const { S3Client } = require('@aws-sdk/client-s3');
const presigner = require('@aws-sdk/s3-request-presigner');

test('store() uploads to S3 with the given key and removes the local scratch file', async (t) => {
  const sendMock = t.mock.method(S3Client.prototype, 'send', async (command) => {
    assert.equal(command.input.Bucket, 'test-bucket');
    assert.equal(command.input.Key, 'job1/clip1.mp4');
    return {};
  });

  const s3 = require('../src/services/storage/s3');

  const tmpFile = path.join(os.tmpdir(), `storage-test-${Date.now()}.mp4`);
  fs.writeFileSync(tmpFile, 'fake video bytes');

  const key = await s3.store(tmpFile, 'job1/clip1.mp4');

  assert.equal(key, 'job1/clip1.mp4');
  assert.equal(sendMock.mock.calls.length, 1);
  assert.equal(fs.existsSync(tmpFile), false); // local scratch copy is gone
});

test('getServeInfo() returns a redirect with a presigned URL', async (t) => {
  t.mock.method(presigner, 'getSignedUrl', async (client, command) => {
    assert.equal(command.input.Bucket, 'test-bucket');
    assert.equal(command.input.Key, 'job1/clip1.mp4');
    return 'https://example-bucket.s3.amazonaws.com/job1/clip1.mp4?signed=1';
  });

  const s3 = require('../src/services/storage/s3');
  const info = await s3.getServeInfo('job1/clip1.mp4', { downloadFilename: 'My Clip.mp4' });

  assert.equal(info.type, 'redirect');
  assert.match(info.url, /^https:\/\//);
});
