import http from 'node:http';

const PORT = 8888;

const server = http.createServer(async (req, res) => {
  const parsed = new URL(req.url, `http://localhost:${PORT}`);
  const targetUrl = parsed.searchParams.get('url');

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (!targetUrl) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Missing url parameter' }));
    return;
  }

  try {
    const response = await fetch(targetUrl, {
      headers: { 'User-Agent': 'AeroXMonitor/1.0 (personal dashboard)' },
    });
    const data = await response.text();
    res.writeHead(response.status, { 'Content-Type': 'application/json' });
    res.end(data);
  } catch (e) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: e.message }));
  }
});

server.listen(PORT, () => {
  console.log(`CORS proxy running on http://localhost:${PORT}`);
});
