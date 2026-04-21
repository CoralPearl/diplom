const express = require('express');
const { z } = require('zod');

const { prisma } = require('../services/db');
const { requireAuth, requireRole } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');

const router = express.Router();

function clampInt(value, def, min, max) {
  const n = Number.parseInt(String(value ?? def), 10);
  if (Number.isNaN(n)) return def;
  return Math.min(Math.max(n, min), max);
}

function parseOrder(value) {
  const v = String(value || '').toLowerCase();
  return v === 'asc' ? 'asc' : 'desc';
}

function buildOrderBy(sortBy, order) {
  const o = parseOrder(order);

  switch (String(sortBy || 'createdAt')) {
    case 'email':
      return [{ email: o }, { createdAt: 'desc' }];
    case 'role':
      return [{ role: o }, { createdAt: 'desc' }];
    case 'createdAt':
    default:
      return [{ createdAt: o }];
  }
}

// GET /admin/users
//
// Query params:
// - q: search in email
// - page, limit
// - sortBy: createdAt | email | role
// - order: asc | desc
// - role: model|booker|manager|admin
// - blocked: true|false
router.get('/users', requireAuth(), requireRole(['admin']), async (req, res, next) => {
  try {
    const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    const page = clampInt(req.query.page, 1, 1, 10_000);
    const limit = clampInt(req.query.limit, 20, 1, 50);
    const sortBy = typeof req.query.sortBy === 'string' ? req.query.sortBy : 'createdAt';
    const order = typeof req.query.order === 'string' ? req.query.order : 'desc';

    const role = typeof req.query.role === 'string' ? req.query.role : '';
    const blocked = typeof req.query.blocked === 'string' ? req.query.blocked : '';

    const where = {
      ...(q ? { email: { contains: q, mode: 'insensitive' } } : {}),
      ...(role && ['model', 'booker', 'manager', 'admin'].includes(role) ? { role } : {}),
      ...(blocked === 'true' ? { isBlocked: true } : {}),
      ...(blocked === 'false' ? { isBlocked: false } : {}),
    };

    const total = await prisma.user.count({ where });
    const totalPages = Math.max(1, Math.ceil(total / limit));
    const skip = (page - 1) * limit;

    const users = await prisma.user.findMany({
      where,
      orderBy: buildOrderBy(sortBy, order),
      skip,
      take: limit,
      include: {
        modelProfile: { select: { id: true, fullName: true } },
      },
    });

    const items = users.map((u) => ({
      id: u.id,
      email: u.email,
      role: u.role,
      isVerified: u.isVerified,
      isBlocked: u.isBlocked,
      createdAt: u.createdAt,
      modelProfile: u.modelProfile,
    }));

    return res.json({
      items,
      page,
      limit,
      total,
      totalPages,
    });
  } catch (err) {
    return next(err);
  }
});

const patchUserSchema = z
  .object({
    role: z.enum(['model', 'booker', 'manager', 'admin']).optional(),
    isBlocked: z.boolean().optional(),
  })
  .refine((v) => v.role != null || v.isBlocked != null, {
    message: 'At least one field must be provided',
  });

// PATCH /admin/users/:id
router.patch('/users/:id', requireAuth(), requireRole(['admin']), validateBody(patchUserSchema), async (req, res, next) => {
  try {
    const id = req.params.id;

    if (req.user.id === id && req.body.isBlocked === true) {
      return res.status(400).json({ error: 'BadRequest', message: 'You cannot block yourself' });
    }

    const existing = await prisma.user.findUnique({
      where: { id },
      include: { modelProfile: { select: { id: true, fullName: true } } },
    });

    if (!existing) {
      return res.status(404).json({ error: 'NotFound', message: 'User not found' });
    }

    // Optional: prevent admin self-downgrade without a secret (to avoid lockout). Keep simple for thesis.
    const data = {};
    if (req.body.role != null) data.role = req.body.role;
    if (req.body.isBlocked != null) data.isBlocked = req.body.isBlocked;

    const updated = await prisma.user.update({
      where: { id },
      data,
      include: { modelProfile: { select: { id: true, fullName: true } } },
    });

    // Ensure model profile exists if role becomes model
    if (updated.role === 'model') {
      const profile = await prisma.modelProfile.findUnique({ where: { userId: updated.id } });
      if (!profile) {
        await prisma.modelProfile.create({
          data: { userId: updated.id, fullName: '' },
        });
      }
    }

    const final = await prisma.user.findUnique({
      where: { id: updated.id },
      include: { modelProfile: { select: { id: true, fullName: true } } },
    });

    return res.json({
      id: final.id,
      email: final.email,
      role: final.role,
      isVerified: final.isVerified,
      isBlocked: final.isBlocked,
      createdAt: final.createdAt,
      modelProfile: final.modelProfile,
    });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
