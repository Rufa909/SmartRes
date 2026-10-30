import test from 'node:test';
import assert from 'node:assert/strict';
import { findLanIpv4, getWebUrl } from './local-config.mjs';

const address = ip => [{ family: 'IPv4', internal: false, address: ip }];
test('Chọn Wi-Fi thay cho Radmin VPN và adapter ảo', () => {
  assert.equal(findLanIpv4({
    'Radmin VPN': address('26.1.2.3'),
    'vEthernet (WSL)': address('172.20.0.1'),
    Ethernet: address('169.254.1.2'),
    'Wi-Fi': address('192.168.1.15'),
  }), '192.168.1.15');
});
test('Dùng Ethernet nếu không có Wi-Fi và không chọn VPN khi chỉ có VPN', () => {
  assert.equal(findLanIpv4({Ethernet: address('10.0.0.8')}), '10.0.0.8');
  assert.equal(findLanIpv4({'Radmin VPN': address('26.1.2.3')}), undefined);
});
test('Cho phép ghi đè URL và từ chối URL không hợp lệ', () => {
  const previous = process.env.NEXT_PUBLIC_WEB_URL;
  try {
    process.env.NEXT_PUBLIC_WEB_URL = 'http://192.168.5.10:3000/';
    assert.equal(getWebUrl(), 'http://192.168.5.10:3000');
    for (const value of ['file:///tmp', 'http://host/order/A01', 'http://user:pass@host']) {
      process.env.NEXT_PUBLIC_WEB_URL = value;
      assert.throws(() => getWebUrl());
    }
  } finally {
    if (previous === undefined) delete process.env.NEXT_PUBLIC_WEB_URL;
    else process.env.NEXT_PUBLIC_WEB_URL = previous;
  }
});
