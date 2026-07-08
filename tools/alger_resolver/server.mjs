import http from 'node:http';
import https from 'node:https';
import match from '@unblockneteasemusic/server';

const DEFAULT_PORT = 30489;
const DEFAULT_HOST = '0.0.0.0';
const DEFAULT_NETEASE_API = 'https://music.163.com/api';
const ALL_PLATFORMS = ['pyncmd', 'kugou', 'kuwo', 'migu', 'qq', 'bilibili'];
const SOURCE_PRIORITY = ['pyncmd', 'kugou', 'kuwo', 'migu', 'qq', 'bilibili'];
const MIN_AUDIO_BYTES = Number.parseInt(process.env.MIN_AUDIO_BYTES || `${512 * 1024}`, 10);
const MAX_CANDIDATES = Number.parseInt(process.env.MAX_CANDIDATES || '6', 10);
const neteaseApiBaseUrl = (process.env.NETEASE_API || DEFAULT_NETEASE_API).replace(/\/+$/, '');

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

function normalizeSources(sources) {
  const allowed = new Set(
    Array.isArray(sources)
      ? sources.filter((source) => ALL_PLATFORMS.includes(source))
      : ALL_PLATFORMS,
  );
  return SOURCE_PRIORITY.filter((source) => allowed.has(source));
}

function requestHead(url, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 4) {
      reject(new Error('Too many redirects'));
      return;
    }

    const parsedUrl = new URL(url);
    const client = parsedUrl.protocol === 'https:' ? https : http;
    const request = client.request(
      parsedUrl,
      {
        method: 'HEAD',
        timeout: 8000,
        headers: {
          'accept': '*/*',
          'user-agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0 Safari/537.36',
        },
      },
      (response) => {
        const location = response.headers.location;
        if (
          location &&
          [301, 302, 303, 307, 308].includes(response.statusCode || 0)
        ) {
          response.resume();
          resolve(requestHead(new URL(location, parsedUrl).toString(), redirectCount + 1));
          return;
        }
        response.resume();
        resolve({
          statusCode: response.statusCode || 0,
          contentLength: Number.parseInt(`${response.headers['content-length'] || 0}`, 10),
          contentType: `${response.headers['content-type'] || ''}`,
        });
      },
    );
    request.on('timeout', () => request.destroy(new Error('HEAD timeout')));
    request.on('error', reject);
    request.end();
  });
}

function requestRangeProbe(url, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 4) {
      reject(new Error('Too many redirects'));
      return;
    }

    const parsedUrl = new URL(url);
    const client = parsedUrl.protocol === 'https:' ? https : http;
    const request = client.request(
      parsedUrl,
      {
        method: 'GET',
        timeout: 8000,
        headers: {
          'accept': '*/*',
          'range': 'bytes=0-0',
          'user-agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0 Safari/537.36',
        },
      },
      (response) => {
        const location = response.headers.location;
        if (
          location &&
          [301, 302, 303, 307, 308].includes(response.statusCode || 0)
        ) {
          response.resume();
          resolve(requestRangeProbe(new URL(location, parsedUrl).toString(), redirectCount + 1));
          return;
        }
        response.resume();
        resolve({
          statusCode: response.statusCode || 0,
          contentLength: Number.parseInt(`${response.headers['content-length'] || 0}`, 10),
          contentType: `${response.headers['content-type'] || ''}`,
        });
      },
    );
    request.on('timeout', () => request.destroy(new Error('range probe timeout')));
    request.on('error', reject);
    request.end();
  });
}

function getJson(url, redirectCount = 0) {
  return new Promise((resolve, reject) => {
    if (redirectCount > 4) {
      reject(new Error('Too many redirects'));
      return;
    }

    const parsedUrl = new URL(url);
    const client = parsedUrl.protocol === 'https:' ? https : http;
    const request = client.get(
      parsedUrl,
      {
        timeout: 10000,
        headers: {
          'accept': 'application/json, text/plain, */*',
          'user-agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0 Safari/537.36',
        },
      },
      (response) => {
        const location = response.headers.location;
        if (
          location &&
          [301, 302, 303, 307, 308].includes(response.statusCode || 0)
        ) {
          response.resume();
          resolve(getJson(new URL(location, parsedUrl).toString(), redirectCount + 1));
          return;
        }

        const chunks = [];
        response.on('data', (chunk) => chunks.push(chunk));
        response.on('end', () => {
          try {
            resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
          } catch (error) {
            reject(error);
          }
        });
      },
    );
    request.on('timeout', () => request.destroy(new Error('GET timeout')));
    request.on('error', reject);
  });
}

