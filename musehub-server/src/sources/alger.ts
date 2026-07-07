import { StreamError, type Source, type StreamHandle, type TrackCandidate } from '../types.js';
import { readSongUrl, searchNeteaseCandidates } from './netease.js';

const DEFAULT_TIMEOUT_MS = 45000;
const DEFAULT_ENABLED_SOURCES = ['pyncmd', 'kugou', 'kuwo', 'migu'];

interface AlgerSourceOptions {
  resolverBaseUrl: string;
  compatibleApiBaseUrl?: string;
  directApiBaseUrl?: string;
  timeoutMs?: number;
  enabledSources?: string[];
}

export class AlgerSource implements Source {
  id = 'alger';

  capabilities = {
    search: true,
    scan: false,
    stream: 'proxy' as const,
  };

  private readonly resolverBaseUrl: string;
  private readonly compatibleApiBaseUrl?: string;
  private readonly directApiBaseUrl?: string;
  private readonly timeoutMs: number;
  private readonly enabledSources: string[];

  constructor(options: AlgerSourceOptions) {
    this.resolverBaseUrl = options.resolverBaseUrl.replace(/\/+$/, '');
    this.compatibleApiBaseUrl = options.compatibleApiBaseUrl;
    this.directApiBaseUrl = options.directApiBaseUrl;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    this.enabledSources = options.enabledSources ?? DEFAULT_ENABLED_SOURCES;
  }

  async search(query: string): Promise<TrackCandidate[]> {
    return searchNeteaseCandidates(query, {
      sourceInstanceId: this.id,
      compatibleApiBaseUrl: this.compatibleApiBaseUrl,
      directApiBaseUrl: this.directApiBaseUrl,
      timeoutMs: Math.min(this.timeoutMs, 8000),
    });
  }

  async getStream(candidate: TrackCandidate): Promise<StreamHandle> {
    const id = Number(candidate.sourceTrackId);
    if (!Number.isFinite(id)) {
      throw new StreamError('Alger source requires a numeric Netease song id', 400);
    }

    const response = await fetchWithTimeout(
      `${this.resolverBaseUrl}/unblock-music`,
      this.timeoutMs,
      {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          accept: 'application/json, text/plain, */*',
        },
        body: JSON.stringify({
          id,
          enabledSources: this.enabledSources,
          songData: songDataFromCandidate(candidate),
        }),
      },
    );
    if (!response.ok) {
      throw new StreamError('Alger resolver unavailable', 502);
    }

    const data = await response.json();
    const url = readResolvedUrl(data);
    if (!url) {
      throw new StreamError('Alger resolver returned no playable URL', 404);
    }
    return { url, contentType: 'audio/mpeg' };
  }
}

function songDataFromCandidate(candidate: TrackCandidate): Record<string, unknown> {
  const artists = candidate.artist
    .split(/\s*[/,，、]\s*/)
    .map((name) => name.trim())
    .filter(Boolean)
    .map((name) => ({ id: 0, name }));
  return {
    name: candidate.title,
    artists,
    album: { name: '' },
    ar: artists,
    al: { name: '' },
  };
}

function readResolvedUrl(data: unknown): string | null {
  const topLevel = readSongUrl(data);
  if (topLevel) return topLevel;
  if (!isRecord(data)) return null;
  const nestedData = data.data;
  const nested = readSongUrl(nestedData);
  if (nested) return nested;
  if (isRecord(nestedData)) {
    return readSongUrl(nestedData.data);
  }
  return null;
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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}
