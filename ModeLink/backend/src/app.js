const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const swaggerUi = require('swagger-ui-express');

// OpenAPI документ лежит в корне проекта
// eslint-disable-next-line import/no-dynamic-require, global-require
const openapiDocument = require('../openapi.json');

const { errorHandler, notFoundHandler } = require('./middleware/errors');
const authRoutes = require('./routes/auth');
const modelProfileRoutes = require('./routes/modelProfile');
const projectRoutes = require('./routes/projects');
const portfolioRoutes = require('./routes/portfolio');
const modelRoutes = require('./routes/models');
const adminRoutes = require('./routes/admin');

function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '2mb' }));
  app.use(morgan('dev'));

  // Static for local uploads
  app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

  app.get('/health', (req, res) => {
    res.json({ ok: true, name: 'modelink-backend', time: new Date().toISOString() });
  });

  // API docs
  app.get('/openapi.json', (req, res) => res.json(openapiDocument));
  app.use('/docs', swaggerUi.serve, swaggerUi.setup(openapiDocument, { explorer: true }));

  app.use('/auth', authRoutes);
  app.use('/model-profile', modelProfileRoutes);
  app.use('/projects', projectRoutes);
  app.use('/portfolio', portfolioRoutes);
  app.use('/models', modelRoutes);
  app.use('/admin', adminRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
