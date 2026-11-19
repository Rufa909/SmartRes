import 'package:flutter/material.dart';

import 'restaurant_theme.dart';
import 'staff_api.dart';

class StaffMenuChatbot extends StatefulWidget {
  final StaffApi api;
  final Map<String, dynamic> table;
  final List<Map<String, dynamic>> menu;
  final Map<int, int> cart;
  final ValueChanged<int> onAdd;

  const StaffMenuChatbot({
    super.key,
    required this.api,
    required this.table,
    required this.menu,
    required this.cart,
    required this.onAdd,
  });

  @override
  State<StaffMenuChatbot> createState() => _StaffMenuChatbotState();
}

class _StaffMenuChatbotState extends State<StaffMenuChatbot> {
  final input = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;
  final List<Map<String, dynamic>> messages = [
    {
      'role': 'assistant',
      'text': 'Mình có thể giúp nhân viên tư vấn món theo khẩu vị, số khách hoặc kiểm tra giá. Bạn muốn tìm món gì?',
    },
  ];

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  String money(num value) =>
      '${value.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]}.')}đ';

  void scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> send([String? quickMessage]) async {
    final message = (quickMessage ?? input.text).trim();
    if (message.isEmpty || busy) return;
    setState(() {
      busy = true;
      input.clear();
      messages.add({'role': 'user', 'text': message});
    });
    scrollToEnd();
    try {
      final guests = widget.table['guests'];
      final data = await widget.api.chatbot(
        message,
        widget.cart.keys.toList(),
        partySize: guests is int && guests > 0 ? guests : null,
      );
      if (!mounted) return;
      setState(() {
        messages.add({
          'role': 'assistant',
          'text': data['reply'] as String? ?? 'Bạn nói rõ thêm một chút nhé.',
          'provider': data['provider'],
          'suggestions': ((data['suggestions'] as List?) ?? const [])
              .cast<Map<String, dynamic>>(),
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        messages.add({'role': 'assistant', 'text': error.toString()});
      });
    } finally {
      if (mounted) setState(() => busy = false);
      scrollToEnd();
    }
  }

  void addSuggestion(Map<String, dynamic> suggestion) {
    final id = (suggestion['id'] as num).toInt();
    final item = widget.menu.cast<Map<String, dynamic>?>().firstWhere(
      (candidate) => candidate?['id'] == id && candidate?['available'] == true,
      orElse: () => null,
    );
    final name = suggestion['name'] as String? ?? 'Món';
    setState(() {
      if (item == null) {
        messages.add({
          'role': 'assistant',
          'text': '$name vừa ngừng bán nên chưa thể thêm vào giỏ.',
        });
      } else {
        widget.onAdd(id);
        messages.add({
          'role': 'assistant',
          'text': 'Đã thêm $name vào giỏ của bàn ${widget.table['code']}.',
        });
      }
    });
    scrollToEnd();
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .9,
    child: SafeArea(
      child: Material(
        color: const Color(0xFFF7F7FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: ink,
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.auto_awesome, color: brandOrange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trợ lý chọn món',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Bàn ${widget.table['code']} · tư vấn từ menu đang bán',
                          style: const TextStyle(
                            color: Color(0xFFB9C0C8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng trợ lý',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length + (busy ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index == messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Đang xem thực đơn…'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  final message = messages[index];
                  final user = message['role'] == 'user';
                  final suggestions =
                      (message['suggestions'] as List<Map<String, dynamic>>?) ??
                      const [];
                  return Align(
                    alignment: user
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: user ? brandOrange : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: user
                            ? null
                            : Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message['text'] as String,
                            style: TextStyle(
                              color: user ? Colors.white : ink,
                              height: 1.35,
                            ),
                          ),
                          if (!user && message['provider'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                message['provider'] == 'gemini'
                                    ? 'Gemini'
                                    : 'Chế độ dự phòng',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ...suggestions.map(
                            (suggestion) => Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7F3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          suggestion['name'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        money(suggestion['price'] as num),
                                        style: const TextStyle(
                                          color: brandOrange,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((suggestion['reason'] as String? ?? '')
                                      .isNotEmpty)
                                    Text(
                                      suggestion['reason'] as String,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          addSuggestion(suggestion),
                                      icon: const Icon(Icons.add, size: 17),
                                      label: const Text('Thêm vào giỏ'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final quick in const [
                    'Món nào dễ ăn?',
                    'Gợi ý cho nhóm đông',
                    'Có đồ uống gì?',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(quick),
                        onPressed: busy ? null : () => send(quick),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      enabled: !busy,
                      maxLength: 400,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: 'Ví dụ: Khách muốn món ít cay',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Gửi câu hỏi',
                    onPressed: busy ? null : send,
                    icon: const Icon(Icons.send),
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
