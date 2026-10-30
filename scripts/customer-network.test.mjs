import test from 'node:test';
import assert from 'node:assert/strict';
import {networkPolicy,createNetworkGuard} from './customer-network.mjs';
import {findLanIpv4} from './local-config.mjs';
import {createServer} from 'node:http';
import {once} from 'node:events';

test('Đổi danh sách mạng, xử lý IPv4-mapped và chặn mạng ngoài',()=>{
  const first=networkPolicy('192.168.1.0/24',{});
  assert.equal(first.allows('192.168.1.20'),true);
  assert.equal(first.allows('::ffff:192.168.1.20'),true);
  assert.equal(first.allows('192.168.2.20'),false);
  assert.equal(first.allows('26.1.2.3'),false);
  const second=networkPolicy('192.168.2.0/24,10.20.0.0/16',{});
  assert.equal(second.allows('192.168.1.20'),false);
  assert.equal(second.allows('192.168.2.20'),true);
  assert.equal(second.allows('10.20.1.8'),true);
  assert.equal(second.allows('127.0.0.1'),true);
});
test('Tự nhận đúng netmask và mặc định chặn khi không có LAN',()=>{
  const policy=networkPolicy('',{'Wi-Fi':[{family:'IPv4',internal:false,address:'192.168.8.20',netmask:'255.255.255.128'}]});
  assert.equal(policy.allows('192.168.8.126'),true);
  assert.equal(policy.allows('192.168.8.130'),false);
  assert.equal(networkPolicy('',{}).allows('192.168.1.20'),false);
});
test('Cấu hình sai hoặc mở toàn Internet bị từ chối',()=>{
  for (const cidr of ['0.0.0.0/0','192.168.1.0/99','192.168.1.0','bad/24','8.8.8.0/24','192.168.0.0/8']) {
    assert.throws(()=>networkPolicy(cidr,{}));
  }
});
test('Giả X-Forwarded-For không vượt kiểm tra IP; giới hạn xin phiên QR',()=>{
  const guard=createNetworkGuard(networkPolicy('192.168.1.0/24',{}),()=>1000);
  let status=0;
  const res={writeHead(code){status=code;},end(){}};
  assert.equal(guard({socket:{remoteAddress:'26.1.2.3'},headers:{'x-forwarded-for':'192.168.1.20'},method:'GET',url:'/'},res),false);
  assert.equal(status,403);
  const req={socket:{remoteAddress:'192.168.1.20'},method:'POST',url:'/api/customer/customer-sessions/join'};
  for(let i=0;i<20;i++) assert.equal(guard(req,res),true);
  assert.equal(guard(req,res),false);
  assert.equal(status,429);
});

test('HTTP thực: chặn kết nối LAN ngoài dải cấu hình kể cả giả header IP',async t=>{
  const lan=findLanIpv4();
  if (!lan) {t.skip('Máy không có IPv4 LAN để kiểm tra socket thật');return;}
  const configured=lan==='10.255.255.254'?'192.168.255.254':'10.255.255.254';
  const guard=createNetworkGuard(networkPolicy(`${configured}/32`,{}));
  const server=createServer((req,res)=>{if(guard(req,res))res.end('ok');});
  server.listen(0,'0.0.0.0');await once(server,'listening');
  const port=server.address().port;
  try {
    assert.equal((await fetch(`http://127.0.0.1:${port}`)).status,200);
    assert.equal((await fetch(`http://${lan}:${port}`,{headers:{'X-Forwarded-For':configured,'X-Real-IP':configured}})).status,403);
  } finally {await new Promise(resolve=>server.close(resolve));}
});