async function isUsableAudio(data) {
  if (!data?.url || typeof data.url !== 'string') {
    return { ok: false, reason: 'missing url' };
  }

  const declaredSize = Number.parseInt(`${data.size || 0}`, 10);
  if (declaredSize > 0 && declaredSize < MIN_AUDIO_BYTES) {
    return {
      ok: false,
      reason: `declared audio too small: ${declaredSize} bytes`,
    };
  }
  if (declaredSize >= MIN_AUDIO_BYTES) {
    return { ok: true };
  }

  try {
    const head = await requestHead(data.url);
    const validation = validateAudioProbe(head);
    if (validation.ok) return validation;
  } catch (_) {
    // Some music CDNs reject HEAD; fall through to a byte-range probe.
  }

  try {
    const probe = await requestRangeProbe(data.url);
    const validation = validateAudioProbe(probe);
    if (!validation.ok) return validation;
    return { ok: true };
  } catch (error) {
    return {
      ok: false,
      reason: error instanceof Error ? error.message : 'audio probe failed',
    };
  }
}

function validateAudioProbe(probe) {
  if (probe.statusCode < 200 || probe.statusCode >= 300) {
    return { ok: false, reason: `bad status: ${probe.statusCode}` };
  }
  const contentType = `${probe.contentType || ''}`.toLowerCase();
  if (
    contentType.includes('json') ||
    contentType.includes('text/html') ||
    contentType.startsWith('text/plain')
  ) {
    return { ok: false, reason: `not audio: ${probe.contentType}` };
  }
  if (probe.contentLength > 0 && probe.contentLength < MIN_AUDIO_BYTES) {
    return {
      ok: false,
      reason: `remote audio too small: ${probe.contentLength} bytes`,
    };
  }
  if (contentType) {
    const likelyAudio =
      contentType.startsWith('audio/') ||
      contentType.includes('octet-stream') ||
      contentType.includes('mpegurl') ||
      contentType.includes('mp4') ||
      contentType.includes('flac');
    if (!likelyAudio) {
      return { ok: false, reason: `not audio: ${probe.contentType}` };
    }
  }
  return { ok: true };
}

function artistText(songData) {
  return (songData.artists || [])
    .map((artist) => artist?.name || '')
    .filter(Boolean)
    .join(' ');
}

async function searchCandidates(id, songData) {
  const keywords = `${songData.name || ''} ${artistText(songData)}`.trim();
  if (!keywords) return [];

  const url = new URL(`${neteaseApiBaseUrl}/search/get`);
  url.searchParams.set('s', keywords);
  url.searchParams.set('type', '1');
  url.searchParams.set('limit', '10');
  url.searchParams.set('timestamp', `${Date.now()}`);

  try {
    const data = await getJson(url.toString());
    const songs = data?.result?.songs;
    if (!Array.isArray(songs)) return [];
    return songs
      .map((song) => ({
        id: Number.parseInt(`${song.id || 0}`, 10),
        name: song.name || songData.name || '',
        artists: Array.isArray(song.ar)
          ? song.ar.map((artist) => ({ name: artist?.name || '' }))
          : songData.artists,
        album: { name: song.al?.name || songData.album?.name || '' },
      }))
      .filter((song) => Number.isFinite(song.id) && song.id !== id)
      .slice(0, MAX_CANDIDATES);
  } catch (error) {
    return [];
  }
}

async function resolveBySources(id, songData, enabledSources) {
  const failures = [];

  for (const source of enabledSources) {
    try {
      const candidate = await match(id, [source], songData);
      const validation = await isUsableAudio(candidate);
      if (validation.ok) {
        return { data: candidate, failures };
      }
      failures.push({ source, reason: validation.reason, data: candidate });
    } catch (error) {
      failures.push({
        source,
        reason: error instanceof Error ? error.message : `${error}`,
      });
    }
  }

  return { data: null, failures };
}

async function resolveMusic(body) {
  const id = Number.parseInt(`${body.id || body.songId || ''}`, 10);
  if (!Number.isFinite(id)) {
    return { code: 400, message: 'Missing song id' };
  }

  const enabledSources = normalizeSources(body.enabledSources);
  const songData = ensureSongData(body.songData || body.data || {});
  const primary = await resolveBySources(id, songData, enabledSources);
  let data = primary.data;
  const failures = [{ songId: id, attempts: primary.failures }];

  if (!data) {
    const candidates = await searchCandidates(id, songData);
    for (const candidateSong of candidates) {
      const candidate = await resolveBySources(candidateSong.id, candidateSong, enabledSources);
      failures.push({ songId: candidateSong.id, attempts: candidate.failures });
      if (candidate.data) {
        data = { ...candidate.data, resolvedSongId: candidateSong.id };
        break;
      }
    }
  }

  if (!data) {
    return {
      code: 404,
      message: 'No usable audio source found',
      failures,
    };
  }

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
  if (request.method === 'GET' && (url.pathname === '/' || url.pathname === '/health')) {
    sendJson(response, 200, {
      ok: true,
      name: 'MuseHub Alger resolver',
      endpoints: ['GET /health', 'POST /unblock-music'],
      sources: SOURCE_PRIORITY,
      minAudioBytes: MIN_AUDIO_BYTES,
      maxCandidates: MAX_CANDIDATES,
      neteaseApiBaseUrl,
    });
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
