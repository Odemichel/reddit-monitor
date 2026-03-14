const https = require('https');

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    const makeRequest = (requestUrl) => {
      https.get(requestUrl, {
        headers: {
          'User-Agent': 'AeroXBot/1.0 (by /u/aerox-befaster)',
        },
      }, (response) => {
        if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
          makeRequest(response.headers.location);
          return;
        }
        let body = '';
        response.on('data', (chunk) => { body += chunk; });
        response.on('end', () => resolve(body));
      }).on('error', reject);
    };
    makeRequest(url);
  });
}

// Parse Atom XML entries without external dependencies
function parseAtomEntries(xml) {
  const entries = [];
  const entryRegex = /<entry>([\s\S]*?)<\/entry>/g;
  let match;

  while ((match = entryRegex.exec(xml)) !== null) {
    const entry = match[1];
    const get = (tag) => {
      const m = entry.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`));
      return m ? m[1].replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"') : '';
    };
    const getAttr = (tag, attr) => {
      const m = entry.match(new RegExp(`<${tag}[^>]*${attr}="([^"]*)"[^>]*/>`))
        || entry.match(new RegExp(`<${tag}[^>]*${attr}="([^"]*)"[^>]*>`));
      return m ? m[1].replace(/&amp;/g, '&') : '';
    };

    const id = get('id');
    const title = get('title');
    const content = get('content');
    const published = get('published');
    const authorName = get('name');
    const link = getAttr('link', 'href');
    const category = getAttr('category', 'term');

    // Extract selftext from HTML content
    const selftextMatch = content.match(/<!-- SC_OFF --><div class="md">([\s\S]*?)<\/div><!-- SC_ON -->/);
    let selftext = '';
    if (selftextMatch) {
      selftext = selftextMatch[1]
        .replace(/<[^>]+>/g, ' ')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#32;/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    }

    // Extract permalink from link
    const permalink = link.replace('https://www.reddit.com', '');

    entries.push({
      kind: 't3',
      data: {
        id: id.replace('t3_', ''),
        title: title,
        subreddit: category,
        selftext: selftext,
        author: authorName.replace('/u/', ''),
        score: 0, // RSS doesn't include score
        num_comments: 0, // RSS doesn't include comment count
        created_utc: Math.floor(new Date(published).getTime() / 1000),
        permalink: permalink,
        url: link,
      }
    });
  }

  return entries;
}

// Parse Atom XML for comments on a post
function parseCommentEntries(xml) {
  const entries = [];
  const entryRegex = /<entry>([\s\S]*?)<\/entry>/g;
  let match;

  while ((match = entryRegex.exec(xml)) !== null) {
    const entry = match[1];
    const get = (tag) => {
      const m = entry.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`));
      return m ? m[1].replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"') : '';
    };

    const id = get('id');
    const content = get('content');
    const published = get('published');
    const authorName = get('name');

    const body = content
      .replace(/<[^>]+>/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#32;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    entries.push({
      kind: 't1',
      data: {
        id: id.replace('t1_', ''),
        author: authorName.replace('/u/', ''),
        body: body,
        score: 2, // RSS doesn't include score, default to passing filter
        created_utc: Math.floor(new Date(published).getTime() / 1000),
      }
    });
  }

  return entries;
}

module.exports = async function handler(req, res) {
  const { url } = req.query;

  if (!url) {
    res.status(400).json({ error: 'Missing url parameter' });
    return;
  }

  const decodedUrl = decodeURIComponent(url);

  if (!decodedUrl.startsWith('https://www.reddit.com/')) {
    res.status(403).json({ error: 'Only Reddit URLs are allowed' });
    return;
  }

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  try {
    // Convert .json URL to .rss
    const rssUrl = decodedUrl.replace(/\.json(\?|$)/, '.rss$1');
    const xml = await fetchUrl(rssUrl);

    if (xml.includes('<entry>') === false && xml.includes('<feed') === false) {
      throw new Error('Reddit returned non-RSS response');
    }

    // Detect if this is a comments page (URL contains /comments/)
    const isCommentsPage = decodedUrl.includes('/comments/');

    if (isCommentsPage) {
      // For comment pages, return as array [postListing, commentsListing]
      const comments = parseCommentEntries(xml);
      // Skip first entry (it's the post itself)
      const commentEntries = comments.length > 1 ? comments.slice(1) : [];
      res.json([
        { data: { children: comments.length > 0 ? [comments[0]] : [] } },
        { data: { children: commentEntries } }
      ]);
    } else {
      // For search/listing pages, return standard Reddit listing format
      const entries = parseAtomEntries(xml);
      res.json({
        data: {
          children: entries,
          after: null,
          dist: entries.length,
        }
      });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
