const path = require('path');

const ROOT = path.join(__dirname, '..');

module.exports = {
  DATABASE_URL: process.env.DATABASE_URL || '',
  REDIS_URL: process.env.REDIS_URL || '',
  S3_BUCKET: process.env.S3_BUCKET || '',
  S3_REGION: process.env.S3_REGION || process.env.AWS_REGION || 'us-east-1',
  // Only needed for S3-compatible non-AWS providers (Cloudflare R2, MinIO, etc).
  S3_ENDPOINT: process.env.S3_ENDPOINT || '',
  S3_FORCE_PATH_STYLE: process.env.S3_FORCE_PATH_STYLE === 'true',
  S3_DOWNLOAD_URL_TTL_SECONDS: parseInt(process.env.S3_DOWNLOAD_URL_TTL_SECONDS || '300', 10),
  OPENAI_API_KEY: process.env.OPENAI_API_KEY || '',
  OPENAI_TRANSCRIBE_MODEL: process.env.OPENAI_TRANSCRIBE_MODEL || 'whisper-1',
  BURN_IN_CAPTIONS: process.env.BURN_IN_CAPTIONS !== 'false',
  STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY || '',
  STRIPE_WEBHOOK_SECRET: process.env.STRIPE_WEBHOOK_SECRET || '',
  STRIPE_CREDIT_PRICE_CENTS: parseInt(process.env.STRIPE_CREDIT_PRICE_CENTS || '1000', 10),
  STRIPE_SUCCESS_URL: process.env.STRIPE_SUCCESS_URL || '',
  STRIPE_CANCEL_URL: process.env.STRIPE_CANCEL_URL || '',
  UPLOAD_DIR: process.env.UPLOAD_DIR || path.join(ROOT, 'uploads'),
  CLIPS_DIR: process.env.CLIPS_DIR || path.join(ROOT, 'clips'),
  MAX_UPLOAD_MB: parseInt(process.env.MAX_UPLOAD_MB || '2048', 10),
  CLIP_COUNT: parseInt(process.env.CLIP_COUNT || '4', 10),
  MAX_CONCURRENT_JOBS: parseInt(process.env.MAX_CONCURRENT_JOBS || '1', 10),
  DELETE_SOURCE_AFTER_PROCESSING: process.env.DELETE_SOURCE_AFTER_PROCESSING !== 'false',
  UPLOAD_RATE_LIMIT_PER_HOUR: parseInt(process.env.UPLOAD_RATE_LIMIT_PER_HOUR || '20', 10),
  ACCESS_TOKEN: process.env.ACCESS_TOKEN || '',
  PORT: parseInt(process.env.PORT || '3000', 10),
};
