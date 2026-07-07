import { serve } from '@hono/node-server';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import type { Context, MiddlewareHandler } from 'hono';
import {
  createSessionToken,
  hashPassword,
  isValidEmail,
  isValidPassword,
  normalizeEmail,
  verifyPassword,
} from './auth.js';
import { openDatabase } from './db.js';
import { Repository } from './repository.js';
import { AlgerSource } from './sources/alger.js';
import { LocalSource } from './sources/local.js';
import { MockNeteaseSource } from './sources/mock-netease.js';
import { NeteaseSource } from './sources/netease.js';
import { SourceRegistry } from './sources/registry.js';
import { proxyStream } from './stream.js';
import {
  HttpError,
  StreamError,
  type PublicUser,
  type TrackCandidate,
  type User,
} from './types.js';

const port = Number(process.env.PORT ?? 30490);
const dbPath = process.env.DB_PATH ?? './data/musehub.sqlite';
const musicDir = process.env.MUSIC_DIR ?? '/music';
const compatibleNeteaseApiBaseUrl =
  process.env.NETEASE_API_BASE ??
  'https://netease-cloud-music-api-five-roan-88.vercel.app';
const directNeteaseApiBaseUrl =
  process.env.NETEASE_DIRECT_API_BASE ?? 'https://music.163.com/api';
const sourceRequestTimeoutMs = Number(process.env.SOURCE_REQUEST_TIMEOUT_MS ?? 8000);
const algerResolverBaseUrl =
  process.env.ALGER_RESOLVER_URL ?? process.env.RESOLVER_BASE_URL ?? '';
const sessionTtlDays = 30;

const db = openDatabase(dbPath);
const repo = new Repository(db);
const sources = new SourceRegistry();
sources.register(new MockNeteaseSource());
if (process.env.NETEASE_SOURCE_ENABLED !== 'false') {
  sources.register(
    new NeteaseSource({
      compatibleApiBaseUrl: compatibleNeteaseApiBaseUrl,
      directApiBaseUrl: directNeteaseApiBaseUrl,
      timeoutMs: sourceRequestTimeoutMs,
    }),
  );
}
if (algerResolverBaseUrl) {
  sources.register(
    new AlgerSource({
      resolverBaseUrl: algerResolverBaseUrl,
      compatibleApiBaseUrl: compatibleNeteaseApiBaseUrl,
      directApiBaseUrl: directNeteaseApiBaseUrl,
      timeoutMs: Number(process.env.ALGER_RESOLVER_TIMEOUT_MS ?? 45000),
    }),
  );
}
sources.register(new LocalSource(musicDir));

type AppEnv = {
  Variables: {
    user: User;
    token: string;
  };
};

const app = new Hono<AppEnv>();
app.use('*', cors());
app.onError((error, c) => {
  if (error instanceof HttpError) {
    return c.json({ error: error.message }, error.status);
  }
  console.error(error);
  return c.json({ error: 'Internal server error' }, 500);
});

const requireAuth: MiddlewareHandler<AppEnv> = async (c, next) => {
  const token = bearerToken(c.req.header('authorization'));
  if (!token) return c.json({ error: 'Authentication required' }, 401);
  const user = repo.getSessionUser(token);
  if (!user) return c.json({ error: 'Invalid or expired session' }, 401);
  c.set('user', user);
  c.set('token', token);
  await next();
};

app.get('/health', (c) => {
  return c.json({
    ok: true,
    name: 'MuseHub Server V0',
    port,
    dbPath,
    musicDir,
    sources: sources.all().map((source) => ({
      id: source.id,
      capabilities: source.capabilities,
    })),
  });
});

app.get('/search', async (c) => {
  const query = c.req.query('q') ?? '';
  const results = await Promise.all(
    sources.searchable().map(async (source) => {
      try {
        return await source.search(query);
      } catch (error) {
        console.warn(`Source search failed: ${source.id}`, error);
        return [];
      }
    }),
  );
  return c.json({ results: results.flat().map(toPublicCandidate) });
});

