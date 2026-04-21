const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { prisma } = require('./db');
const { envInt } = require('../utils/env');

function generate6DigitCode() {
  // crypto-random int between 0..999999 and pad
  const n = crypto.randomInt(0, 1000000);
  return String(n).padStart(6, '0');
}

async function canSendOtp({ email, purpose }) {
  const cooldownSeconds = envInt('OTP_RESEND_COOLDOWN_SECONDS', 60);
  if (cooldownSeconds <= 0) return true;

  const latest = await prisma.emailOtp.findFirst({
    where: { email, purpose },
    orderBy: { createdAt: 'desc' },
  });

  if (!latest) return true;

  const diffMs = Date.now() - latest.createdAt.getTime();
  return diffMs >= cooldownSeconds * 1000;
}

async function createOtp({ email, purpose }) {
  const ttlMinutes = envInt('OTP_TTL_MINUTES', 10);
  const attempts = envInt('OTP_ATTEMPTS', 5);

  const code = generate6DigitCode();
  const codeHash = await bcrypt.hash(code, 10);

  const expiresAt = new Date(Date.now() + ttlMinutes * 60 * 1000);

  await prisma.emailOtp.create({
    data: {
      email,
      purpose,
      codeHash,
      expiresAt,
      attemptsLeft: attempts,
    },
  });

  return { code, expiresAt };
}

async function verifyOtp({ email, purpose, code }) {
  // Find latest active OTP
  const otp = await prisma.emailOtp.findFirst({
    where: {
      email,
      purpose,
      consumedAt: null,
      expiresAt: { gt: new Date() },
      attemptsLeft: { gt: 0 },
    },
    orderBy: { createdAt: 'desc' },
  });

  if (!otp) {
    return { ok: false, reason: 'not_found_or_expired' };
  }

  const match = await bcrypt.compare(code, otp.codeHash);

  if (!match) {
    await prisma.emailOtp.update({
      where: { id: otp.id },
      data: { attemptsLeft: otp.attemptsLeft - 1 },
    });
    return { ok: false, reason: 'invalid_code' };
  }

  await prisma.emailOtp.update({
    where: { id: otp.id },
    data: { consumedAt: new Date() },
  });

  return { ok: true };
}

module.exports = { generate6DigitCode, canSendOtp, createOtp, verifyOtp };
