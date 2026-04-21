const express = require('express');
const { z } = require('zod');

const { prisma } = require('../services/db');
const { requireAuth, requireRole } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const { getIdempotencyKey, sha256, stableStringify, runIdempotent } = require('../services/idempotency');

const router = express.Router();

const createProjectSchema = z.object({
  // modelId is required only for manager/admin
  modelId: z.string().uuid().optional(),
  title: z.string().min(1),
  date: z.string().datetime(),
  location: z.string().min(1),
});

router.post(
  '/',
  requireAuth(),
  requireRole(['model', 'manager', 'admin']),
  validateBody(createProjectSchema),
  async (req, res, next) => {
    try {
      const keyOrErr = getIdempotencyKey(req);
      if (keyOrErr && typeof keyOrErr === 'object') {
        return res.status(400).json(keyOrErr);
      }
      const idemKey = keyOrErr;

      const { title, date, location } = req.body;
      let modelId = req.body.modelId;

      if (req.user.role === 'model') {
        if (!req.user.modelProfileId) {
          return res.status(400).json({ error: 'ModelProfileMissing', message: 'Model profile not found' });
        }
        modelId = req.user.modelProfileId;
      } else {
        if (!modelId) {
          return res.status(400).json({ error: 'BadRequest', message: 'modelId is required' });
        }
      }

      const scope = 'POST /projects';
      const requestHash = sha256(
        stableStringify({
          modelId,
          title,
          date,
          location,
        })
      );

      const result = await runIdempotent({
        userId: req.user.id,
        key: idemKey,
        scope,
        requestHash,
        execute: async () => {
          const project = await prisma.project.create({
            data: {
              modelId,
              title,
              date: new Date(date),
              location,
            },
          });
          return { status: 201, body: project };
        },
      });

      return res.status(result.status).json(result.body);
    } catch (err) {
      return next(err);
    }
  }
);

router.get('/', requireAuth(), requireRole(['model', 'manager', 'admin']), async (req, res, next) => {
  try {
    const { modelId } = req.query;

    if (req.user.role === 'model') {
      if (!req.user.modelProfileId) {
        return res.status(400).json({ error: 'ModelProfileMissing', message: 'Model profile not found' });
      }
      const projects = await prisma.project.findMany({
        where: { modelId: req.user.modelProfileId },
        orderBy: { date: 'desc' },
      });
      return res.json(projects);
    }

    const where = {};
    if (typeof modelId === 'string' && modelId) {
      where.modelId = modelId;
    }

    const projects = await prisma.project.findMany({
      where,
      orderBy: { date: 'desc' },
    });

    return res.json(projects);
  } catch (err) {
    return next(err);
  }
});

const updateProjectSchema = z.object({
  title: z.string().min(1).optional(),
  date: z.string().datetime().optional(),
  location: z.string().min(1).optional(),
});

router.put(
  '/:id',
  requireAuth(),
  requireRole(['model', 'manager', 'admin']),
  validateBody(updateProjectSchema),
  async (req, res, next) => {
    try {
      const id = req.params.id;

      const project = await prisma.project.findUnique({
        where: { id },
        include: { model: { select: { userId: true } } },
      });

      if (!project) {
        return res.status(404).json({ error: 'NotFound', message: 'Project not found' });
      }

      if (req.user.role === 'model' && project.model.userId !== req.user.id) {
        return res.status(403).json({ error: 'Forbidden', message: 'Cannot edit чужой проект' });
      }

      const data = {};
      if (req.body.title != null) data.title = req.body.title;
      if (req.body.location != null) data.location = req.body.location;
      if (req.body.date != null) data.date = new Date(req.body.date);

      const updated = await prisma.project.update({
        where: { id },
        data,
      });

      return res.json(updated);
    } catch (err) {
      return next(err);
    }
  }
);

router.delete(
  '/:id',
  requireAuth(),
  requireRole(['model', 'manager', 'admin']),
  async (req, res, next) => {
    try {
      const id = req.params.id;

      const project = await prisma.project.findUnique({
        where: { id },
        include: { model: { select: { userId: true } } },
      });

      if (!project) {
        return res.status(404).json({ error: 'NotFound', message: 'Project not found' });
      }

      if (req.user.role === 'model' && project.model.userId !== req.user.id) {
        return res.status(403).json({ error: 'Forbidden', message: 'Cannot delete чужой проект' });
      }

      await prisma.project.delete({ where: { id } });

      return res.json({ ok: true });
    } catch (err) {
      return next(err);
    }
  }
);

module.exports = router;
