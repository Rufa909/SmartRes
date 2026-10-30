import { BlockList, isIP } from 'node:net';
import { networkInterfaces } from 'node:os';
import { findLanIpv4 } from './local-config.mjs';

export function networkPolicy(config = process.env.CUSTOMER_ALLOWED_CIDRS, interfaces = networkInterfaces()) {
  const detectedIp = findLanIpv4(interfaces);
  const detected = Object.values(interfaces).flat().find(a => a?.address === detectedIp);
  let networks;
  if (config?.trim()) {
    networks = config.split(',').map(n => n.trim());
  } else if (detected) {
    const prefix = detected.netmask.split('.').reduce((sum, part) => sum + Number(part).toString(2).replaceAll('0','').length, 0);
    networks = [`${detectedIp}/${prefix}`];
  } else {
    networks = [];
  }
  const list = new BlockList();
  for (const network of networks) {
    const [ip, bits, extra] = network.split('/');
    const prefix = Number(bits);
    if (isIP(ip) !== 4 || !/^\d+$/.test(bits || '') || prefix < 8 || prefix > 32 || extra !== undefined) {
      throw new Error(`CUSTOMER_ALLOWED_CIDRS không hợp lệ: ${network}. Ví dụ: 192.168.1.0/24`);
    }
    const [first, second] = ip.split('.').map(Number);
    const privateRange = first === 10 ? 8 : first === 172 && second >= 16 && second <= 31 ? 12 : first === 192 && second === 168 ? 16 : null;
    if (privateRange === null || prefix < privateRange) throw new Error(`Chỉ cho phép dải IPv4 nội bộ trong CUSTOMER_ALLOWED_CIDRS: ${network}`);
    list.addSubnet(ip,prefix,'ipv4');
  }
  return {
    networks,
    allows(address = '') {
      const ip=address.replace(/^::ffff:/i,'');
      // Local tools/proxy on this computer remain available; never trust forwarded headers.
      return ip === '::1' || /^127\./.test(ip) || (isIP(ip) === 4 && list.check(ip,'ipv4'));
    },
  };
}

export function createNetworkGuard(policy, now = Date.now) {
  const attempts = new Map();
  return (req,res) => {
    const address=req.socket.remoteAddress || '';
    if (!policy.allows(address)) {
      res.writeHead(403,{'Content-Type':'text/plain; charset=utf-8','Cache-Control':'no-store'});
      res.end('Hãy kết nối Wi-Fi nhà hàng để truy cập trang gọi món.');
      return false;
    }
    if (req.method === 'POST' && req.url?.split('?')[0] === '/api/customer/customer-sessions/join') {
      const time=now();
      for (const [ip, entry] of attempts) if (entry.resetAt<=time) attempts.delete(ip);
      const entry=attempts.get(address) || {count:0,resetAt:time+60000};
      if (entry.count>=20 || (attempts.size>=10000 && !attempts.has(address))) {
        res.writeHead(429,{'Content-Type':'application/json; charset=utf-8','Retry-After':'60'});
        res.end(JSON.stringify({message:'Bạn thử quá nhiều lần. Vui lòng chờ một phút.'}));
        return false;
      }
      entry.count++;
      attempts.set(address,entry);
    }
    return true;
  };
}
