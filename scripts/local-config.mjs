import dotenv from 'dotenv';
import { networkInterfaces } from 'node:os';

// Biến môi trường > cấu hình riêng của máy > cấu hình mặc định của dự án.
dotenv.config({ path: new URL('../.env.mysql.local', import.meta.url), quiet: true });
dotenv.config({ path: new URL('../.env', import.meta.url), quiet: true });

export function findLanIpv4(interfaces = networkInterfaces()) {
  const candidates = Object.entries(interfaces)
    .flatMap(([name, addresses]) => (addresses || []).map(address => ({ name, ...address })))
    .filter(address => address.family === 'IPv4' && !address.internal &&
      !address.address.startsWith('169.254.') &&
      !/vpn|radmin|virtual|vethernet|vmware|vbox|wsl|docker|tailscale|zerotier|loopback/i.test(address.name))
    .sort((a, b) => {
      const score = name => /wi-?fi|wireless|wlan/i.test(name) ? 0 : /ethernet|^en\d|^eth\d/i.test(name) ? 1 : 2;
      return score(a.name) - score(b.name);
    });
  return candidates[0]?.address;
}

export function getWebUrl() {
  const url = new URL(process.env.NEXT_PUBLIC_WEB_URL?.trim() ||
    `http://${findLanIpv4() || '127.0.0.1'}:3000`);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password ||
      url.pathname !== '/' || url.search || url.hash) {
    throw new Error('NEXT_PUBLIC_WEB_URL phải là địa chỉ gốc http/https, ví dụ http://192.168.1.15:3000.');
  }
  return url.origin;
}
