// Crash-safe writes: write a temp file in the same folder, then rename over the target.
// A crash, a killed process or a full disk leaves the previous file (or no file) - never a
// half-written one that the calendar, --check or the dashboard would take as finished.
const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');

function tempPathFor(file) {
  const ext = path.extname(file); // keep the extension so tools like ffmpeg pick the format
  return path.join(path.dirname(file), `.${path.basename(file, ext)}.${crypto.randomBytes(4).toString('hex')}.tmp${ext}`);
}

async function writeFileAtomic(file, data, encoding) {
  const tmp = tempPathFor(file);
  try {
    await fs.writeFile(tmp, data, encoding);
    await fs.rename(tmp, file);
  } catch (err) {
    await fs.rm(tmp, { force: true });
    throw err;
  }
  return file;
}

// Let `produce(tmpPath)` create the file (e.g. an ffmpeg run), then move it into place.
async function produceAtomic(file, produce) {
  const tmp = tempPathFor(file);
  try {
    await produce(tmp);
    await fs.rename(tmp, file);
  } catch (err) {
    await fs.rm(tmp, { force: true });
    throw err;
  }
  return file;
}

module.exports = { writeFileAtomic, produceAtomic, tempPathFor };
