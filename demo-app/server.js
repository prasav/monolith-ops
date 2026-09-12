const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;

app.get('/', (req, res) => {
  res.json({
    service: 'monolith-ops demo',
    status: 'ok',
    project: process.env.GOOGLE_CLOUD_PROJECT || 'local',
    revision: process.env.K_REVISION || 'local',
    time: new Date().toISOString(),
  });
});

app.get('/healthz', (req, res) => res.status(200).send('ok'));

app.listen(PORT, () => console.log(`demo listening on ${PORT}`));
