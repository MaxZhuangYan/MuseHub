export type BindingStatus = 'available' | 'dead' | 'unknown';
export type StreamMode = 'proxy' | 'direct';

export interface TrackCandidate {
  title: string;
  artist: string;
  duration?: number | null;
  sourceInstanceId: string;
  sourceTrackId: string;
  version?: string | null;
  streamUrl?: string | null;
}

export interface StreamHandle {
  url?: string;
  filePath?: string;
  contentType?: string;
  contentLength?: number;
}

export interface Source {
  id: string;
  capabilities: {
    search: boolean;
    scan: boolean;
    stream: StreamMode;
  };
  search(query: string): Promise<TrackCandidate[]>;
  getStream(candidate: TrackCandidate): Promise<StreamHandle>;
  scan?(): AsyncIterable<TrackCandidate>;
}

export interface ResolvedTrack {
  id: string;
  title: string;
  artist: string;
  normalizedTitle: string;
  normalizedArtist: string;
  duration: number | null;
  version: string | null;
}

export interface SourceBinding {
  id: string;
  trackId: string;
  sourceInstanceId: string;
  sourceTrackId: string;
  status: BindingStatus;
  priority: number;
  matchConfidence: number;
  lastVerifiedAt: string | null;
}

export interface User {
  id: string;
  email: string;
  passwordHash: string;
  displayName: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface PublicUser {
  id: string;
  email: string;
  displayName: string | null;
  createdAt: string;
}
