const express = require('express');
const multer = require('multer');
const { z } = require('zod');

const { prisma } = require('../services/db');
const { requireAuth, requireRole } = require('../middleware/auth');
const { uploadPortfolioImage, deleteByKey } = require('../services/storage');
const { getIdempotencyKey, sha256, stableStringify, runIdempotent } = require('../services/idempotency');

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
  fileFilter: (req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      return cb(new Error('Only image files are allowed'));
    }
    cb(null, true);
  },
});

const postPortfolioSchema = z.object({
  modelId: z.string().uuid().optional(),
});

router.post(
  '/',
  requireAuth(),
  requireRole(['model', 'manager', 'admin']),
  upload.single('image'),
  async (req, res, next) => {
    try {
      const keyOrErr = getIdempotencyKey(req);
      if (keyOrErr && typeof keyOrErr === 'object') {
        return res.status(400).json(keyOrErr);
      }
      const idemKey = keyOrErr;

      // Validate non-file fields
      const parsed = postPortfolioSchema.safeParse(req.body || {});
      if (!parsed.success) {
        return res.status(400).json({ error: 'BadRequest', message: 'Validation error', details: parsed.error.issues });
      }

      if (!req.file) {
        return res.status(400).json({ error: 'BadRequest', message: 'Missing image file (field name: image)' });
      }

      let modelId = parsed.data.modelId;

      if (req.user.role === 'model') {
        if (!req.user.modelProfileId) {
          return res.status(400).json({ error: 'ModelProfileMissing', message: 'Model profile not found' });
        }
        modelId = req.user.modelProfileId;
      } else {
        if (!modelId) {
          return res.status(400).json({ error: 'BadRequest', message: 'modelId is required for manager/admin' });
        }
      }

      const count = await prisma.portfolioImage.count({ where: { modelId } });
      if (count >= 10) {
        return res.status(400).json({ error: 'LimitExceeded', message: 'Max 10 portfolio images per model' });
      }

      const scope = 'POST /portfolio';
      const fileHash = sha256(req.file.buffer);
      const requestHash = sha256(
        stableStringify({
          modelId,
          file: {
            size: req.file.size,
            mimetype: req.file.mimetype,
            originalname: req.file.originalname,
            sha256: fileHash,
          },
        })
      );

      const result = await runIdempotent({
        userId: req.user.id,
        key: idemKey,
        scope,
        requestHash,
        execute: async () => {
          const { url, key } = await uploadPortfolioImage({ modelId, file: req.file });

          const image = await prisma.portfolioImage.create({
            data: {
              modelId,
              imageUrl: url,
              storageKey: key,
            },
          });

          return { status: 201, body: image };
        },
      });

      return res.status(result.status).json(result.body);
    } catch (err) {
      return next(err);
    }
  }
);

router.get('/', requireAuth(), requireRole(['model', 'booker', 'manager', 'admin']), async (req, res, next) => {
  try {
    const { modelId } = req.query;

    if (req.user.role === 'model') {
      if (!req.user.modelProfileId) {
        return res.status(400).json({ error: 'ModelProfileMissing', message: 'Model profile not found' });
      }
      const images = await prisma.portfolioImage.findMany({
        where: { modelId: req.user.modelProfileId },
        orderBy: { createdAt: 'desc' },
      });
      return res.json(images);
    }

    if (typeof modelId !== 'string' || !modelId) {
      return res.status(400).json({ error: 'BadRequest', message: 'modelId query param is required' });
    }

    const images = await prisma.portfolioImage.findMany({
      where: { modelId },
      orderBy: { createdAt: 'desc' },
    });

    return res.json(images);
  } catch (err) {
    return next(err);
  }
});

router.delete(
  '/:id',
  requireAuth(),
  requireRole(['model', 'manager', 'admin']),
  async (req, res, next) => {
    try {
      const id = req.params.id;

      const image = await prisma.portfolioImage.findUnique({
        where: { id },
        include: { model: { select: { userId: true } } },
      });

      if (!image) {
        return res.status(404).json({ error: 'NotFound', message: 'Portfolio image not found' });
      }

      if (req.user.role === 'model' && image.model.userId !== req.user.id) {
        return res.status(403).json({ error: 'Forbidden', message: 'Cannot delete чужое фото' });
      }

      await deleteByKey(image.storageKey);
      await prisma.portfolioImage.delete({ where: { id } });

      return res.json({ ok: true });
    } catch (err) {
      return next(err);
    }
  }
);

module.exports = router;
