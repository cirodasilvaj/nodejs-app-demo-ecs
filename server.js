const http = require('node:http');
const os = require('node:os');
const { execSync } = require('node:child_process');

const PORT = Number(process.env.PORT || 8080);
const APP_NAME = process.env.APP_NAME || 'bkstg-made-nodejs-demo22';
const FLUENTD_HOST = process.env.FLUENTD_HOST || 'fluentd.logging.svc.cluster.local';
const FLUENTD_PORT = process.env.FLUENTD_PORT || '24224';
const START_TIME = Date.now();

const metricsCounters = {
  '/': 0,
  '/api/info': 0,
  '/healthz': 0,
  '/metrics': 0,
};

function getUname() {
  try {
    return execSync('uname -a', { encoding: 'utf-8', timeout: 1000 }).trim();
  } catch {
    return `${os.type()} ${os.hostname()} ${os.release()} ${os.version()} ${os.arch()}`;
  }
}

function getServerIps() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const net of interfaces[name] || []) {
      if (net.family === 'IPv4' && !net.internal) {
        addresses.push(net.address);
      }
    }
  }
  return addresses.length > 0 ? addresses.join(', ') : '127.0.0.1';
}

function getRequestOrigin(req) {
  return (
    req.headers['origin'] ||
    req.headers['referer'] ||
    req.headers['x-forwarded-host'] ||
    req.headers['host'] ||
    'direct'
  );
}

function getClientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim().length > 0) {
    return forwarded.split(',')[0].trim();
  }
  const realIp = req.headers['x-real-ip'];
  if (typeof realIp === 'string' && realIp.trim().length > 0) {
    return realIp.trim();
  }
  return req.socket?.remoteAddress || 'unknown';
}

function emitFluentdLog(event, path, clientIp) {
  const record = {
    time: new Date().toISOString(),
    app: APP_NAME,
    language: `Node.js ${process.version}`,
    event,
    path,
    client_ip: clientIp,
    hostname: os.hostname(),
    fluentd_target: `${FLUENTD_HOST}:${FLUENTD_PORT}`,
  };
  process.stdout.write(`${JSON.stringify(record)}\n`);
}

function buildPayload(req) {
  const clientIp = getClientIp(req);
  const serverIp = getServerIps();
  const hostname = os.hostname();
  const requestOrigin = getRequestOrigin(req);
  const language = `Node.js ${process.version} (V8 ${process.versions.v8})`;
  const uname = getUname();
  const uptime = ((Date.now() - START_TIME) / 1000).toFixed(2);

  return {
    message: 'Hello World from Backstage Versao manual555 !',
    service: APP_NAME,
    ip: serverIp,
    server_ip: serverIp,
    client_ip: clientIp,
    hostname,
    request_origin: requestOrigin,
    language,
    uname,
    platform: `${os.platform()} (${os.arch()})`,
    uptime_seconds: Number(uptime),
    timestamp: new Date().toISOString(),
  };
}

