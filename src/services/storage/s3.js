// Used instead of storage/local.js whenever S3_BUCKET is set. ffmpeg still writes clips
// and thumbnails to local scratch space (it can't operate on S3 objects directly) - this
// module uploads that output to S3 as the durable copy and removes the local scratch
// file, so what survives a redeploy (or serves from any instance) lives in the bucket.
const fs = require('fs');
const {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
} = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const {
  S3_BUCKET,
  S3_REGION,
  S3_ENDPOINT,
  S3_FORCE_PATH_STYLE,
  S3_DOWNLOAD_URL_TTL_SECONDS,
} = require('../../config');

const client = new S3Client({
  region: S3_REGION,
  endpoint: S3_ENDPOINT || undefined,
  forcePathStyle: S3_FORCE_PATH_STYLE || undefined,
});

async function store(localPath, key) {
  const body = fs.createReadStream(localPath);
  await client.send(
    new PutObjectCommand({
      Bucket: S3_BUCKET,
      Key: key,
      Body: body,
      ContentType: key.endsWith('.jpg') ? 'image/jpeg' : 'video/mp4',
    })
  );
  await fs.promises.rm(localPath, { force: true });
  return key;
}

async function getServeInfo(key, { downloadFilename } = {}) {
  const command = new GetObjectCommand({
    Bucket: S3_BUCKET,
    Key: key,
    ResponseContentDisposition: downloadFilename
      ? `attachment; filename="${downloadFilename}"`
      : undefined,
  });
  const url = await getSignedUrl(client, command, { expiresIn: S3_DOWNLOAD_URL_TTL_SECONDS });
  return { type: 'redirect', url };
}

module.exports = { store, getServeInfo, client };
