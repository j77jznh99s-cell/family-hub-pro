const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');
const { writeFileAtomic, produceAtomic } = require('../src/presenter/fsutil');

function tmpdir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'atomic-test-'));
}

test('writeFileAtomic replaces the file and leaves no temp behind', async () => {
  const dir = tmpdir();
  try {
    const f = path.join(dir, 'script.json');
    await writeFileAtomic(f, '{"v":1}', 'utf8');
    await writeFileAtomic(f, '{"v":2}', 'utf8');
    assert.equal(fs.readFileSync(f, 'utf8'), '{"v":2}');
    assert.deepEqual(fs.readdirSync(dir), ['script.json']);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('a render that fails halfway leaves neither a partial output nor a temp file', async () => {
  const dir = tmpdir();
  try {
    const out = path.join(dir, 'video.captioned.mp4');
    await assert.rejects(
      produceAtomic(out, async (tmp) => {
        assert.equal(path.extname(tmp), '.mp4'); // ffmpeg picks the format from the extension
        fs.writeFileSync(tmp, 'half a video');
        throw new Error('ffmpeg killed');
      }),
      /ffmpeg killed/
    );
    assert.deepEqual(fs.readdirSync(dir), []); // nothing that would count as "captioned"
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('a failed re-render keeps the previous good output', async () => {
  const dir = tmpdir();
  try {
    const out = path.join(dir, 'video.captioned.mp4');
    await produceAtomic(out, async (tmp) => fs.writeFileSync(tmp, 'good'));
    await assert.rejects(produceAtomic(out, async () => { throw new Error('boom'); }));
    assert.equal(fs.readFileSync(out, 'utf8'), 'good');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