function createServer() {
  return http.createServer((req, res) => {
    const urlPath = (req.url || '/').split('?')[0];
    const clientIp = getClientIp(req);

    if (urlPath === '/healthz') {
      metricsCounters['/healthz'] += 1;
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', language: `Node.js ${process.version}`, hostname: os.hostname() }));
      return;
    }

    if (urlPath === '/metrics') {
      metricsCounters['/metrics'] += 1;
      const uptime = ((Date.now() - START_TIME) / 1000).toFixed(2);
      const lines = [
        '# HELP app_http_requests_total Total HTTP requests handled by the application',
        '# TYPE app_http_requests_total counter',
        `app_http_requests_total{app="${APP_NAME}",language="NodeJS",endpoint="/"} ${metricsCounters['/']}`,
        `app_http_requests_total{app="${APP_NAME}",language="NodeJS",endpoint="/api/info"} ${metricsCounters['/api/info']}`,
        `app_http_requests_total{app="${APP_NAME}",language="NodeJS",endpoint="/healthz"} ${metricsCounters['/healthz']}`,
        `app_http_requests_total{app="${APP_NAME}",language="NodeJS",endpoint="/metrics"} ${metricsCounters['/metrics']}`,
        '# HELP app_uptime_seconds Application uptime in seconds',
        '# TYPE app_uptime_seconds gauge',
        `app_uptime_seconds{app="${APP_NAME}",language="NodeJS"} ${uptime}`,
        '',
      ];
      res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' });
      res.end(lines.join('\n'));
      return;
    }

    if (urlPath === '/api/info' || urlPath === '/json') {
      metricsCounters['/api/info'] += 1;
      emitFluentdLog('api_info_request', urlPath, clientIp);
      const data = buildPayload(req);
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(data, null, 2));
      return;
    }

    if (urlPath === '/') {
      metricsCounters['/'] += 1;
      emitFluentdLog('index_request', urlPath, clientIp);
      const data = buildPayload(req);

      const acceptHeader = req.headers['accept'] || '';
      if (acceptHeader.includes('application/json')) {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify(data, null, 2));
        return;
      }

      // Render friendly HTML page
      const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Hello World FURADO  TESTE444 - ${data.service}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #0f172a; color: #f8fafc; padding: 2rem; margin: 0; }
    .card { max-width: 720px; margin: 0 auto; background: #1e293b; border-radius: 12px; padding: 2rem; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }
    h1 { color: #38bdf8; margin-top: 0; font-size: 1.8rem; }
    .tag { display: inline-block; background: #0369a1; color: #fff; padding: 0.25rem 0.75rem; border-radius: 9999px; font-size: 0.85rem; font-weight: 600; margin-bottom: 1.5rem; }
    table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
    th, td { text-align: left; padding: 0.75rem 0.5rem; border-bottom: 1px solid #334155; }
    th { color: #94a3b8; width: 35%; font-weight: 500; }
    td { color: #f1f5f9; font-family: 'JetBrains Mono', monospace; word-break: break-all; }
    .footer { margin-top: 1.5rem; display: flex; gap: 1rem; }
    .footer a { color: #38bdf8; text-decoration: none; font-size: 0.9rem; background: #0f172a; padding: 0.5rem 1rem; border-radius: 6px; border: 1px solid #334155; }
    .footer a:hover { background: #38bdf8; color: #0f172a; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🚀 ${data.message}</h1>
    <div class="tag">Backstage Developer Portal Microservice</div>
    <table>
      <tr><th>🌍 IP do Servidor (ip):</th><td>${data.server_ip}</td></tr>
      <tr><th>👤 IP do Cliente:</th><td>${data.client_ip}</td></tr>
      <tr><th>🖥️ Nome do Host (hostname):</th><td>${data.hostname}</td></tr>
      <tr><th>📡 Origem da Requisição:</th><td>${data.request_origin}</td></tr>
      <tr><th>⚡ Linguagem:</th><td>${data.language}</td></tr>
      <tr><th>🐧 Uname (SO / Kernel):</th><td>${data.uname}</td></tr>
      <tr><th>📦 Plataforma:</th><td>${data.platform}</td></tr>
      <tr><th>⏱️ Uptime:</th><td>${data.uptime_seconds}s</td></tr>
      <tr><th>🕒 Timestamp (UTC):</th><td>${data.timestamp}</td></tr>
    </table>
    <div class="footer">
      <a href="/api/info" target="_blank">📄 JSON API (/api/info)</a>
      <a href="/healthz" target="_blank">🩺 Health (/healthz)</a>
      <a href="/metrics" target="_blank">📊 Prometheus (/metrics)</a>
    </div>
  </div>
</body>
</html>`;
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(html);
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not Found' }));
  });
}

if (require.main === module) {
  const server = createServer();
  server.listen(PORT, '0.0.0.0', () => {
    emitFluentdLog('server_started', '/', '127.0.0.1');
    console.log(`Server listening on port ${PORT} (http://0.0.0.0:${PORT})`);
  });
}

module.exports = { createServer, getUname, getServerIps, getRequestOrigin, getClientIp };