app.post('/auth/register', async (c) => {
  const body = await readJson<{
    email?: string;
    password?: string;
    displayName?: string | null;
  }>(c);
  const email = normalizeEmail(body.email ?? '');
  const password = body.password ?? '';
  if (!isValidEmail(email)) return c.json({ error: 'valid email is required' }, 400);
  if (!isValidPassword(password)) {
    return c.json({ error: 'password must be 8 to 256 characters' }, 400);
  }
  if (repo.getUserByEmail(email)) return c.json({ error: 'email already registered' }, 409);

  const user = repo.createUser({
    email,
    passwordHash: await hashPassword(password),
    displayName: body.displayName?.trim() || null,
  });
  const token = issueSession(user.id);
  return c.json({ user: toPublicUser(user), token }, 201);
});

app.post('/auth/login', async (c) => {
  const body = await readJson<{ email?: string; password?: string }>(c);
  const email = normalizeEmail(body.email ?? '');
  const password = body.password ?? '';
  const user = repo.getUserByEmail(email);
  if (!user || !(await verifyPassword(password, user.passwordHash))) {
    return c.json({ error: 'invalid email or password' }, 401);
  }
  const token = issueSession(user.id);
  return c.json({ user: toPublicUser(user), token });
});

app.post('/auth/logout', requireAuth, (c) => {
  repo.deleteSession(c.get('token'));
  return c.json({ ok: true });
});

app.get('/me', requireAuth, (c) => {
  return c.json({ user: toPublicUser(c.get('user')) });
});

app.post('/tracks/resolve', requireAuth, async (c) => {
  const candidate = await readJson<TrackCandidate>(c);
  const error = validateCandidate(candidate);
  if (error) return c.json({ error }, 400);
  const result = repo.resolveTrack(candidate);
  return c.json(result, result.created ? 201 : 200);
});

app.get('/track/:id', requireAuth, (c) => {
  const track = repo.getTrack(c.req.param('id'));
  if (!track) return c.json({ error: 'Track not found' }, 404);
  return c.json(track);
});

app.get('/stream/:id', requireAuth, async (c) => {
  const bindings = repo.getPlayableBindings(c.req.param('id'));
  if (bindings.length === 0) return c.json({ error: 'No playable binding found' }, 404);

  let lastError: { message: string; status: 400 | 404 | 502 } | null = null;
  for (const binding of bindings) {
    const source = sources.get(binding.sourceInstanceId);
    if (!source) {
      lastError = { message: 'Source not registered', status: 502 };
      continue;
    }
    const candidate = repo.getBindingCandidate(binding);
    if (!candidate) return c.json({ error: 'Track not found' }, 404);
    try {
      const handle = await source.getStream(candidate);
      return proxyStream(c, handle);
    } catch (error) {
      if (error instanceof StreamError) {
        lastError = { message: error.message, status: error.status };
      } else {
        console.error(error);
        lastError = { message: 'Stream unavailable', status: 502 };
      }
    }
  }

  return c.json(
    { error: lastError?.message ?? 'No playable source available' },
    lastError?.status ?? 502,
  );
});

app.get('/playlists', requireAuth, (c) => {
  return c.json({ playlists: repo.listPlaylists(c.get('user').id) });
});

app.post('/playlist', requireAuth, async (c) => {
  const body = await readJson<{ name?: string }>(c);
  const name = body.name?.trim();
  if (!name) return c.json({ error: 'name is required' }, 400);
  return c.json(repo.createPlaylist(c.get('user').id, name), 201);
});

app.post('/playlist/:id/add', requireAuth, async (c) => {
  const body = await readJson<{ trackId?: string }>(c);
  if (!body.trackId) return c.json({ error: 'trackId is required' }, 400);
  if (!repo.trackExists(body.trackId)) return c.json({ error: 'Track not found' }, 404);
  const ok = repo.addPlaylistTrack(c.get('user').id, c.req.param('id'), body.trackId);
  if (!ok) return c.json({ error: 'Playlist not found' }, 404);
  return c.json({ ok: true });
});

app.post('/playlist/:id/reorder', requireAuth, async (c) => {
  const body = await readJson<{ trackIds?: string[] }>(c);
  if (!Array.isArray(body.trackIds)) {
    return c.json({ error: 'trackIds must be an array' }, 400);
  }
  if (body.trackIds.some((trackId) => !repo.trackExists(trackId))) {
    return c.json({ error: 'Track not found' }, 404);
  }
  const ok = repo.reorderPlaylist(c.get('user').id, c.req.param('id'), body.trackIds);
  if (!ok) return c.json({ error: 'Playlist not found' }, 404);
  return c.json({ ok: true });
});

