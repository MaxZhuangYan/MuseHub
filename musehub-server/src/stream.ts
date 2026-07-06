import fs from 'node:fs';
import { Readable } from 'node:stream';
import type { Context } from 'hono';
import type { StreamHandle } from './types.js';

interface RangeSpec {
  start: number;
  end: number;
  partial: boolean;
}

export async function proxyStream(c: Context, handle: StreamHandle): Promise<Response> {
  if (handle.filePath) {
    return streamLocalFile(c, handle);
  }
  if (handle.url) {
    return streamRemoteUrl(c, handle);
  }
  return c.json({ error: 'No stream handle available' }, 502);
}

function streamLocalFile(c: Context, handle: StreamHandle): Response {
  const stat = fs.statSync(handle.filePath!);
  const range = parseRange(c.req.header('range'), stat.size);
  const stream = fs.createReadStream(handle.filePath!, {
    start: range.start,
    end: range.end,
  });
  const headers = new Headers({
    'content-type': handle.contentType ?? 'application/octet-stream',
    'accept-ranges': 'bytes',
    'content-length': String(range.end - range.start + 1),
  });
  if (range.partial) {
    headers.set('content-range', `bytes ${range.start}-${range.end}/${stat.size}`);
  }
  return new Response(Readable.toWeb(stream) as unknown as BodyInit, {
    status: range.partial ? 206 : 200,
    headers,
  });
}

async function streamRemoteUrl(c: Context, handle: StreamHandle): Promise<Response> {
  const headers = new Headers();
  const range = c.req.header('range');
  if (range) headers.set('range', range);

  const upstream = await fetch(handle.url!, { headers });
  if (!upstream.ok && upstream.status !== 206) {
    return c.json({ error: 'Upstream stream unavailable' }, 502);
  }

  const responseHeaders = new Headers();
  responseHeaders.set(
    'content-type',
    upstream.headers.get('content-type') ?? handle.contentType ?? 'application/octet-stream',
  );
  responseHeaders.set('accept-ranges', 'bytes');
  copyHeader(upstream.headers, responseHeaders, 'content-length');
  copyHeader(upstream.headers, responseHeaders, 'content-range');

  return new Response(upstream.body, {
    status: upstream.status === 206 ? 206 : 200,
    headers: responseHeaders,
  });
}

function parseRange(header: string | undefined, size: number): RangeSpec {
  if (!header) {
    return { start: 0, end: size - 1, partial: false };
  }
  const match = /^bytes=(\d*)-(\d*)$/.exec(header);
  if (!match) {
    return { start: 0, end: size - 1, partial: false };
  }
  const [, rawStart, rawEnd] = match;
  if (!rawStart && !rawEnd) {
    return { start: 0, end: size - 1, partial: false };
  }
  if (!rawStart) {
    const suffixLength = Number(rawEnd);
    const start = Math.max(size - suffixLength, 0);
    return { start, end: size - 1, partial: true };
  }
  const start = Math.min(Number(rawStart), size - 1);
  const end = rawEnd ? Math.min(Number(rawEnd), size - 1) : size - 1;
  return { start, end: Math.max(start, end), partial: true };
}

function copyHeader(from: Headers, to: Headers, name: string): void {
  const value = from.get(name);
  if (value) to.set(name, value);
}
