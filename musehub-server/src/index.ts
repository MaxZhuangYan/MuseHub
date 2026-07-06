import { serve } from '@hono/node-server';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { openDatabase } from './db.js';
import { Repository } from './repository.js';
import { LocalSource } from './sources/local.js';
import { MockNeteaseSource } from './sources/mock-netease.js';
import { SourceRegistry } from './sources/registry.js';
import { proxyStream } from './stream.js';
import type { TrackCandidate } from './types.js';

const port = Number(process.env.PORT ?? 30490);
const dbPath = process.env.DB_PATH ?? './data/musehub.sqlite';
const musicDir = process.env.MUSIC_DIR ?? '/music';
const defaultUserId = 'local';

const db = openDatabase(dbPath);
const repo = new Repository(db);
const sources = new SourceRegistry();
sources.register(new MockNeteaseSource());
sources.register(new LocalSource(musicDir));

const app = new Hono();
app.use('*', cors());

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
    sources.searchable().map(async (source) => source.search(query)),
  );
  return c.json({ results: results.flat() });
});

app.post('/tracks/resolve', async (c) => {
  const candidate = await c.req.json<TrackCandidate>();
  const error = validateCandidate(candidate);
  if (error) return c.json({ error }, 400);
  const result = repo.resolveTrack(candidate);
  return c.json(result, result.created ? 201 : 200);
});

app.get('/track/:id', (c) => {
  const track = repo.getTrack(c.req.param('id'));
  if (!track) return c.json({ error: 'Track not found' }, 404);
  return c.json(track);
});

app.get('/stream/:id', async (c) => {
  const binding = repo.getBestBinding(c.req.param('id'));
  if (!binding) return c.json({ error: 'No playable binding found' }, 404);
  const source = sources.get(binding.sourceInstanceId);
  if (!source) return c.json({ error: 'Source not registered' }, 502);
  const candidate = repo.getBindingCandidate(binding);
  if (!candidate) return c.json({ error: 'Track not found' }, 404);
  const handle = await source.getStream(candidate);
  return proxyStream(c, handle);
});

app.get('/playlists', (c) => {
  return c.json({ playlists: repo.listPlaylists() });
});

app.post('/playlist', async (c) => {
  const body = await c.req.json<{ name?: string }>();
  const name = body.name?.trim();
  if (!name) return c.json({ error: 'name is required' }, 400);
  return c.json(repo.createPlaylist(name), 201);
});

app.post('/playlist/:id/add', async (c) => {
  const body = await c.req.json<{ trackId?: string }>();
  if (!body.trackId) return c.json({ error: 'trackId is required' }, 400);
  repo.addPlaylistTrack(c.req.param('id'), body.trackId);
  return c.json({ ok: true });
});

app.post('/playlist/:id/reorder', async (c) => {
  const body = await c.req.json<{ trackIds?: string[] }>();
  if (!Array.isArray(body.trackIds)) {
    return c.json({ error: 'trackIds must be an array' }, 400);
  }
  repo.reorderPlaylist(c.req.param('id'), body.trackIds);
  return c.json({ ok: true });
});

app.post('/favorite/:id', (c) => {
  repo.setFavorite(c.req.param('id'));
  return c.json({ ok: true });
});

app.delete('/favorite/:id', (c) => {
  repo.deleteFavorite(c.req.param('id'));
  return c.json({ ok: true });
});

app.get('/favorites', (c) => {
  return c.json({ favorites: repo.listFavorites() });
});

app.get('/playback-state/latest', (c) => {
  const userId = c.req.query('userId') ?? defaultUserId;
  return c.json({ playbackState: repo.getPlaybackState(userId) });
});

app.patch('/playback-state', async (c) => {
  const body = await c.req.json<{
    userId?: string;
    trackId?: string;
    positionMs?: number;
  }>();
  if (!body.trackId || typeof body.positionMs !== 'number') {
    return c.json({ error: 'trackId and positionMs are required' }, 400);
  }
  repo.patchPlaybackState(body.userId ?? defaultUserId, body.trackId, body.positionMs);
  return c.json({ ok: true });
});

app.post('/history', async (c) => {
  const body = await c.req.json<{
    trackId?: string;
    startedAt?: string;
    endedAt?: string | null;
    durationPlayed?: number;
  }>();
  if (!body.trackId || !body.startedAt || typeof body.durationPlayed !== 'number') {
    return c.json(
      { error: 'trackId, startedAt, and durationPlayed are required' },
      400,
    );
  }
  const id = repo.appendHistory({
    trackId: body.trackId,
    startedAt: body.startedAt,
    endedAt: body.endedAt,
    durationPlayed: body.durationPlayed,
  });
  return c.json({ id }, 201);
});

app.get('/history', (c) => {
  const limit = Math.min(Number(c.req.query('limit') ?? 50), 200);
  return c.json({ history: repo.listHistory(limit) });
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

serve({ fetch: app.fetch, port }, (info) => {
  console.log(`MuseHub Server V0 listening on http://127.0.0.1:${info.port}`);
});
