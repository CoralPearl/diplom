function envInt(name, fallback) {
  const raw = process.env[name];
  if (raw == null || raw === '') return fallback;
  const n = Number(raw);
  return Number.isFinite(n) ? n : fallback;
}

function envStr(name, fallback = '') {
  const raw = process.env[name];
  return raw == null ? fallback : raw;
}

module.exports = { envInt, envStr };
