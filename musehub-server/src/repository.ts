import { nanoid } from 'nanoid';
import type { Db } from './db.js';
import { normalizeTrackMetadata } from './normalize.js';
import { HttpError } from './types.js';
import type {
  BindingStatus,
  ResolvedTrack,
  SourceBinding,
  TrackCandidate,
  User,
} from './types.js';

export class Repository {
  constructor(private readonly db: Db) {}

  createUser(input: {
    email: string;
    passwordHash: string;
    displayName?: string | null;
  }): User {
    const id = nanoid();
    this.db
      .prepare(
        `INSERT INTO users (id, email, passwordHash, displayName)
         VALUES (?, ?, ?, ?)`,
      )
      .run(id, input.email, input.passwordHash, input.displayName ?? null);
    return this.getUserById(id)!;
  }

  getUserByEmail(email: string): User | null {
    return (
      (this.db.prepare('SELECT * FROM users WHERE email = ?').get(email) as
        | User
        | undefined) ?? null
    );
  }

  getUserById(id: string): User | null {
    return (
      (this.db.prepare('SELECT * FROM users WHERE id = ?').get(id) as User | undefined) ??
      null
    );
  }

  createSession(userId: string, token: string, expiresAt: string): void {
    this.db
      .prepare('INSERT INTO sessions (token, userId, expiresAt) VALUES (?, ?, ?)')
      .run(token, userId, expiresAt);
  }

  getSessionUser(token: string): User | null {
    const row = this.db
      .prepare(
        `SELECT u.*, s.expiresAt AS sessionExpiresAt
         FROM sessions s
         JOIN users u ON u.id = s.userId
         WHERE s.token = ?`,
      )
      .get(token) as (User & { sessionExpiresAt: string }) | undefined;
    if (!row) return null;
    if (isExpired(row.sessionExpiresAt)) {
      this.deleteSession(token);
      return null;
    }
    const { sessionExpiresAt: _sessionExpiresAt, ...user } = row;
    return user;
  }

  deleteSession(token: string): void {
    this.db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
  }

  deleteExpiredSessions(): void {
    const rows = this.db.prepare('SELECT token, expiresAt FROM sessions').all() as Array<{
      token: string;
      expiresAt: string;
    }>;
    const expired = rows.filter((row) => isExpired(row.expiresAt));
    const remove = this.db.prepare('DELETE FROM sessions WHERE token = ?');
    const run = this.db.transaction(() => {
      for (const row of expired) remove.run(row.token);
    });
    run();
  }

