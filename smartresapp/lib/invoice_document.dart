import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const paymentMethods = {
  'cash': 'Tiền mặt',
  'bank_transfer': 'Chuyển khoản',
  'card': 'Thẻ',
};

String invoiceMoney(num value) =>
    '${value.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} đ';

String invoiceDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return '—';
  // Nhà hàng sử dụng giờ Việt Nam, kể cả khi thiết bị ở múi giờ khác.
  final local = date.toUtc().add(const Duration(hours: 7));
  String pad(int v) => v.toString().padLeft(2, '0');
  return '${pad(local.day)}/${pad(local.month)}/${local.year} '
      '${pad(local.hour)}:${pad(local.minute)}:${pad(local.second)}';
}

// Giấy cuộn 80 mm, chiều dài được tính từ nội dung sau khi dàn trang.
const receiptPaperFormat = PdfPageFormat(
  80 * PdfPageFormat.mm,
  double.infinity,
  marginAll: 4 * PdfPageFormat.mm,
);

Future<({Uint8List bytes, PdfPageFormat format})> _buildReceipt(
  Map<String, dynamic> invoice,
) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: receiptPaperFormat,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (_) => pw.DefaultTextStyle(
        style: pw.TextStyle(font: font, fontSize: 9),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                'SmartRes',
                style: const pw.TextStyle(fontSize: 16),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'PHIẾU THANH TOÁN',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Số bill: ${invoice['invoiceCode']}'),
            pw.Text(
              'Bàn ${invoice['tableCode']} • ${invoice['guests'] ?? '—'} khách',
            ),
            pw.Text('Ngày: ${invoiceDate(invoice['issuedAt'])}'),
            pw.Divider(thickness: 0.5, height: 14),
            pw.Row(
              children: [
                pw.Expanded(child: pw.Text('Món / SL x Đơn giá')),
                pw.Text('Thành tiền'),
              ],
            ),
            pw.Divider(thickness: 0.5, height: 10),
            ...(invoice['items'] as List).map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 7),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(item['name'] as String),
                    if ((item['note'] as String? ?? '').isNotEmpty)
                      pw.Text(
                        'Ghi chú: ${item['note']}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${item['quantity']} x ${invoiceMoney(item['unitPrice'] as num)}',
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(invoiceMoney(item['lineTotal'] as num)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            pw.Divider(thickness: 0.5, height: 12),
            if (((invoice['discountAmount'] as num?) ?? 0) > 0) ...[
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Tiền món')),
                  pw.Text(
                    invoiceMoney(
                      (invoice['subtotalAmount'] as num?) ??
                          invoice['totalAmount'] as num,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Giảm giá (${invoice['discountPercentage']}%)',
                    ),
                  ),
                  pw.Text('-${invoiceMoney(invoice['discountAmount'] as num)}'),
                ],
              ),
              if (invoice['voucherCode'] != null)
                pw.Text('Voucher: ${invoice['voucherCode']}'),
              pw.SizedBox(height: 8),
            ],
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'TỔNG CỘNG',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
                pw.Text(
                  invoiceMoney(invoice['totalAmount'] as num),
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Thanh toán: ${paymentMethods[invoice['paymentMethod']] ?? 'Chưa chọn'}',
            ),
            pw.Text(
              invoice['paymentStatus'] == 'paid'
                  ? 'Đã thanh toán'
                  : 'Chưa thanh toán',
            ),
            pw.Divider(thickness: 0.5, height: 16),
            pw.Center(child: pw.Text('Cảm ơn quý khách!')),
            pw.Center(child: pw.Text('Hẹn gặp lại.')),
          ],
        ),
      ),
    ),
  );
  final bytes = await document.save();
  // Dùng kích thước hữu hạn đã đo, không gửi chiều cao infinity cho driver in.
  return (bytes: bytes, format: document.document.page(0)!.pageFormat);
}

Future<Uint8List> buildInvoicePdf(Map<String, dynamic> invoice) async =>
    (await _buildReceipt(invoice)).bytes;

Future<void> printInvoice(Map<String, dynamic> invoice) async {
  final receipt = await _buildReceipt(invoice);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // Android của plugin printing thay giấy cuộn bằng UNKNOWN_PORTRAIT.
    // Gửi kích thước thật tới adapter riêng để preview không bị dư bên phải.
    await const MethodChannel('smartres/receipt_printing')
        .invokeMethod<void>('printReceipt', {
          'name': '${invoice['invoiceCode']}.pdf',
          'bytes': receipt.bytes,
          'width': receipt.format.width,
          'height': receipt.format.height,
        });
    return;
  }
  await Printing.layoutPdf(
    name: '${invoice['invoiceCode']}.pdf',
    format: receipt.format,
    dynamicLayout: false,
    forceCustomPrintPaper: true,
    onLayout: (_) async => receipt.bytes,
  );
}
