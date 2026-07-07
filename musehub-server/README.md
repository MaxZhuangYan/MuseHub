# MuseHub Server V0

Minimal self-hosted music orchestration backend for the MuseHub Flutter client.

## Run

```sh
npm install
npm run dev
```

Defaults:

- HTTP: `http://127.0.0.1:30490`
- SQLite: `./data/musehub.sqlite`
- Local music folder: `/music`

Override with env:

```sh
PORT=30490 DB_PATH=./data/musehub.sqlite MUSIC_DIR=/music npm run dev
```

Optional source configuration:

```sh
# Existing Netease-compatible mechanism. Enabled by default unless set to false.
NETEASE_SOURCE_ENABLED=true
NETEASE_API_BASE=https://netease-cloud-music-api-five-roan-88.vercel.app
NETEASE_DIRECT_API_BASE=https://music.163.com/api

# Alger/unblock resolver mechanism. Enabled only when this URL is set.
ALGER_RESOLVER_URL=http://127.0.0.1:30489

# Per-source HTTP timeout.
SOURCE_REQUEST_TIMEOUT_MS=8000
ALGER_RESOLVER_TIMEOUT_MS=45000
```

Source behavior:

- `local` is preferred for files in `MUSIC_DIR`.
- `netease` uses the existing direct/compatible Netease API flow.
- `alger` delegates playback resolution to `ALGER_RESOLVER_URL`.
- `/stream/:id` proxies the selected source and automatically tries lower-priority bindings when one source cannot produce a usable stream.

## Core Endpoints

```txt
GET  /health
GET  /search?q=yellow
POST /auth/register
POST /auth/login
POST /auth/logout
GET  /me
POST /tracks/resolve
GET  /track/:id
GET  /stream/:id

GET  /playlists
POST /playlist
POST /playlist/:id/add
POST /playlist/:id/reorder

POST   /favorite/:id
DELETE /favorite/:id
GET    /favorites

GET   /playback-state/latest
PATCH /playback-state
POST  /history
GET   /history
```

User-owned endpoints require:

```txt
Authorization: Bearer SESSION_TOKEN
```

## Example

```sh
curl "http://127.0.0.1:30490/search?q=yellow"
```

Create a local sample track:

```sh
npm run sample:local
MUSIC_DIR=./music npm run dev
```

Resolve a candidate into a stable MuseHub track:

```sh
curl -X POST "http://127.0.0.1:30490/tracks/resolve" \
  -H "content-type: application/json" \
  -H "authorization: Bearer SESSION_TOKEN" \
  -d '{
    "title": "Yellow",
    "artist": "Coldplay",
    "duration": 266000,
    "sourceInstanceId": "mock-netease",
    "sourceTrackId": "mock-netease-yellow"
  }'
```

Stream through the server:

```sh
curl -L "http://127.0.0.1:30490/stream/TRACK_ID" \
  -H "authorization: Bearer SESSION_TOKEN"
```

Register and call a protected endpoint:

```sh
curl -X POST "http://127.0.0.1:30490/auth/register" \
  -H "content-type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

curl "http://127.0.0.1:30490/favorites" \
  -H "authorization: Bearer SESSION_TOKEN"
```

Run the backend smoke test:

```sh
npm run build
npm run smoke
```

## Notes

- Track IDs are UUID-like nanoid values. Source IDs are stored in bindings.
- Raw title and artist are preserved for display.
- Normalized title and artist are used only for matching.
- SQLite runs in WAL mode.
- `/stream/:id` never returns raw source URLs to clients.
- Passwords are hashed with Node.js `crypto.scrypt`.
- Playlist, favorites, playback state, and history are scoped by authenticated user.
- Search tolerates individual source failures; one broken source will not break the full `/search` response.
