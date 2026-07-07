import { timingSafeEqual, randomBytes, scrypt as scryptCallback } from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(scryptCallback);
const keyLength = 64;

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function createSessionToken(): string {
  return randomBytes(32).toString('base64url');
}

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16).toString('base64url');
  const key = (await scrypt(password, salt, keyLength)) as Buffer;
  return `scrypt:${salt}:${key.toString('base64url')}`;
}

export async function verifyPassword(password: string, storedHash: string): Promise<boolean> {
  const [scheme, salt, rawKey] = storedHash.split(':');
  if (scheme !== 'scrypt' || !salt || !rawKey) return false;
  const expected = Buffer.from(rawKey, 'base64url');
  const actual = (await scrypt(password, salt, expected.length)) as Buffer;
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function isValidPassword(password: string): boolean {
  return password.length >= 8 && password.length <= 256;
}
