import type { Source, StreamHandle, TrackCandidate } from '../types.js';

const mockTracks: TrackCandidate[] = [
  {
    title: 'Yellow',
    artist: 'Coldplay',
    duration: 266000,
    version: null,
    sourceInstanceId: 'mock-netease',
    sourceTrackId: 'mock-netease-yellow',
    streamUrl: 'https://example.com/audio/yellow.mp3',
  },
  {
    title: 'Love Story',
    artist: 'Taylor Swift',
    duration: 236000,
    version: null,
    sourceInstanceId: 'mock-netease',
    sourceTrackId: 'mock-netease-love-story',
    streamUrl: 'https://example.com/audio/love-story.mp3',
  },
  {
    title: '晴天',
    artist: '周杰伦',
    duration: 269000,
    version: null,
    sourceInstanceId: 'mock-netease',
    sourceTrackId: 'mock-netease-qingtian',
    streamUrl: 'https://example.com/audio/qingtian.mp3',
  },
];

export class MockNeteaseSource implements Source {
  id = 'mock-netease';

  capabilities = {
    search: true,
    scan: false,
    stream: 'proxy' as const,
  };

  async search(query: string): Promise<TrackCandidate[]> {
    const q = query.trim().toLowerCase();
    if (!q) return mockTracks;
    return mockTracks.filter((track) => {
      return (
        track.title.toLowerCase().includes(q) ||
        track.artist.toLowerCase().includes(q)
      );
    });
  }

  async getStream(candidate: TrackCandidate): Promise<StreamHandle> {
    return {
      url: candidate.streamUrl ?? 'https://example.com/audio/placeholder.mp3',
      contentType: 'audio/mpeg',
    };
  }
}
