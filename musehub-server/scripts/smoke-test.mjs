import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const root = process.cwd();
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'musehub-smoke-'));
const musicDir = path.join(tempRoot, 'music');
const privateMusicDir = path.join(tempRoot, 'music_private');
const dataDir = path.join(tempRoot, 'data');
fs.mkdirSync(musicDir, { recursive: true });
fs.mkdirSync(privateMusicDir, { recursive: true });
fs.mkdirSync(dataDir, { recursive: true });
fs.writeFileSync(path.join(musicDir, 'Coldplay - Yellow.mp3'), '0123456789abcdefghijklmnopqrstuvwxyz\n');
fs.writeFileSync(path.join(privateMusicDir, 'secret.mp3'), 'SECRET OUTSIDE MUSIC ROOT\n');

const port = String(39000 + Math.floor(Math.random() * 1000));
const server = spawn(process.execPath, ['dist/index.js'], {
  cwd: root,
  env: {
    ...process.env,
    PORT: port,
    DB_PATH: path.join(dataDir, 'musehub.sqlite'),
    MUSIC_DIR: musicDir,
  },
  stdio: ['ignore', 'pipe', 'pipe'],
});

let output = '';
server.stdout.on('data', (chunk) => {
  output += chunk.toString();
});
server.stderr.on('data', (chunk) => {
  output += chunk.toString();
});