app.post('/favorite/:id', requireAuth, (c) => {
  if (!repo.trackExists(c.req.param('id'))) return c.json({ error: 'Track not found' }, 404);
  repo.setFavorite(c.get('user').id, c.req.param('id'));
  return c.json({ ok: true });
});

app.delete('/favorite/:id', requireAuth, (c) => {
  repo.deleteFavorite(c.get('user').id, c.req.param('id'));
  return c.json({ ok: true });
});

app.get('/favorites', requireAuth, (c) => {
  return c.json({ favorites: repo.listFavorites(c.get('user').id) });
});

app.get('/playback-state/latest', requireAuth, (c) => {
  return c.json({ playbackState: repo.getPlaybackState(c.get('user').id) });
});

app.patch('/playback-state', requireAuth, async (c) => {
  const body = await readJson<{
    trackId?: string;
    positionMs?: number;
  }>(c);
  if (!body.trackId || typeof body.positionMs !== 'number') {
    return c.json({ error: 'trackId and positionMs are required' }, 400);
  }
  if (!repo.trackExists(body.trackId)) return c.json({ error: 'Track not found' }, 404);
  repo.patchPlaybackState(c.get('user').id, body.trackId, body.positionMs);
  return c.json({ ok: true });
});

app.post('/history', requireAuth, async (c) => {
  const body = await readJson<{
    trackId?: string;
    startedAt?: string;
    endedAt?: string | null;
    durationPlayed?: number;
  }>(c);
  if (!body.trackId || !body.startedAt || typeof body.durationPlayed !== 'number') {
    return c.json(
      { error: 'trackId, startedAt, and durationPlayed are required' },
      400,
    );
  }
  if (!repo.trackExists(body.trackId)) return c.json({ error: 'Track not found' }, 404);
  const id = repo.appendHistory({
    userId: c.get('user').id,
    trackId: body.trackId,
    startedAt: body.startedAt,
    endedAt: body.endedAt,
    durationPlayed: body.durationPlayed,
  });
  return c.json({ id }, 201);
});

app.get('/history', requireAuth, (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 50), 200);
  return c.json({ history: repo.listHistory(c.get('user').id, limit) });
});

function validateCandidate(candidate: Partial<TrackCandidate>): string | null {
  if (!candidate.title?.trim()) return 'title is required';
  if (!candidate.artist?.trim()) return 'artist is required';
  if (!candidate.sourceInstanceId?.trim()) return 'sourceInstanceId is required';
  if (!candidate.sourceTrackId?.trim()) return 'sourceTrackId is required';
  if (
    candidate.duration != null &&
    (typeof candidate.duration !== 'number' || candidate.duration < 0)
  ) {
    return 'duration must be a positive number';
  }
  return null;
}

async function readJson<T>(c: Context): Promise<T> {
  try {
    return await c.req.json<T>();
  } catch {
    throw new HttpError('Invalid JSON body', 400);
  }
}

function toPublicCandidate(candidate: TrackCandidate): TrackCandidate {
  return {
    title: candidate.title,
    artist: candidate.artist,
    duration: candidate.duration ?? null,
    version: candidate.version ?? null,
    sourceInstanceId: candidate.sourceInstanceId,
    sourceTrackId: candidate.sourceTrackId,
  };
}

function bearerToken(header: string | undefined): string | null {
  const match = /^Bearer\s+(.+)$/i.exec(header ?? '');
  return match?.[1]?.trim() || null;
}

function issueSession(userId: string): string {
  repo.deleteExpiredSessions();
  const token = createSessionToken();
  const expiresAt = String(Date.now() + sessionTtlDays * 24 * 60 * 60 * 1000);
  repo.createSession(userId, token, expiresAt);
  return token;
}

function toPublicUser(user: User): PublicUser {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    createdAt: user.createdAt,
  };
}

serve({ fetch: app.fetch, port }, (info) => {
  console.log(`MuseHub Server V0 listening on http://127.0.0.1:${info.port}`);
});