  resolveTrack(candidate: TrackCandidate): { trackId: string; created: boolean } {
    const run = this.db.transaction(() => {
      const normalized = normalizeTrackMetadata(candidate.title, candidate.artist);
      const duration = candidate.duration ?? null;
      const existing = this.findMetadataMatch(
        normalized.normalizedTitle,
        normalized.normalizedArtist,
        duration,
      );

      if (existing) {
        this.ensureBinding(
          existing.id,
          candidate,
          'unknown',
          defaultPriority(candidate.sourceInstanceId),
          1,
        );
        return { trackId: existing.id, created: false };
      }

      const trackId = nanoid();
      this.db.prepare('INSERT INTO tracks (id) VALUES (?)').run(trackId);
      this.db
        .prepare(
          `INSERT INTO track_metadata (
            trackId, title, artist, normalizedTitle, normalizedArtist, duration, version
          ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
        )
        .run(
          trackId,
          candidate.title,
          candidate.artist,
          normalized.normalizedTitle,
          normalized.normalizedArtist,
          duration,
          candidate.version ?? null,
        );
      this.ensureBinding(
        trackId,
        candidate,
        'unknown',
        defaultPriority(candidate.sourceInstanceId),
        1,
      );
      return { trackId, created: true };
    });
    return run();
  }

  getTrack(id: string): (ResolvedTrack & { bindings: SourceBinding[] }) | null {
    const trackId = this.resolveAlias(id);
    const metadata = this.db
      .prepare(
        `SELECT
          tracks.id,
          m.title,
          m.artist,
          m.normalizedTitle,
          m.normalizedArtist,
          m.duration,
          m.version
        FROM tracks
        JOIN track_metadata m ON m.trackId = tracks.id
        WHERE tracks.id = ?`,
      )
      .get(trackId) as ResolvedTrack | undefined;
    if (!metadata) return null;
    return {
      ...metadata,
      bindings: this.getBindings(trackId),
    };
  }

  getBestBinding(trackId: string): SourceBinding | null {
    const resolved = this.resolveAlias(trackId);
    return (
      (this.db
        .prepare(
          `SELECT * FROM track_source_bindings
           WHERE trackId = ? AND status != 'dead'
           ORDER BY priority ASC, matchConfidence DESC, createdAt ASC
           LIMIT 1`,
        )
        .get(resolved) as SourceBinding | undefined) ?? null
    );
  }

  getPlayableBindings(trackId: string): SourceBinding[] {
    const resolved = this.resolveAlias(trackId);
    return this.db
      .prepare(
        `SELECT * FROM track_source_bindings
         WHERE trackId = ? AND status != 'dead'
         ORDER BY priority ASC, matchConfidence DESC, createdAt ASC`,
      )
      .all(resolved) as SourceBinding[];
  }

  getBindingCandidate(binding: SourceBinding): TrackCandidate | null {
    const track = this.getTrack(binding.trackId);
    if (!track) return null;
    return {
      title: track.title,
      artist: track.artist,
      duration: track.duration,
      version: track.version,
      sourceInstanceId: binding.sourceInstanceId,
      sourceTrackId: binding.sourceTrackId,
    };
  }

  trackExists(trackId: string): boolean {
    const resolvedTrackId = this.resolveAlias(trackId);
    const row = this.db.prepare('SELECT id FROM tracks WHERE id = ?').get(resolvedTrackId);
    return row != null;
  }

  listPlaylists(userId: string): unknown[] {
    const playlists = this.db
      .prepare('SELECT * FROM playlists WHERE userId = ? ORDER BY createdAt DESC')
      .all(userId) as Array<{
      id: string;
      userId: string;
      name: string;
      createdAt: string;
      updatedAt: string;
    }>;
    return playlists.map((playlist) => ({
      ...playlist,
      tracks: this.db
        .prepare(
          `SELECT pt.position, m.trackId AS id, m.title, m.artist, m.duration, m.version
           FROM playlist_tracks pt
           JOIN track_metadata m ON m.trackId = pt.trackId
           WHERE pt.playlistId = ?
           ORDER BY pt.position ASC`,
        )
        .all(playlist.id),
    }));
  }

  createPlaylist(userId: string, name: string): { id: string; name: string } {
    const id = nanoid();
    this.db
      .prepare('INSERT INTO playlists (id, userId, name) VALUES (?, ?, ?)')
      .run(id, userId, name);
    return { id, name };
  }

  addPlaylistTrack(userId: string, playlistId: string, trackId: string): boolean {
    const resolvedTrackId = this.resolveAlias(trackId);
    if (!this.trackExists(resolvedTrackId)) return false;
    const playlist = this.db
      .prepare('SELECT id FROM playlists WHERE id = ? AND userId = ?')
      .get(playlistId, userId);
    if (!playlist) return false;
    const row = this.db
      .prepare('SELECT COALESCE(MAX(position), -1) + 1 AS next FROM playlist_tracks WHERE playlistId = ?')
      .get(playlistId) as { next: number };
    this.db
      .prepare(
        `INSERT OR REPLACE INTO playlist_tracks (playlistId, trackId, position)
         VALUES (?, ?, ?)`,
      )
      .run(playlistId, resolvedTrackId, row.next);
    return true;
  }

  reorderPlaylist(userId: string, playlistId: string, trackIds: string[]): boolean {
    const playlist = this.db
      .prepare('SELECT id FROM playlists WHERE id = ? AND userId = ?')
      .get(playlistId, userId);
    if (!playlist) return false;
    const run = this.db.transaction(() => {
      for (let i = 0; i < trackIds.length; i++) {
        this.db
          .prepare(
            `UPDATE playlist_tracks
             SET position = ?
             WHERE playlistId = ? AND trackId = ?`,
          )
          .run(i, playlistId, this.resolveAlias(trackIds[i]));
      }
    });
    run();
    return true;
  }

  setFavorite(userId: string, trackId: string): void {
    const resolvedTrackId = this.resolveAlias(trackId);
    if (!this.trackExists(resolvedTrackId)) throw new HttpError('Track not found', 404);
    this.db
      .prepare('INSERT OR IGNORE INTO favorites (userId, trackId) VALUES (?, ?)')
      .run(userId, resolvedTrackId);
  }

  deleteFavorite(userId: string, trackId: string): void {
    this.db
      .prepare('DELETE FROM favorites WHERE userId = ? AND trackId = ?')
      .run(userId, this.resolveAlias(trackId));
  }

  listFavorites(userId: string): unknown[] {
    const rows = this.db
      .prepare(
        `SELECT f.createdAt, m.trackId AS id, m.title, m.artist, m.duration, m.version
         FROM favorites f
         JOIN track_metadata m ON m.trackId = f.trackId
         WHERE f.userId = ?
         ORDER BY f.createdAt DESC`,
      )
      .all(userId) as Array<{
      createdAt: string;
      id: string;
      title: string;
      artist: string;
      duration: number | null;
      version: string | null;
    }>;
    return rows.map((row) => ({
      ...row,
      bindings: this.getBindings(row.id),
    }));
  }

  getPlaybackState(userId: string): unknown | null {
    return (
      this.db.prepare('SELECT * FROM playback_state WHERE userId = ?').get(userId) ??
      null
    );
  }

  patchPlaybackState(userId: string, trackId: string, positionMs: number): void {
    const resolvedTrackId = this.resolveAlias(trackId);
    if (!this.trackExists(resolvedTrackId)) throw new HttpError('Track not found', 404);
    this.db
      .prepare(
        `INSERT INTO playback_state (userId, trackId, positionMs, updatedAt)
         VALUES (?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(userId) DO UPDATE SET
           trackId = excluded.trackId,
           positionMs = excluded.positionMs,
           updatedAt = excluded.updatedAt`,
      )
      .run(userId, resolvedTrackId, positionMs);
  }

  appendHistory(input: {
    userId: string;
    trackId: string;
    startedAt: string;
    endedAt?: string | null;
    durationPlayed: number;
  }): string {
    const id = nanoid();
    const resolvedTrackId = this.resolveAlias(input.trackId);
    if (!this.trackExists(resolvedTrackId)) throw new HttpError('Track not found', 404);
    this.db
      .prepare(
        `INSERT INTO playback_history (id, userId, trackId, startedAt, endedAt, durationPlayed)
         VALUES (?, ?, ?, ?, ?, ?)`,
      )
      .run(
        id,
        input.userId,
        resolvedTrackId,
        input.startedAt,
        input.endedAt ?? null,
        input.durationPlayed,
      );
    return id;
  }

  listHistory(userId: string, limit: number): unknown[] {
    return this.db
      .prepare(
        `SELECT h.*, m.title, m.artist
         FROM playback_history h
         JOIN track_metadata m ON m.trackId = h.trackId
         WHERE h.userId = ?
         ORDER BY h.startedAt DESC
         LIMIT ?`,
      )
      .all(userId, limit);
  }

  resolveAlias(trackId: string): string {
    let current = trackId;
    const seen = new Set<string>();
    while (!seen.has(current)) {
      seen.add(current);
      const alias = this.db
        .prepare('SELECT newTrackId FROM track_aliases WHERE oldTrackId = ?')
        .get(current) as { newTrackId: string } | undefined;
      if (!alias) return current;
      current = alias.newTrackId;
    }
    return current;
  }

  private findMetadataMatch(
    normalizedTitle: string,
    normalizedArtist: string,
    duration: number | null,
  ): ResolvedTrack | null {
    const rows = this.db
      .prepare(
        `SELECT
          trackId AS id,
          title,
          artist,
          normalizedTitle,
          normalizedArtist,
          duration,
          version
        FROM track_metadata
        WHERE normalizedTitle = ? AND normalizedArtist = ?`,
      )
      .all(normalizedTitle, normalizedArtist) as ResolvedTrack[];

    return (
      rows.find((row) => {
        if (duration == null || row.duration == null) return true;
        return Math.abs(row.duration - duration) <= 2000;
      }) ?? null
    );
  }

  private ensureBinding(
    trackId: string,
    candidate: TrackCandidate,
    status: BindingStatus,
    priority: number,
    matchConfidence: number,
  ): void {
    const existing = this.db
      .prepare(
        `SELECT id FROM track_source_bindings
         WHERE sourceInstanceId = ? AND sourceTrackId = ?`,
      )
      .get(candidate.sourceInstanceId, candidate.sourceTrackId) as
      | { id: string }
      | undefined;
    if (existing) return;

    this.db
      .prepare(
        `INSERT INTO track_source_bindings (
          id, trackId, sourceInstanceId, sourceTrackId, status, priority,
          matchConfidence, lastVerifiedAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
      )
      .run(
        nanoid(),
        trackId,
        candidate.sourceInstanceId,
        candidate.sourceTrackId,
        status,
        priority,
        matchConfidence,
      );
  }

  private getBindings(trackId: string): SourceBinding[] {
    return this.db
      .prepare('SELECT * FROM track_source_bindings WHERE trackId = ? ORDER BY priority ASC')
      .all(trackId) as SourceBinding[];
  }
}

function defaultPriority(sourceInstanceId: string): number {
  if (sourceInstanceId === 'local') return 10;
  if (sourceInstanceId === 'netease') return 50;
  if (sourceInstanceId === 'alger') return 80;
  return 100;
}

function isExpired(value: string): boolean {
  const asNumber = Number(value);
  const expiresAt = Number.isFinite(asNumber) && value.trim() !== ''
    ? asNumber
    : Date.parse(value);
  return !Number.isFinite(expiresAt) || expiresAt <= Date.now();
}
