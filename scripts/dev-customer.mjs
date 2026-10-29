import { spawn, spawnSync } from 'node:child_process';
import { createConnection } from 'node:net';

function npmCommand(args) {
  if (process.platform === 'win32') {
    return {
      command: process.env.ComSpec || 'cmd.exe',
      args: ['/d', '/s', '/c', ['npm', ...args].join(' ')]
    };
  }
  return { command: 'npm', args };
}

function isPortOpen(port) {
  return new Promise((resolve) => {
    const socket = createConnection({ host: '127.0.0.1', port });
    const finish = (open) => {
      socket.destroy();
      resolve(open);
    };
    socket.setTimeout(1000);
    socket.once('connect', () => finish(true));
    socket.once('timeout', () => finish(false));
    socket.once('error', () => finish(false));
  });
}

const qrCommand = npmCommand(['run', 'generate:qr']);
const qr = spawnSync(qrCommand.command, qrCommand.args, {
  cwd: process.cwd(),
  stdio: 'inherit'
});

if (qr.status !== 0) {
  console.error('\nKhông thể tạo QR. Hãy kiểm tra .env, MySQL và chạy npm run setup:customer trước.');
  process.exit(qr.status ?? 1);
}

const definitions = [
  { name: 'Customer API', port: 4010, args: ['run', 'dev:customer-api'] },
  { name: 'Customer Web', port: 3000, args: ['run', 'dev:web'] }
];
const services = [];

for (const definition of definitions) {
  if (await isPortOpen(definition.port)) {
    console.log(`${definition.name} đã chạy ở cổng ${definition.port}; dùng lại dịch vụ hiện có.`);
    continue;
  }
  const command = npmCommand(definition.args);
  services.push(spawn(command.command, command.args, {
    cwd: process.cwd(), stdio: 'inherit'
  }));
}

if (!services.length) {
  console.log('Customer API và Web đều đã sẵn sàng.');
  process.exit(0);
}

let stopping = false;
function stop(exitCode = 0) {
  if (stopping) return;
  stopping = true;
  for (const service of services) {
    if (!service.killed) service.kill('SIGTERM');
  }
  setTimeout(() => process.exit(exitCode), 250).unref();
}

for (const service of services) {
  service.on('error', (error) => {
    console.error('Không thể khởi động dịch vụ:', error.message);
    stop(1);
  });
  service.on('exit', (code, signal) => {
    if (!stopping) {
      console.error(`Một dịch vụ đã dừng (${signal || `mã ${code ?? 1}`}).`);
      stop(code ?? 1);
    }
  });
}

process.on('SIGINT', () => stop(0));
process.on('SIGTERM', () => stop(0));

console.log('\nĐang chạy Customer API + Web. Nhấn Ctrl+C để dừng cả hai.');
