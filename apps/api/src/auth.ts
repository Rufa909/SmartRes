import { createHmac, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

export type Role = 'staff' | 'kitchen' | 'manager';
export type AuthUser = { id: number; username: string; displayName: string; role: Role };

const secret = process.env.SMARTRES_AUTH_SECRET || 'smartres-dev-secret-change-me';
const encode = (value: string) => Buffer.from(value).toString('base64url');
const decode = (value: string) => Buffer.from(value, 'base64url').toString('utf8');

export function hashPassword(password: string, salt = randomBytes(16).toString('hex')) {
  return `${salt}:${scryptSync(password, salt, 64).toString('hex')}`;
}

export function verifyPassword(password: string, stored: string) {
  const [salt, expected] = stored.split(':');
  if (!salt || !expected) return false;
  const actual = scryptSync(password, salt, 64).toString('hex');
  return actual.length === expected.length && timingSafeEqual(Buffer.from(actual), Buffer.from(expected));
}

export function createToken(user: AuthUser) {
  const payload = encode(JSON.stringify({ ...user, exp: Math.floor(Date.now() / 1000) + 60 * 60 * 12 }));
  const signature = createHmac('sha256', secret).update(payload).digest('base64url');
  return `${payload}.${signature}`;
}

export function readToken(token: string): AuthUser | null {
  try {
    const [payload, signature] = token.split('.');
    if (!payload || !signature) return null;
    const expected = createHmac('sha256', secret).update(payload).digest('base64url');
    if (signature.length !== expected.length || !timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) return null;
    const data = JSON.parse(decode(payload)) as AuthUser & { exp?: number };
    if (!data.exp || data.exp < Math.floor(Date.now() / 1000)) return null;
    if (!data.id || !data.username || !['staff', 'kitchen', 'manager'].includes(data.role)) return null;
    return data;
  } catch { return null; }
}
