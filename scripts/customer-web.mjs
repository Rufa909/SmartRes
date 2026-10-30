import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import next from 'next';
import './local-config.mjs';
import { networkPolicy, createNetworkGuard } from './customer-network.mjs';

const policy=networkPolicy();
const guard=createNetworkGuard(policy);
const port=3000;
const app=next({dev: !process.argv.includes('--production'),dir:fileURLToPath(new URL('../apps/web',import.meta.url)),hostname:'0.0.0.0',port});
await app.prepare();
const handler=app.getRequestHandler();
const upgrade=app.getUpgradeHandler();
const server=createServer((req,res) => {
  if (guard(req,res)) void handler(req,res);
});
server.on('upgrade',(req,socket,head) => {
  if (!policy.allows(req.socket.remoteAddress)) {socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');return;}
  void upgrade(req,socket,head);
});
server.on('error',error => {console.error('Không mở được web:',error.message);process.exit(1);});
server.listen(port,'0.0.0.0',() => {
  console.log(`SmartRes Web Ready :${port}. Mạng được phép: ${policy.networks.join(', ') || 'chỉ máy này'}.`);
});
const stop=()=>{server.close();void app.close().finally(()=>process.exit(0));};
process.on('SIGINT',stop);
process.on('SIGTERM',stop);
