const express = require('express');
const { z } = require('zod');

const { prisma } = require('../services/db');
const { requireAuth, requireRole } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');

const router = express.Router();

router.get('/me', requireAuth(), requireRole(['model']), async (req, res, next) => {
  try {
    const profile = await prisma.modelProfile.findUnique({
      where: { userId: req.user.id },
    });

    if (!profile) {
      return res.status(404).json({ error: 'NotFound', message: 'Model profile not found' });
    }

    return res.json(profile);
  } catch (err) {
    return next(err);
  }
});

const updateSchema = z.object({
  fullName: z.string().min(1).optional(),
  height: z.number().int().min(50).max(250).optional(),
  weight: z.number().int().min(20).max(250).optional(),
  bust: z.number().int().min(40).max(200).optional(),
  waist: z.number().int().min(40).max(200).optional(),
  hips: z.number().int().min(40).max(250).optional(),
  shoeSize: z.number().min(20).max(60).optional(),
});

router.put('/', requireAuth(), requireRole(['model']), validateBody(updateSchema), async (req, res, next) => {
  try {
    const profile = await prisma.modelProfile.findUnique({ where: { userId: req.user.id } });
    if (!profile) {
      return res.status(404).json({ error: 'NotFound', message: 'Model profile not found' });
    }

    const updated = await prisma.modelProfile.update({
      where: { id: profile.id },
      data: req.body,
    });

    return res.json(updated);
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
