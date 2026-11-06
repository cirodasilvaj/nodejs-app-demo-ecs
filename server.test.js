const assert = require('node:assert/strict');
const { createServer } = require('./server');

const testCase = typeof test === 'function' ? test : require('node:test');

testCase('Node.js microservice exposes Hello World with IP, Hostname, Request Origin, Language, and Uname', async () => {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();

  try {
    // 1. Health check
    const healthRes = await fetch(`http://127.0.0.1:${port}/healthz`);
    assert.equal(healthRes.status, 200);
    const healthJson = await healthRes.json();
    assert.equal(healthJson.status, 'ok');

    // 2. /api/info (JSON endpoint with all required attributes)
    const infoRes = await fetch(`http://127.0.0.1:${port}/api/info`, {
      headers: {
        'X-Forwarded-For': '203.0.113.195',
        'Origin': 'https://backstage.realhandsonlabs.net',
      },
    });
    assert.equal(infoRes.status, 200);
    const infoJson = await infoRes.json();
    assert.match(infoJson.message, /Hello World/);
    assert.ok(infoJson.ip, 'IP should be defined');
    assert.ok(infoJson.hostname, 'Hostname should be defined');
    assert.equal(infoJson.client_ip, '203.0.113.195');
    assert.equal(infoJson.request_origin, 'https://backstage.realhandsonlabs.net');
    assert.match(infoJson.language, /Node\.js/);
    assert.ok(infoJson.uname, 'Uname should be defined');

    // 3. / (Root endpoint accepting JSON)
    const rootJsonRes = await fetch(`http://127.0.0.1:${port}/`, {
      headers: { 'Accept': 'application/json' },
    });
    assert.equal(rootJsonRes.status, 200);
    const rootJson = await rootJsonRes.json();
    assert.ok(rootJson.hostname);
    assert.ok(rootJson.uname);

    // 4. / (Root endpoint accepting HTML)
    const rootHtmlRes = await fetch(`http://127.0.0.1:${port}/`);
    assert.equal(rootHtmlRes.status, 200);
    const rootHtml = await rootHtmlRes.text();
    assert.match(rootHtml, /Hello World/);
    assert.match(rootHtml, /Nome do Host/);

    // 5. Prometheus /metrics
    const metricsRes = await fetch(`http://127.0.0.1:${port}/metrics`);
    assert.equal(metricsRes.status, 200);
    const metricsText = await metricsRes.text();
    assert.match(metricsText, /app_http_requests_total/);
  } finally {
    server.close();
  }
});
