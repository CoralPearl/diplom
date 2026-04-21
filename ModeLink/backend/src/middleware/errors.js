function notFoundHandler(req, res, next) {
  res.status(404).json({ error: 'NotFound', message: 'Route not found' });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const status = err.status || 500;
  const payload = {
    error: err.name || 'InternalServerError',
    message: err.message || 'Unexpected error',
  };

  // Optionally include details for validation errors
  if (err.details) payload.details = err.details;

  if (status >= 500) {
    console.error(err);
  }

  res.status(status).json(payload);
}

module.exports = { notFoundHandler, errorHandler };
