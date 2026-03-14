export default async function handler(req, res) {
  const { url } = req.query;

  if (!url) {
    res.status(400).json({ error: 'Missing url parameter' });
    return;
  }

  const decodedUrl = decodeURIComponent(url);

  // Only allow Reddit URLs
  if (!decodedUrl.startsWith('https://www.reddit.com/')) {
    res.status(403).json({ error: 'Only Reddit URLs are allowed' });
    return;
  }

  try {
    const response = await fetch(decodedUrl, {
      headers: {
        'User-Agent': 'AeroXMonitor/1.0 (personal dashboard)',
      },
    });

    const data = await response.json();

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET');
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch from Reddit' });
  }
}
