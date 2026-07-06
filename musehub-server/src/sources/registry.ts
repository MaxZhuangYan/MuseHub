import type { Source } from '../types.js';

export class SourceRegistry {
  private readonly sources = new Map<string, Source>();

  register(source: Source): void {
    this.sources.set(source.id, source);
  }

  get(id: string): Source | undefined {
    return this.sources.get(id);
  }

  all(): Source[] {
    return [...this.sources.values()];
  }

  searchable(): Source[] {
    return this.all().filter((source) => source.capabilities.search);
  }
}
