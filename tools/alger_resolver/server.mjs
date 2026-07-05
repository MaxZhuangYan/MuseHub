import http from 'node:http';
import match from '@unblockneteasemusic/server';

const DEFAULT_PORT = 30489;
const DEFAULT_HOST = '127.0.0.1';
const ALL_PLATFORMS = ['migu', 'kugou', 'kuwo', 'pyncmd'];

const port = Number.parseInt(process.env.PORT || `${DEFAULT_PORT}`, 10);
const host = process.env.HOST || DEFAULT_HOST;

function ensureSongData(data = {}) {
  const artists = Array.isArray(data.artists)
    ? data.artists
    : Array.isArray(data.ar)
      ? data.ar
      : [];
  const album = data.album && typeof data.album === 'object'
    ? data.album
    : data.al && typeof data.al === 'object'
      ? data.al
      : { name: '' };

  return {
    ...data,
    name: data.name || '',
    artists: artists.map((artist) => ({ name: artist?.name || '' })),
    album: { name: album.name || '' },
  };
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    request.on('data', (chunk) => chunks.push(chunk));
    request.on('end', () => {
      const body = Buffer.concat(chunks).toString('utf8');
      if (!body) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch (error) {
        reject(error);
      }
    });
    request.on('error', reject);
  });
}

function sendJson(response, statusCode, data) {
  const body = JSON.stringify(data);
  response.writeHead(statusCode, {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
    'access-control-allow-headers': 'content-type',
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
  });
  response.end(body);
}

async function resolveMusic(body) {
  const id = Number.parseInt(`${body.id || body.songId || ''}`, 10);
  if (!Number.isFinite(id)) {
    return { code: 400, message: 'Missing song id' };
  }

  const enabledSources = Array.isArray(body.enabledSources)
    ? body.enabledSources.filter((source) => ALL_PLATFORMS.includes(source))
    : ALL_PLATFORMS;
  const songData = ensureSongData(body.songData || body.data || {});
  const data = await match(id, enabledSources, songData);

  return {
    code: 200,
    message: 'success',
    data: {
      data,
      params: { id, type: 'song' },
    },
  };
}

const server = http.createServer(async (request, response) => {
  if (request.method === 'OPTIONS') {
    sendJson(response, 204, {});
    return;
  }

  const url = new URL(request.url || '/', `http://${request.headers.host}`);
  if (request.method === 'GET' && url.pathname === '/health') {
    sendJson(response, 200, { ok: true, sources: ALL_PLATFORMS });
    return;
  }

  if (request.method === 'POST' && url.pathname === '/unblock-music') {
    try {
      const body = await readJson(request);
      const result = await resolveMusic(body);
      sendJson(response, result.code === 200 ? 200 : 400, result);
    } catch (error) {
      sendJson(response, 502, {
        code: 502,
        message: error instanceof Error ? error.message : 'Resolver failed',
      });
    }
    return;
  }

  sendJson(response, 404, { code: 404, message: 'Not found' });
});

server.listen(port, host, () => {
  console.log(`MuseHub Alger resolver listening at http://${host}:${port}`);
});
