const jwt = require('jsonwebtoken');

function signAccessToken(user) {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    const err = new Error('JWT_SECRET is missing');
    err.status = 500;
    throw err;
  }

  const expiresIn = process.env.JWT_EXPIRES_IN || '7d';

  // `sub` — стандартное поле JWT (subject)
  return jwt.sign(
    {
      role: user.role,
    },
    secret,
    {
      subject: user.id,
      expiresIn,
    }
  );
}

module.exports = { signAccessToken };
