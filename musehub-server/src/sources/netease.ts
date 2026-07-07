import { StreamError, type Source, type StreamHandle, type TrackCandidate } from '../types.js';

const DEFAULT_COMPATIBLE_API_BASE = 'https://netease-cloud-music-api-five-roan-88.vercel.app';
const DEFAULT_DIRECT_API_BASE = 'https://music.163.com/api';
const DEFAULT_TIMEOUT_MS = 8000;
const DEFAULT_MIN_AUDIO_BYTES = 512 * 1024;

interface NeteaseSearchOptions {
  sourceInstanceId: string;
  compatibleApiBaseUrl?: string;
  directApiBaseUrl?: string;
  timeoutMs?: number;
  limit?: number;
}

interface NeteaseSourceOptions {
  compatibleApiBaseUrl?: string;
  directApiBaseUrl?: string;
  timeoutMs?: number;
  minAudioBytes?: number;
}

interface RemoteAudioValidation {
  ok: boolean;
  reason?: string;
}

interface NeteaseEndpoint {
  baseUrl: string;
  path: string;
  query: Record<string, string>;
}

export class NeteaseSource implements Source {
  id = 'netease';

  capabilities = {
    search: true,
    scan: false,
    stream: 'proxy' as const,
  };

  private readonly compatibleApiBaseUrl: string;
  private readonly directApiBaseUrl: string;
  private readonly timeoutMs: number;
  private readonly minAudioBytes: number;

  constructor(options: NeteaseSourceOptions = {}) {
    this.compatibleApiBaseUrl = stripTrailingSlash(
      options.compatibleApiBaseUrl ?? DEFAULT_COMPATIBLE_API_BASE,
    );
    this.directApiBaseUrl = stripTrailingSlash(
      options.directApiBaseUrl ?? DEFAULT_DIRECT_API_BASE,
    );
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    this.minAudioBytes = options.minAudioBytes ?? DEFAULT_MIN_AUDIO_BYTES;
  }

  async search(query: string): Promise<TrackCandidate[]> {
    return searchNeteaseCandidates(query, {
      sourceInstanceId: this.id,
      compatibleApiBaseUrl: this.compatibleApiBaseUrl,
      directApiBaseUrl: this.directApiBaseUrl,
      timeoutMs: this.timeoutMs,
    });
  }

  async getStream(candidate: TrackCandidate): Promise<StreamHandle> {
    const id = candidate.sourceTrackId.trim();
    if (!id) throw new StreamError('Missing Netease song id', 400);

    const endpoints: NeteaseEndpoint[] = [
      {
        baseUrl: this.directApiBaseUrl,
        path: '/song/enhance/player/url',
        query: { id, ids: `[${id}]`, br: '320000' },
      },
      {
        baseUrl: this.compatibleApiBaseUrl,
        path: '/song/url/v1',
        query: { id, level: 'higher', encodeType: 'aac' },
      },
      {
        baseUrl: this.compatibleApiBaseUrl,
        path: '/song/url/v1',
        query: { id, level: 'exhigh', encodeType: 'aac' },
      },
      {
        baseUrl: this.compatibleApiBaseUrl,
        path: '/song/url/v1',
        query: { id, level: 'standard', encodeType: 'aac' },
      },
      {
        baseUrl: this.compatibleApiBaseUrl,
        path: '/song/url',
        query: { id, br: '128000' },
      },
    ];

    for (const endpoint of endpoints) {
      try {
        const data = await fetchJson(buildUrl(endpoint), this.timeoutMs);
        const url = readSongUrl(data);
        if (!url) continue;
        const validation = await validateRemoteAudio(url, this.timeoutMs, this.minAudioBytes);
        if (!validation.ok) continue;
        return { url, contentType: 'audio/mpeg' };
      } catch {
        // Try the next endpoint. Playback fallback across sources happens in index.ts.
      }
    }

    throw new StreamError('Netease stream unavailable', 404);
  }
}

