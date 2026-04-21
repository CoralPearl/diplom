const crypto = require('crypto');

const { prisma } = require('./db');

function sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

// Stable stringify for simple JSON bodies.
// Good enough for our DTOs (no deep nesting).
function stableStringify(obj) {
  if (obj == null) return 'null';
  if (typeof obj !== 'object') return JSON.stringify(obj);
  if (Array.isArray(obj)) return `[${obj.map(stableStringify).join(',')}]`;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(obj[k])}`).join(',')}}`;
}

function getIdempotencyKey(req) {
  const key = req.get('Idempotency-Key');
  if (!key) return null;
  const trimmed = String(key).trim();
  if (trimmed.length < 8 || trimmed.length > 128) {
    return { error: 'BadRequest', message: 'Idempotency-Key must be 8..128 chars' };
  }
  return trimmed;
}

function jsonSafe(value) {
  // Convert Dates, BigInt, etc. to JSON-safe values.
  return JSON.parse(JSON.stringify(value));
}

/**
 * Runs an operation under an idempotency key.
 *
 * The route handler should NOT write to res directly.
 * Instead it should return { status, body }.
 */
async function runIdempotent({
  userId,
  key,
  scope,
  requestHash,
  execute,
}) {
  if (!key) {
    const result = await execute();
    return result;
  }

  // 1) Lookup existing record
  const existing = await prisma.idempotencyRecord.findUnique({
    where: {
      userId_key_scope: {
        userId,
        key,
        scope,
      },
    },
  });

  if (existing) {
    if (existing.requestHash !== requestHash) {
      return {
        status: 409,
        body: {
          error: 'IdempotencyKeyReuse',
          message: 'Idempotency-Key was already used with a different request payload',
        },
      };
    }

    if (existing.responseStatus != null && existing.responseBody != null) {
      return {
        status: existing.responseStatus,
        body: existing.responseBody,
        replay: true,
      };
    }

    // Request is in progress (race / duplicate concurrent call)
    return {
      status: 409,
      body: {
        error: 'IdempotencyInProgress',
        message: 'Request with this Idempotency-Key is still in progress. Retry later.',
      },
      replay: true,
    };
  }

  // 2) Create record (guard against races)
  try {
    await prisma.idempotencyRecord.create({
      data: {
        userId,
        key,
        scope,
        requestHash,
        status: 'IN_PROGRESS',
      },
    });
  } catch (e) {
    // Unique conflict: someone created it in parallel → fetch and replay
    const again = await prisma.idempotencyRecord.findUnique({
      where: {
        userId_key_scope: {
          userId,
          key,
          scope,
        },
      },
    });
    if (again && again.responseStatus != null && again.responseBody != null) {
      return { status: again.responseStatus, body: again.responseBody, replay: true };
    }
    return {
      status: 409,
      body: {
        error: 'IdempotencyInProgress',
        message: 'Request with this Idempotency-Key is still in progress. Retry later.',
      },
      replay: true,
    };
  }

  // 3) Execute and persist response
  try {
    const result = await execute();
    const safeBody = jsonSafe(result.body);

    await prisma.idempotencyRecord.update({
      where: {
        userId_key_scope: {
          userId,
          key,
          scope,
        },
      },
      data: {
        status: 'COMPLETED',
        responseStatus: result.status,
        responseBody: safeBody,
      },
    });

    return { ...result, body: safeBody };
  } catch (err) {
    // Persist known HTTP-shaped errors (4xx)
    if (err && typeof err === 'object' && err.status && err.body) {
      const safeBody = jsonSafe(err.body);
      await prisma.idempotencyRecord.update({
        where: {
          userId_key_scope: {
            userId,
            key,
            scope,
          },
        },
        data: {
          status: 'COMPLETED',
          responseStatus: err.status,
          responseBody: safeBody,
        },
      });
      return { status: err.status, body: safeBody };
    }

    // Unknown error → mark FAILED and rethrow.
    await prisma.idempotencyRecord.update({
      where: {
        userId_key_scope: {
          userId,
          key,
          scope,
        },
      },
      data: {
        status: 'FAILED',
        responseStatus: 500,
        responseBody: { error: 'InternalError', message: 'Internal server error' },
      },
    });
    throw err;
  }
}

module.exports = {
  sha256,
  stableStringify,
  getIdempotencyKey,
  runIdempotent,
};
