import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'restaurant_theme.dart';

class OrderCatalogue extends StatefulWidget {
  final Map<String, dynamic> table;
  final List<Map<String, dynamic>> menu;
  final Map<int, int> cart;
  final bool sending;
  final String? error;
  final num total;
  final void Function(int, int) change;
  final VoidCallback send;
  const OrderCatalogue({
    super.key,
    required this.table,
    required this.menu,
    required this.cart,
    required this.sending,
    required this.total,
    required this.change,
    required this.send,
    this.error,
  });
  @override
  State<OrderCatalogue> createState() => _OrderCatalogueState();
}

class _OrderCatalogueState extends State<OrderCatalogue> {
  final search = TextEditingController();
  String category = 'Tất cả';
  bool cartOnly = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String money(num amount) =>
      '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}đ';
  @override
  Widget build(BuildContext context) {
    final categories = [
      'Tất cả',
      ...widget.menu.map((m) => m['category'] as String? ?? 'Khác').toSet(),
    ];
    final visible = widget.menu
        .where(
          (m) =>
              matchesSearch(m['name'] as String, search.text) &&
              (category == 'Tất cả' || m['category'] == category) &&
              (!cartOnly || (widget.cart[m['id']] ?? 0) > 0),
        )
        .toList();
    final count = widget.cart.values.fold<int>(0, (a, b) => a + b);
    return Theme(
      data: restaurantTheme(),
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nhân viên',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'Gọi món',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    backgroundColor: const Color(0xFFFFF3EF),
                    side: const BorderSide(color: Color(0xFFFFD2C6)),
                    avatar: const Icon(
                      Icons.table_restaurant,
                      size: 18,
                      color: brandOrange,
                    ),
                    label: Text(
                      'Bàn ${widget.table['code']} · ${widget.table['guests']} khách',
                      style: const TextStyle(
                        color: Color(0xFFD84324),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm món, ví dụ: com chien',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xóa tìm kiếm',
                            onPressed: () => setState(search.clear),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, i) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ChoiceChip(
                    label: Text(categories[i]),
                    selected: category == categories[i],
                    onSelected: (_) => setState(() => category = categories[i]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cartOnly ? 'Giỏ đã chọn' : 'Thực đơn',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${visible.length} món',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Đã chọn ($count)'),
                      selected: cartOnly,
                      onSelected: (v) => setState(() {
                        cartOnly = v;
                        category = 'Tất cả';
                        search.clear();
                      }),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có món phù hợp.\nThử từ khóa hoặc danh mục khác.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, size) => GridView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: visible.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: size.maxWidth > 650 ? 4 : 2,
                                mainAxisExtent: 252,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 16,
                              ),
                          itemBuilder: (_, index) {
                            final m = visible[index];
                            final id = m['id'] as int;
                            final qty = widget.cart[id] ?? 0;
                            final available = m['available'] == true;
                            return Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0D0D0F1C),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (m['imageUrl'] is String &&
                                      (m['imageUrl'] as String).isNotEmpty)
                                    Image.network(
                                      m['imageUrl'] as String,
                                      height: 110,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Image.asset(
                                        'assets/figma/imgFoodImageFrame.png',
                                        height: 110,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Image.asset(
                                      'assets/figma/imgFoodImageFrame.png',
                                      height: 110,
                                      fit: BoxFit.cover,
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      0,
                                    ),
                                    child: Text(
                                      m['name'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      money(m['price'] as num),
                                      style: const TextStyle(
                                        color: brandOrange,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (!available)
                                    const SizedBox(
                                      height: 48,
                                      child: Center(
                                        child: Text(
                                          'Hết món',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    )
                                  else
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (qty > 0) ...[
                                          IconButton(
                                            tooltip: 'Giảm ${m['name']}',
                                            onPressed: widget.sending
                                                ? null
                                                : () => widget.change(id, -1),
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                          ),
                                          Text('$qty'),
                                        ],
                                        IconButton(
                                          tooltip: 'Thêm ${m['name']}',
                                          onPressed: widget.sending || qty >= 99
                                              ? null
                                              : () => widget.change(id, 1),
                                          icon: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: const BoxDecoration(
                                              color: brandOrange,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: SvgPicture.asset(
                                              'assets/figma/imgPlus.svg',
                                              width: 16,
                                              height: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
              if (widget.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tạm tính · Bàn ${widget.table['code']}',
                            style: const TextStyle(
                              color: Color(0xFFB9C0C8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            money(widget.total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor: const Color(0xFF59616B),
                        disabledForegroundColor: Colors.white,
                      ),
                      onPressed: widget.sending || count == 0
                          ? null
                          : widget.send,
                      child: Text(widget.sending ? 'Đang gửi…' : 'Gửi món'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
