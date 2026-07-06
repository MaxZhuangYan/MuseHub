import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';

export type Db = Database.Database;

export function openDatabase(dbPath: string): Db {
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.pragma('busy_timeout = 5000');
  applySchema(db);
  return db;
}

function applySchema(db: Db): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS tracks (
      id TEXT PRIMARY KEY,
      createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS track_metadata (
      trackId TEXT PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      artist TEXT NOT NULL,
      normalizedTitle TEXT NOT NULL,
      normalizedArtist TEXT NOT NULL,
      duration INTEGER,
      version TEXT,
      updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_track_metadata_match
      ON track_metadata(normalizedTitle, normalizedArtist, duration);

    CREATE TABLE IF NOT EXISTS track_source_bindings (
      id TEXT PRIMARY KEY,
      trackId TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      sourceInstanceId TEXT NOT NULL,
      sourceTrackId TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('available', 'dead', 'unknown')),
      priority INTEGER NOT NULL DEFAULT 100,
      matchConfidence REAL NOT NULL DEFAULT 1.0,
      lastVerifiedAt TEXT,
      createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(sourceInstanceId, sourceTrackId)
    );

    CREATE INDEX IF NOT EXISTS idx_bindings_track
      ON track_source_bindings(trackId, status, priority);

    CREATE TABLE IF NOT EXISTS track_aliases (
      oldTrackId TEXT PRIMARY KEY,
      newTrackId TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      reason TEXT NOT NULL,
      createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS playlists (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS playlist_tracks (
      playlistId TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
      trackId TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      position INTEGER NOT NULL,
      addedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (playlistId, trackId)
    );

    CREATE INDEX IF NOT EXISTS idx_playlist_tracks_position
      ON playlist_tracks(playlistId, position);

    CREATE TABLE IF NOT EXISTS favorites (
      trackId TEXT PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE,
      createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS playback_state (
      userId TEXT PRIMARY KEY,
      trackId TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      positionMs INTEGER NOT NULL,
      updatedAt TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS playback_history (
      id TEXT PRIMARY KEY,
      trackId TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      startedAt TEXT NOT NULL,
      endedAt TEXT,
      durationPlayed INTEGER NOT NULL DEFAULT 0
    );
  `);
}
