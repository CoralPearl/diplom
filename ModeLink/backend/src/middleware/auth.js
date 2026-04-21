const jwt = require('jsonwebtoken');
const { prisma } = require('../services/db');

function requireAuth() {
  return async (req, res, next) => {
    try {
      const header = req.headers.authorization || '';
      const [type, token] = header.split(' ');
      if (type !== 'Bearer' || !token) {
        return res.status(401).json({ error: 'Unauthorized', message: 'Missing Bearer token' });
      }

      const secret = process.env.JWT_SECRET;
      if (!secret) {
        return res.status(500).json({ error: 'ServerMisconfigured', message: 'JWT_SECRET is missing' });
      }

      const payload = jwt.verify(token, secret);
      const userId = payload.sub;
      if (!userId) {
        return res.status(401).json({ error: 'Unauthorized', message: 'Invalid token payload' });
      }

      const user = await prisma.user.findUnique({
        where: { id: userId },
        include: { modelProfile: true },
      });
      if (!user) {
        return res.status(401).json({ error: 'Unauthorized', message: 'User not found' });
      }

      if (user.isBlocked) {
        return res.status(403).json({ error: 'AccountBlocked', message: 'Account is blocked' });
      }

      req.user = {
        id: user.id,
        email: user.email,
        role: user.role,
        isVerified: user.isVerified,
        isBlocked: user.isBlocked,
        modelProfileId: user.modelProfile?.id || null,
      };

      return next();
    } catch (err) {
      return res.status(401).json({ error: 'Unauthorized', message: 'Invalid or expired token' });
    }
  };
}

function requireRole(allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized', message: 'Not authenticated' });
    }
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Forbidden', message: 'Insufficient role' });
    }
    return next();
  };
}

module.exports = { requireAuth, requireRole };