try {
  const base = `http://127.0.0.1:${port}`;
  await waitForHealth(base);

  const health = await getJson(`${base}/health`);
  assert.equal(health.ok, true);
  assert.equal(health.port, Number(port));
  assert.equal(health.sources.length, 2);

  const search = await getJson(`${base}/search?q=yellow`);
  assert.ok(search.results.length >= 1);
  assert.equal(search.results.some((candidate) => 'streamUrl' in candidate), false);
  const localCandidate = search.results.find((candidate) => candidate.sourceInstanceId === 'local');
  assert.ok(localCandidate);
  assert.equal(localCandidate.title, 'Yellow');
  assert.equal(localCandidate.artist, 'Coldplay');

  const unauthorizedResolve = await fetch(`${base}/tracks/resolve`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(localCandidate),
  });
  assert.equal(unauthorizedResolve.status, 401);

  const unauthorized = await fetch(`${base}/favorites`);
  assert.equal(unauthorized.status, 401);

  const auth = await postJson(`${base}/auth/register`, {
    email: 'smoke@example.com',
    password: 'password123',
    displayName: 'Smoke User',
  });
  assert.ok(auth.token);
  assert.equal(auth.user.email, 'smoke@example.com');
  assert.equal('passwordHash' in auth.user, false);

  const duplicate = await fetch(`${base}/auth/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'smoke@example.com', password: 'password123' }),
  });
  assert.equal(duplicate.status, 409);

  const login = await postJson(`${base}/auth/login`, {
    email: 'SMOKE@example.com',
    password: 'password123',
  });
  assert.ok(login.token);
  assert.equal(login.user.id, auth.user.id);

  const me = await getJson(`${base}/me`, login.token);
  assert.equal(me.user.email, 'smoke@example.com');

  const secondAuth = await postJson(`${base}/auth/register`, {
    email: 'other@example.com',
    password: 'password123',
  });

  const mockCandidate = search.results.find((candidate) => candidate.sourceInstanceId === 'mock-netease');
  assert.ok(mockCandidate);
  const resolvedMock = await postJson(`${base}/tracks/resolve`, mockCandidate, login.token);
  assert.ok(resolvedMock.trackId);

  const resolved = await postJson(`${base}/tracks/resolve`, localCandidate, login.token);
  assert.ok(resolved.trackId);
  assert.equal(resolved.trackId, resolvedMock.trackId);
  assert.equal(resolved.created, false);

  const resolvedAgain = await postJson(`${base}/tracks/resolve`, localCandidate, login.token);
  assert.equal(resolvedAgain.trackId, resolved.trackId);
  assert.equal(resolvedAgain.created, false);

  const unauthorizedTrack = await fetch(`${base}/track/${resolved.trackId}`);
  assert.equal(unauthorizedTrack.status, 401);
  const unauthorizedStream = await fetch(`${base}/stream/${resolved.trackId}`);
  assert.equal(unauthorizedStream.status, 401);

  const track = await getJson(`${base}/track/${resolved.trackId}`, login.token);
  assert.equal(track.title, 'Yellow');
  assert.equal(track.artist, 'Coldplay');
  assert.equal(track.normalizedTitle, 'yellow');
  assert.equal(track.normalizedArtist, 'coldplay');
  assert.equal(track.bindings.length, 2);

  const stream = await fetch(`${base}/stream/${resolved.trackId}`, {
    headers: { ...authHeaders(login.token), range: 'bytes=0-9' },
  });
  assert.equal(stream.status, 206);
  assert.equal(stream.headers.get('accept-ranges'), 'bytes');
  assert.equal(stream.headers.get('content-range'), 'bytes 0-9/37');
  assert.equal(stream.headers.get('content-length'), '10');
  assert.equal(await stream.text(), '0123456789');

  const traversalCandidate = {
    title: 'Secret',
    artist: 'Coldplay',
    duration: null,
    version: null,
    sourceInstanceId: 'local',
    sourceTrackId: '../music_private/secret.mp3',
  };
  const traversalResolve = await postJson(`${base}/tracks/resolve`, traversalCandidate, login.token);
  const traversalStream = await fetch(`${base}/stream/${traversalResolve.trackId}`, {
    headers: authHeaders(login.token),
  });
  assert.notEqual(traversalStream.status, 200);
  assert.ok([400, 404, 502].includes(traversalStream.status));
  assert.notEqual(await traversalStream.text(), 'SECRET OUTSIDE MUSIC ROOT\n');

  const playlist = await postJson(
    `${base}/playlist`,
    { name: 'Smoke Playlist' },
    login.token,
  );
  assert.ok(playlist.id);
  await postJson(
    `${base}/playlist/${playlist.id}/add`,
    { trackId: resolved.trackId },
    login.token,
  );
  const playlists = await getJson(`${base}/playlists`, login.token);
  assert.equal(playlists.playlists.length, 1);
  assert.equal(playlists.playlists[0].tracks.length, 1);
  assert.equal(playlists.playlists[0].userId, auth.user.id);

  const secondPlaylists = await getJson(`${base}/playlists`, secondAuth.token);
  assert.equal(secondPlaylists.playlists.length, 0);

  await fetch(`${base}/favorite/${resolved.trackId}`, {
    method: 'POST',
    headers: authHeaders(login.token),
  });
  const favorites = await getJson(`${base}/favorites`, login.token);
  assert.equal(favorites.favorites.length, 1);
  const secondFavorites = await getJson(`${base}/favorites`, secondAuth.token);
  assert.equal(secondFavorites.favorites.length, 0);

  const playbackPatch = await fetch(`${base}/playback-state`, {
    method: 'PATCH',
    headers: authHeaders(login.token),
    body: JSON.stringify({ trackId: resolved.trackId, positionMs: 12345 }),
  });
  assert.equal(playbackPatch.status, 200);
  const playback = await getJson(`${base}/playback-state/latest`, login.token);
  assert.equal(playback.playbackState.trackId, resolved.trackId);
  assert.equal(playback.playbackState.positionMs, 12345);
  const secondPlayback = await getJson(`${base}/playback-state/latest`, secondAuth.token);
  assert.equal(secondPlayback.playbackState, null);

  const history = await postJson(
    `${base}/history`,
    {
      trackId: resolved.trackId,
      startedAt: new Date('2026-01-01T00:00:00Z').toISOString(),
      endedAt: new Date('2026-01-01T00:01:00Z').toISOString(),
      durationPlayed: 60000,
    },
    login.token,
  );
  assert.ok(history.id);
  const historyList = await getJson(`${base}/history`, login.token);
  assert.equal(historyList.history.length, 1);
  const secondHistory = await getJson(`${base}/history`, secondAuth.token);
  assert.equal(secondHistory.history.length, 0);

  const logout = await fetch(`${base}/auth/logout`, {
    method: 'POST',
    headers: authHeaders(login.token),
  });
  assert.equal(logout.status, 200);
  const afterLogout = await fetch(`${base}/me`, { headers: authHeaders(login.token) });
  assert.equal(afterLogout.status, 401);

  console.log('MuseHub Server V0 smoke test passed');
} finally {
  server.kill('SIGTERM');
  await onceExit(server);
  fs.rmSync(tempRoot, { recursive: true, force: true });
}

async function waitForHealth(base) {
  const deadline = Date.now() + 5000;
  let lastError = null;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${base}/health`);
      if (response.ok) return;
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Server did not become healthy. Last error: ${lastError?.message ?? 'none'}\n${output}`);
}

async function getJson(url, token) {
  const response = await fetch(url, { headers: authHeaders(token) });
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status}: ${await response.text()}`);
  }
  return response.json();
}

async function postJson(url, body, token) {
  const response = await fetch(url, {
    method: 'POST',
    headers: authHeaders(token),
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status}: ${await response.text()}`);
  }
  return response.json();
}

function authHeaders(token) {
  const headers = { 'content-type': 'application/json' };
  if (token) headers.authorization = `Bearer ${token}`;
  return headers;
}

function onceExit(child) {
  return new Promise((resolve) => {
    if (child.exitCode !== null || child.signalCode !== null) {
      resolve();
      return;
    }
    child.once('exit', resolve);
  });
}
