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
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT NOT NULL UNIQUE,
      passwordHash TEXT NOT NULL,
      displayName TEXT,
      createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      expiresAt TEXT NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_sessions_user
      ON sessions(userId, expiresAt);

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
      userId TEXT NOT NULL DEFAULT 'local',
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
      userId TEXT NOT NULL DEFAULT 'local',
      trackId TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (userId, trackId)
    );

    CREATE TABLE IF NOT EXISTS playback_state (
      userId TEXT PRIMARY KEY,
      trackId TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      positionMs INTEGER NOT NULL,
      updatedAt TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS playback_history (
      id TEXT PRIMARY KEY,
      userId TEXT NOT NULL DEFAULT 'local',
      trackId TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      startedAt TEXT NOT NULL,
      endedAt TEXT,
      durationPlayed INTEGER NOT NULL DEFAULT 0
    );
  `);
  applyLightweightMigrations(db);
}

function applyLightweightMigrations(db: Db): void {
  ensureColumn(db, 'playlists', 'userId', "TEXT NOT NULL DEFAULT 'local'");
  ensureColumn(db, 'favorites', 'userId', "TEXT NOT NULL DEFAULT 'local'");
  ensureColumn(db, 'playback_history', 'userId', "TEXT NOT NULL DEFAULT 'local'");
  migrateFavoritesPrimaryKey(db);

  db.exec(`
    INSERT OR IGNORE INTO users (id, email, passwordHash, displayName)
    VALUES ('local', 'local@musehub.local', 'legacy-local-user', 'Local User');

    CREATE INDEX IF NOT EXISTS idx_playlists_user
      ON playlists(userId, createdAt);

    CREATE INDEX IF NOT EXISTS idx_favorites_user
      ON favorites(userId, createdAt);

    CREATE INDEX IF NOT EXISTS idx_history_user
      ON playback_history(userId, startedAt);
  `);
}

function ensureColumn(db: Db, table: string, column: string, definition: string): void {
  const rows = db.prepare(`PRAGMA table_info(${table})`).all() as Array<{ name: string }>;
  if (rows.some((row) => row.name === column)) return;
  db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
}

function migrateFavoritesPrimaryKey(db: Db): void {
  const rows = db.prepare('PRAGMA table_info(favorites)').all() as Array<{
    name: string;
    pk: number;
  }>;
  const trackIdColumn = rows.find((row) => row.name === 'trackId');
  const userIdColumn = rows.find((row) => row.name === 'userId');
  if (trackIdColumn?.pk !== 1 || userIdColumn?.pk === 1) return;

  db.exec(`
    CREATE TABLE favorites_next (
      userId TEXT NOT NULL DEFAULT 'local',
      trackId TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      createdAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (userId, trackId)
    );

    INSERT OR IGNORE INTO favorites_next (userId, trackId, createdAt)
    SELECT userId, trackId, createdAt FROM favorites;

    DROP TABLE favorites;
    ALTER TABLE favorites_next RENAME TO favorites;
  `);
}
