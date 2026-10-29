import test from 'node:test';
import assert from 'node:assert/strict';
import { invoiceCode } from '../src/invoice.js';

test('Mã hóa đơn dùng ngày tháng và giờ nhận bàn ở Việt Nam, không có năm', () => {
  assert.equal(invoiceCode('A02', new Date('2026-10-28T12:30:00Z')), '2810-A02-1930');
  assert.equal(invoiceCode('B01', new Date('2026-12-31T17:05:09Z')), '0101-B01-0005');
});
