Map<String, dynamic> overviewFixture({
  String from = '2026-10-25',
  String to = '2026-10-31',
  num revenue = 500000,
}) => {
  'generatedAt': '2026-10-31T03:15:00Z',
  'period': {'from': from, 'to': to, 'days': 7, 'timezone': 'Asia/Ho_Chi_Minh'},
  'summary': {
    'revenue': revenue,
    'invoiceCount': revenue == 0 ? 0 : 5,
    'averageBill': revenue == 0 ? 0 : 100000,
    'discountAmount': 20000,
    'previousRevenue': 250000,
    'changePercent': 100,
  },
  'operations': {
    'totalTables': 8,
    'availableTables': 5,
    'diningTables': 2,
    'waitingPaymentTables': 1,
    'guests': 9,
    'unpaidAmount': 210000,
    'pendingKitchen': 3,
    'readyToServe': 2,
    'outOfStock': 1,
  },
  'daily': List.generate(
    7,
    (i) => {
      'date': '2026-10-${25 + i}',
      'revenue': i == 6 ? revenue : 0,
      'invoiceCount': i == 6 ? 5 : 0,
    },
  ),
  'topItems': revenue == 0
      ? []
      : [
          {
            'menuItemId': 1,
            'name': 'Cơm chiên hải sản',
            'quantity': 8,
            'grossAmount': 360000,
          },
        ],
  'paymentMethods': revenue == 0
      ? []
      : [
          {'method': 'cash', 'invoiceCount': 5, 'revenue': revenue},
        ],
  'recentInvoices': revenue == 0
      ? []
      : [
          {
            'historyId': 7,
            'invoiceCode': '3110-A01-1000',
            'tableCode': 'A01',
            'totalAmount': 100000,
            'paymentMethod': 'cash',
            'paidAt': '2026-10-31T03:15:00Z',
          },
        ],
};
