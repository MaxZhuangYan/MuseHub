import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const root = process.cwd();
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'musehub-smoke-'));
const musicDir = path.join(tempRoot, 'music');
const dataDir = path.join(tempRoot, 'data');
fs.mkdirSync(musicDir, { recursive: true });
fs.mkdirSync(dataDir, { recursive: true });
fs.writeFileSync(path.join(musicDir, 'Coldplay - Yellow.mp3'), '0123456789abcdefghijklmnopqrstuvwxyz\n');

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

  const resolved = await postJson(`${base}/tracks/resolve`, localCandidate);
  assert.ok(resolved.trackId);
  assert.equal(resolved.created, true);

  const resolvedAgain = await postJson(`${base}/tracks/resolve`, localCandidate);
  assert.equal(resolvedAgain.trackId, resolved.trackId);
  assert.equal(resolvedAgain.created, false);

  const track = await getJson(`${base}/track/${resolved.trackId}`);
  assert.equal(track.title, 'Yellow');
  assert.equal(track.artist, 'Coldplay');
  assert.equal(track.normalizedTitle, 'yellow');
  assert.equal(track.normalizedArtist, 'coldplay');
  assert.equal(track.bindings.length, 1);

  const stream = await fetch(`${base}/stream/${resolved.trackId}`, {
    headers: { range: 'bytes=0-9' },
  });
  assert.equal(stream.status, 206);
  assert.equal(stream.headers.get('accept-ranges'), 'bytes');
  assert.equal(stream.headers.get('content-range'), 'bytes 0-9/37');
  assert.equal(stream.headers.get('content-length'), '10');
  assert.equal(await stream.text(), '0123456789');

  const playlist = await postJson(`${base}/playlist`, { name: 'Smoke Playlist' });
  assert.ok(playlist.id);
  await postJson(`${base}/playlist/${playlist.id}/add`, { trackId: resolved.trackId });
  const playlists = await getJson(`${base}/playlists`);
  assert.equal(playlists.playlists.length, 1);
  assert.equal(playlists.playlists[0].tracks.length, 1);

  await fetch(`${base}/favorite/${resolved.trackId}`, { method: 'POST' });
  const favorites = await getJson(`${base}/favorites`);
  assert.equal(favorites.favorites.length, 1);

  const playbackPatch = await fetch(`${base}/playback-state`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ trackId: resolved.trackId, positionMs: 12345 }),
  });
  assert.equal(playbackPatch.status, 200);
  const playback = await getJson(`${base}/playback-state/latest`);
  assert.equal(playback.playbackState.trackId, resolved.trackId);
  assert.equal(playback.playbackState.positionMs, 12345);

  const history = await postJson(`${base}/history`, {
    trackId: resolved.trackId,
    startedAt: new Date('2026-01-01T00:00:00Z').toISOString(),
    endedAt: new Date('2026-01-01T00:01:00Z').toISOString(),
    durationPlayed: 60000,
  });
  assert.ok(history.id);
  const historyList = await getJson(`${base}/history`);
  assert.equal(historyList.history.length, 1);

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

async function getJson(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status}: ${await response.text()}`);
  }
  return response.json();
}

async function postJson(url, body) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status}: ${await response.text()}`);
  }
  return response.json();
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
