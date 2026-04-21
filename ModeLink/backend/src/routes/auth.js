const express = require('express');
const bcrypt = require('bcryptjs');
const { z } = require('zod');

const { prisma } = require('../services/db');
const { validateBody } = require('../middleware/validate');
const { sendOtpEmail } = require('../services/email');
const { canSendOtp, createOtp, verifyOtp } = require('../services/otp');
const { signAccessToken } = require('../services/jwt');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

const requestOtpSchema = z.object({
  email: z.string().email().transform((v) => v.toLowerCase()),
  purpose: z.literal('register').default('register'),
});

router.post('/otp/request', validateBody(requestOtpSchema), async (req, res, next) => {
  try {
    const { email, purpose } = req.body;

    // If user already exists and verified, you may want to return generic OK (anti-enumeration)
    // Here we return 409 for clarity in a thesis demo.
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing?.isVerified) {
      return res.status(409).json({ error: 'UserAlreadyExists', message: 'User with this email already exists' });
    }

    const allowed = await canSendOtp({ email, purpose });
    if (!allowed) {
      return res.status(429).json({ error: 'TooManyRequests', message: 'OTP resend cooldown. Try later.' });
    }

    const { code, expiresAt } = await createOtp({ email, purpose });

    await sendOtpEmail({ to: email, code });

    return res.json({ ok: true, expiresAt });
  } catch (err) {
    return next(err);
  }
});

const verifyOtpSchema = z.object({
  email: z.string().email().transform((v) => v.toLowerCase()),
  purpose: z.literal('register').default('register'),
  code: z.string().regex(/^\d{6}$/, 'Code must be 6 digits'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  role: z.enum(['model', 'booker', 'manager', 'admin']),
  adminRegistrationSecret: z.string().optional(),
});

router.post('/otp/verify', validateBody(verifyOtpSchema), async (req, res, next) => {
  try {
    const { email, purpose, code, password, role, adminRegistrationSecret } = req.body;

    // Safety: block self-registration as admin unless explicitly enabled.
    if (role === 'admin') {
      const allow = String(process.env.ALLOW_ADMIN_REGISTRATION || '').toLowerCase() === 'true';
      const secret = process.env.ADMIN_REGISTRATION_SECRET;
      const okBySecret = secret && adminRegistrationSecret && secret === adminRegistrationSecret;
      if (!allow && !okBySecret) {
        return res.status(403).json({
          error: 'Forbidden',
          message: 'Admin self-registration is disabled',
        });
      }
    }

    const result = await verifyOtp({ email, purpose, code });
    if (!result.ok) {
      return res.status(400).json({
        error: 'InvalidOtp',
        message: result.reason === 'invalid_code' ? 'Invalid code' : 'OTP not found or expired',
      });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    // create or update user
    let user = await prisma.user.findUnique({ where: { email } });

    if (!user) {
      user = await prisma.user.create({
        data: {
          email,
          passwordHash,
          role,
          isVerified: true,
        },
      });
    } else {
      user = await prisma.user.update({
        where: { id: user.id },
        data: {
          passwordHash,
          role,
          isVerified: true,
        },
      });
    }

    // Ensure model profile exists for role=model
    if (user.role === 'model') {
      const existingProfile = await prisma.modelProfile.findUnique({ where: { userId: user.id } });
      if (!existingProfile) {
        await prisma.modelProfile.create({
          data: {
            userId: user.id,
            fullName: '',
          },
        });
      }
    }

    const token = signAccessToken(user);

    return res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        isVerified: user.isVerified,
      },
    });
  } catch (err) {
    return next(err);
  }
});

const loginSchema = z.object({
  email: z.string().email().transform((v) => v.toLowerCase()),
  password: z.string().min(1),
});

router.post('/login', validateBody(loginSchema), async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !user.isVerified) {
      return res.status(401).json({ error: 'Unauthorized', message: 'Invalid credentials' });
    }

    if (user.isBlocked) {
      return res.status(403).json({ error: 'AccountBlocked', message: 'Account is blocked' });
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      return res.status(401).json({ error: 'Unauthorized', message: 'Invalid credentials' });
    }

    const token = signAccessToken(user);

    return res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        isVerified: user.isVerified,
      },
    });
  } catch (err) {
    return next(err);
  }
});

router.get('/me', requireAuth(), async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      include: { modelProfile: true },
    });

    if (!user) {
      return res.status(404).json({ error: 'NotFound', message: 'User not found' });
    }

    return res.json({
      id: user.id,
      email: user.email,
      role: user.role,
      isVerified: user.isVerified,
      modelProfile: user.modelProfile,
    });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
