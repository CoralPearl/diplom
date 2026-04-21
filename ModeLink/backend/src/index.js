require('dotenv').config();

const { createApp } = require('./app');

const PORT = process.env.PORT || 3000;

const app = createApp();

app.listen(PORT, () => {
  console.log(`ModeLink API listening on http://localhost:${PORT}`);
});