export async function searchNeteaseCandidates(
  query: string,
  options: NeteaseSearchOptions,
): Promise<TrackCandidate[]> {
  const keyword = query.trim();
  if (!keyword) return [];
  const compatibleApiBaseUrl = stripTrailingSlash(
    options.compatibleApiBaseUrl ?? DEFAULT_COMPATIBLE_API_BASE,
  );
  const directApiBaseUrl = stripTrailingSlash(
    options.directApiBaseUrl ?? DEFAULT_DIRECT_API_BASE,
  );
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const limit = options.limit ?? 30;

  const endpoints: NeteaseEndpoint[] = [
    {
      baseUrl: directApiBaseUrl,
      path: '/search/get',
      query: { s: keyword, type: '1', limit: String(limit), offset: '0' },
    },
    {
      baseUrl: compatibleApiBaseUrl,
      path: '/cloudsearch',
      query: { keywords: keyword, type: '1', limit: String(limit), offset: '0' },
    },
  ];

  const responses = await Promise.allSettled(
    endpoints.map((endpoint) => fetchJson(buildUrl(endpoint), timeoutMs)),
  );
  const seen = new Set<string>();
  const results: TrackCandidate[] = [];
  for (const response of responses) {
    if (response.status !== 'fulfilled') continue;
    for (const song of readSongs(response.value)) {
      const candidate = candidateFromSong(song, options.sourceInstanceId);
      if (!candidate || seen.has(candidate.sourceTrackId)) continue;
      seen.add(candidate.sourceTrackId);
      results.push(candidate);
    }
  }
  return results.slice(0, limit);
}

export function readSongUrl(data: unknown): string | null {
  if (!isRecord(data)) return null;
  const directUrl = typeof data.url === 'string' ? data.url : null;
  if (directUrl) return directUrl;
  const items = data.data;
  if (!Array.isArray(items) || items.length === 0) return null;
  const first = items[0];
  if (!isRecord(first)) return null;
  const url = first.url;
  return typeof url === 'string' && url.trim() ? url : null;
}

async function validateRemoteAudio(
  url: string,
  timeoutMs: number,
  minAudioBytes: number,
): Promise<RemoteAudioValidation> {
  try {
    const response = await fetchWithTimeout(url, timeoutMs, {
      method: 'HEAD',
      headers: { accept: '*/*', 'user-agent': userAgent() },
    });
    if (response.status < 200 || response.status >= 400) {
      return { ok: false, reason: `bad status: ${response.status}` };
    }
    const contentType = response.headers.get('content-type') ?? '';
    if (contentType && !contentType.toLowerCase().startsWith('audio/')) {
      return { ok: false, reason: `not audio: ${contentType}` };
    }
    const contentLength = Number(response.headers.get('content-length') ?? 0);
    if (contentLength > 0 && contentLength < minAudioBytes) {
      return { ok: false, reason: `audio too small: ${contentLength}` };
    }
    return { ok: true };
  } catch {
    return { ok: true };
  }
}

async function fetchJson(url: string, timeoutMs: number): Promise<unknown> {
  const response = await fetchWithTimeout(url, timeoutMs, {
    headers: {
      accept: 'application/json, text/plain, */*',
      'user-agent': userAgent(),
    },
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return response.json();
}

function fetchWithTimeout(
  url: string,
  timeoutMs: number,
  init: RequestInit = {},
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  return fetch(url, { ...init, signal: controller.signal }).finally(() => {
    clearTimeout(timer);
  });
}

function readSongs(data: unknown): unknown[] {
  if (!isRecord(data)) return [];
  const result = data.result;
  if (isRecord(result) && Array.isArray(result.songs)) return result.songs;
  if (Array.isArray(data.songs)) return data.songs;
  return [];
}

function candidateFromSong(song: unknown, sourceInstanceId: string): TrackCandidate | null {
  if (!isRecord(song)) return null;
  const id = song.id == null ? '' : String(song.id);
  const title = typeof song.name === 'string' ? song.name.trim() : '';
  if (!id || !title) return null;
  const artists = readArtistNames(song);
  const duration = Number(song.dt ?? song.duration ?? 0);
  return {
    title,
    artist: artists.length > 0 ? artists.join(' / ') : 'Unknown Artist',
    duration: Number.isFinite(duration) && duration > 0 ? duration : null,
    version: null,
    sourceInstanceId,
    sourceTrackId: id,
  };
}

function readArtistNames(song: Record<string, unknown>): string[] {
  const rawArtists = Array.isArray(song.ar)
    ? song.ar
    : Array.isArray(song.artists)
      ? song.artists
      : [];
  return rawArtists
    .map((artist) => (isRecord(artist) && typeof artist.name === 'string' ? artist.name : ''))
    .map((name) => name.trim())
    .filter(Boolean);
}

function buildUrl(endpoint: NeteaseEndpoint): string {
  const url = new URL(`${stripTrailingSlash(endpoint.baseUrl)}${endpoint.path}`);
  for (const [key, value] of Object.entries(endpoint.query)) {
    url.searchParams.set(key, value);
  }
  url.searchParams.set('timestamp', String(Date.now()));
  return url.toString();
}

function stripTrailingSlash(value: string): string {
  return value.replace(/\/+$/, '');
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function userAgent(): string {
  return 'Mozilla/5.0 MuseHubServer/0.1';
}
