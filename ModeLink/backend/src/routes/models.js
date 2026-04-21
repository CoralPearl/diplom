const express = require('express');

const { prisma } = require('../services/db');
const { requireAuth, requireRole } = require('../middleware/auth');

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
    case 'fullName':
      return [{ fullName: o }, { createdAt: 'desc' }];
    case 'updatedAt':
      return [{ updatedAt: o }, { createdAt: 'desc' }];
    case 'portfolioCount':
      return [{ portfolioImages: { _count: o } }, { createdAt: 'desc' }];
    case 'projectsCount':
      return [{ projects: { _count: o } }, { createdAt: 'desc' }];
    case 'createdAt':
    default:
      return [{ createdAt: o }];
  }
}

// List models (for booker/manager/admin) with search + pagination + sorting
//
// Query params:
// - q: search in fullName or userEmail
// - page: 1..
// - limit: 1..50
// - sortBy: createdAt | updatedAt | fullName | portfolioCount | projectsCount
// - order: asc | desc
router.get('/', requireAuth(), requireRole(['booker', 'manager', 'admin']), async (req, res, next) => {
  try {
    const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    const page = clampInt(req.query.page, 1, 1, 10_000);
    const limit = clampInt(req.query.limit, 20, 1, 50);
    const sortBy = typeof req.query.sortBy === 'string' ? req.query.sortBy : 'createdAt';
    const order = typeof req.query.order === 'string' ? req.query.order : 'desc';

    // Show only active model users
    const where = {
      user: {
        role: 'model',
        isBlocked: false,
        isVerified: true,
      },
      ...(q
        ? {
            OR: [
              { fullName: { contains: q, mode: 'insensitive' } },
              { user: { email: { contains: q, mode: 'insensitive' } } },
            ],
          }
        : {}),
    };

    const total = await prisma.modelProfile.count({ where });
    const totalPages = Math.max(1, Math.ceil(total / limit));
    const skip = (page - 1) * limit;

    const models = await prisma.modelProfile.findMany({
      where,
      orderBy: buildOrderBy(sortBy, order),
      skip,
      take: limit,
      include: {
        user: { select: { email: true } },
        _count: { select: { portfolioImages: true, projects: true } },
      },
    });

    const items = models.map((m) => ({
      id: m.id,
      userEmail: m.user.email,
      fullName: m.fullName,
      height: m.height,
      weight: m.weight,
      bust: m.bust,
      waist: m.waist,
      hips: m.hips,
      shoeSize: m.shoeSize,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
      portfolioCount: m._count.portfolioImages,
      projectsCount: m._count.projects,
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

// Get one model profile
router.get('/:id', requireAuth(), requireRole(['booker', 'manager', 'admin']), async (req, res, next) => {
  try {
    const id = req.params.id;

    const model = await prisma.modelProfile.findFirst({
      where: {
        id,
        user: {
          role: 'model',
          isBlocked: false,
          isVerified: true,
        },
      },
      include: {
        user: { select: { email: true } },
        portfolioImages: { orderBy: { createdAt: 'desc' } },
        projects: { orderBy: { date: 'desc' } },
      },
    });

    if (!model) {
      return res.status(404).json({ error: 'NotFound', message: 'Model not found' });
    }

    return res.json({
      id: model.id,
      userEmail: model.user.email,
      fullName: model.fullName,
      height: model.height,
      weight: model.weight,
      bust: model.bust,
      waist: model.waist,
      hips: model.hips,
      shoeSize: model.shoeSize,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      portfolioImages: model.portfolioImages,
      projects: model.projects,
    });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
