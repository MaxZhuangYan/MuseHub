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

## Core Endpoints

```txt
GET  /health
GET  /search?q=yellow
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
curl -L "http://127.0.0.1:30490/stream/TRACK_ID"
```

## Notes

- Track IDs are UUID-like nanoid values. Source IDs are stored in bindings.
- Raw title and artist are preserved for display.
- Normalized title and artist are used only for matching.
- SQLite runs in WAL mode.
- `/stream/:id` never returns raw source URLs to clients.
