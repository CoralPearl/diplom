const sgMail = require('@sendgrid/mail');

function isSendgridConfigured() {
  return Boolean(process.env.SENDGRID_API_KEY && process.env.SENDGRID_FROM_EMAIL);
}

async function sendOtpEmail({ to, code }) {
  const from = process.env.SENDGRID_FROM_EMAIL;

  if (!isSendgridConfigured()) {
    // DEV fallback: log code
    console.log(`[DEV] OTP for ${to}: ${code}`);
    return;
  }

  sgMail.setApiKey(process.env.SENDGRID_API_KEY);

  const msg = {
    to,
    from,
    subject: 'ModeLink — код подтверждения',
    text: `Ваш код подтверждения: ${code}. Код действителен ограниченное время.`,
  };

  await sgMail.send(msg);
}

module.exports = { sendOtpEmail, isSendgridConfigured };
