export interface NormalizedMetadata {
  normalizedTitle: string;
  normalizedArtist: string;
}

const keptVersionTerms = new Set([
  'live',
  'remaster',
  'acoustic',
  'demo',
  'instrumental',
  '伴奏',
  '纯音乐',
]);

export function normalizeTrackMetadata(
  title: string,
  artist: string,
): NormalizedMetadata {
  return {
    normalizedTitle: normalizeText(title),
    normalizedArtist: normalizeText(artist),
  };
}

function normalizeText(value: string): string {
  const simplified = toSimplifiedChinese(value.normalize('NFKC'));
  return simplified
    .toLowerCase()
    .replace(/\b(feat|ft|with)\.?\b/gi, ' ')
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .split(/\s+/)
    .filter((part) => part.length > 0)
    .filter((part) => keptVersionTerms.has(part) || !isJoinerToken(part))
    .join(' ')
    .trim();
}

function isJoinerToken(value: string): boolean {
  return value === 'feat' || value === 'ft' || value === 'with';
}

function toSimplifiedChinese(value: string): string {
  // Production deployment can swap this stub for OpenCC. V0 keeps no native
  // dependency so the server runs with only npm install.
  const map: Record<string, string> = {
    體: '体',
    樂: '乐',
    裡: '里',
    佇: '伫',
    愛: '爱',
    聽: '听',
    無: '无',
    會: '会',
    雲: '云',
    電: '电',
    後: '后',
    與: '与',
  };
  return value.replace(/[體樂裡佇愛聽無會雲電後與]/g, (char) => map[char] ?? char);
}
