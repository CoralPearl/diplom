const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const { S3Client, PutObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');

function isS3Configured() {
  return Boolean(
    process.env.S3_BUCKET &&
      process.env.S3_REGION &&
      process.env.AWS_ACCESS_KEY_ID &&
      process.env.AWS_SECRET_ACCESS_KEY
  );
}

function getS3Client() {
  return new S3Client({
    region: process.env.S3_REGION,
    credentials: {
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    },
  });
}

function safeExt(filename) {
  const ext = path.extname(filename || '').toLowerCase();
  if (!ext) return '';
  // allow common image types
  const allowed = new Set(['.jpg', '.jpeg', '.png', '.webp', '.heic']);
  return allowed.has(ext) ? ext : '';
}

async function uploadPortfolioImage({ modelId, file }) {
  // `file` from multer memoryStorage: { originalname, mimetype, buffer, size }
  const ext = safeExt(file.originalname);
  const id = crypto.randomUUID();

  const key = `portfolio/${modelId}/${id}${ext}`;

  if (isS3Configured()) {
    const client = getS3Client();
    const bucket = process.env.S3_BUCKET;

    await client.send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
        ACL: 'public-read',
      })
    );

    const baseUrl = process.env.S3_PUBLIC_BASE_URL;
    const url = baseUrl ? `${baseUrl}/${key}` : `https://${bucket}.s3.${process.env.S3_REGION}.amazonaws.com/${key}`;

    return { url, key };
  }

  // Local fallback
  const uploadsDir = path.join(__dirname, '..', '..', 'uploads');
  const localName = `${modelId}_${id}${ext || ''}`;
  const localPath = path.join(uploadsDir, localName);
  await fs.writeFile(localPath, file.buffer);

  const baseUrl = process.env.APP_BASE_URL || 'http://localhost:3000';
  const url = `${baseUrl.replace(/\/$/, '')}/uploads/${localName}`;

  return { url, key: `local:${localName}` };
}

async function deleteByKey(storageKey) {
  if (!storageKey) return;

  if (storageKey.startsWith('local:')) {
    const localName = storageKey.replace('local:', '');
    const localPath = path.join(__dirname, '..', '..', 'uploads', localName);
    try {
      await fs.unlink(localPath);
    } catch {
      // ignore
    }
    return;
  }

  if (!isS3Configured()) return;

  const client = getS3Client();
  const bucket = process.env.S3_BUCKET;
  await client.send(
    new DeleteObjectCommand({
      Bucket: bucket,
      Key: storageKey,
    })
  );
}

module.exports = { isS3Configured, uploadPortfolioImage, deleteByKey };
