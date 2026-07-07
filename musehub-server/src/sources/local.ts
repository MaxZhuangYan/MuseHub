import fs from 'node:fs';
import path from 'node:path';
import { StreamError, type Source, type StreamHandle, type TrackCandidate } from '../types.js';

const supportedExtensions = new Set(['.mp3', '.flac', '.m4a', '.aac', '.ogg', '.wav']);

export class LocalSource implements Source {
  id = 'local';

  capabilities = {
    search: true,
    scan: true,
    stream: 'proxy' as const,
  };

  constructor(private readonly musicDir: string) {}

  async search(query: string): Promise<TrackCandidate[]> {
    const q = query.trim().toLowerCase();
    const results: TrackCandidate[] = [];
    for await (const candidate of this.scan()) {
      if (
        !q ||
        candidate.title.toLowerCase().includes(q) ||
        candidate.artist.toLowerCase().includes(q)
      ) {
        results.push(candidate);
      }
    }
    return results.slice(0, 50);
  }

  async *scan(): AsyncIterable<TrackCandidate> {
    if (!fs.existsSync(this.musicDir)) return;
    const files = walkMusicFiles(this.musicDir);
    for (const filePath of files) {
      yield candidateFromFile(this.musicDir, filePath);
    }
  }

  async getStream(candidate: TrackCandidate): Promise<StreamHandle> {
    const absolutePath = path.resolve(this.musicDir, candidate.sourceTrackId);
    const root = path.resolve(this.musicDir);
    if (absolutePath !== root && !absolutePath.startsWith(root + path.sep)) {
      throw new StreamError('Invalid local source path', 400);
    }
    if (!fs.existsSync(absolutePath)) {
      throw new StreamError('Local source file not found', 404);
    }
    const stat = fs.statSync(absolutePath);
    if (!stat.isFile()) {
      throw new StreamError('Local source path is not a file', 400);
    }
    return {
      filePath: absolutePath,
      contentLength: stat.size,
      contentType: contentTypeForPath(absolutePath),
    };
  }
}

function walkMusicFiles(root: string): string[] {
  const results: string[] = [];
  const stack = [root];
  while (stack.length > 0) {
    const current = stack.pop();
    if (!current) continue;
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const entryPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(entryPath);
      } else if (supportedExtensions.has(path.extname(entry.name).toLowerCase())) {
        results.push(entryPath);
      }
    }
  }
  return results.sort();
}

function candidateFromFile(root: string, filePath: string): TrackCandidate {
  const relativePath = path.relative(root, filePath);
  const fileName = path.basename(filePath, path.extname(filePath));
  const parsed = parseName(fileName);
  return {
    title: parsed.title,
    artist: parsed.artist,
    duration: null,
    version: null,
    sourceInstanceId: 'local',
    sourceTrackId: relativePath,
  };
}

function parseName(fileName: string): { title: string; artist: string } {
  const normalized = fileName.replace(/[_]+/g, ' ').trim();
  const separators = [' - ', ' – ', ' — '];
  for (const separator of separators) {
    if (normalized.includes(separator)) {
      const [artist, ...titleParts] = normalized.split(separator);
      const title = titleParts.join(separator).trim();
      if (artist.trim() && title) {
        return { artist: artist.trim(), title };
      }
    }
  }
  return { artist: 'Unknown Artist', title: normalized || 'Unknown Title' };
}

function contentTypeForPath(filePath: string): string {
  switch (path.extname(filePath).toLowerCase()) {
    case '.flac':
      return 'audio/flac';
    case '.m4a':
      return 'audio/mp4';
    case '.aac':
      return 'audio/aac';
    case '.ogg':
      return 'audio/ogg';
    case '.wav':
      return 'audio/wav';
    default:
      return 'audio/mpeg';
  }
}
