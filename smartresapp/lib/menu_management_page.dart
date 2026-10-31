import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'restaurant_theme.dart';

String _money(num value) =>
    '${value.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} đ';

class MenuManagementPage extends StatefulWidget {
  final StaffApi api;
  const MenuManagementPage({super.key, required this.api});
  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage> {
  List<Map<String, dynamic>> items = [], categories = [];
  bool loading = true, busy = false;
  String? error;
  String query = '', status = 'Tất cả';
  int? categoryId;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.api.managedMenu();
      if (!mounted) return;
      setState(() {
        items = (data['items'] as List).cast<Map<String, dynamic>>();
        categories = (data['categories'] as List).cast<Map<String, dynamic>>();
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> availability(Map<String, dynamic> item, bool value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.api.setMenuAvailability(
        item['id'] as int,
        item['version'] as int,
        value,
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      await load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editItem([Map<String, dynamic>? item]) async {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hãy thêm danh mục trước.')));
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MenuItemEditor(api: widget.api, categories: categories, item: item),
      ),
    );
    if (changed == true) await load();
  }

  Future<void> editCategory([Map<String, dynamic>? category]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryEditor(api: widget.api, category: category),
      ),
    );
    if (changed == true) await load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = items
        .where(
          (i) =>
              matchesSearch(i['name'] as String, query) &&
              (categoryId == null || i['categoryId'] == categoryId) &&
              (status == 'Tất cả' ||
                  (i['available'] == true) == (status == 'Còn bán')),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý thực đơn'),
        actions: [
          IconButton(
            tooltip: 'Tải lại thực đơn',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy || loading || error != null ? null : () => editItem(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm món'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(error!, style: const TextStyle(color: Colors.red)),
                        TextButton(
                          onPressed: load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      labelText: 'Tìm món',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final value in ['Tất cả', 'Còn bán', 'Hết món'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(value),
                            selected: status == value,
                            onSelected: (_) => setState(() => status = value),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int?>(
                          isExpanded: true,
                          value: categoryId,
                          hint: const Text('Tất cả danh mục'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Tất cả danh mục'),
                            ),
                            ...categories.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c['id'] as int,
                                child: Text(
                                  c['name'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => categoryId = v),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Thêm danh mục',
                        onPressed: busy || error != null
                            ? null
                            : () => editCategory(),
                        icon: const Icon(Icons.create_new_folder_outlined),
                      ),
                      IconButton(
                        tooltip: 'Sửa danh mục đang chọn',
                        onPressed: categoryId == null || busy || error != null
                            ? null
                            : () => editCategory(
                                categories.firstWhere(
                                  (c) => c['id'] == categoryId,
                                ),
                              ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('Chưa có món phù hợp.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final item = visible[index];
                            final category = categories
                                .where((c) => c['id'] == item['categoryId'])
                                .firstOrNull;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: MenuPhoto(
                                            url: item['imageUrl'] as String?,
                                            emoji:
                                                item['emoji'] as String? ??
                                                '🍽️',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'] as String,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                ),
                                              ),
                                              Text(
                                                category?['name'] as String? ??
                                                    'Danh mục',
                                              ),
                                              Text(
                                                _money(item['price'] as num),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Sửa ${item['name']}',
                                          onPressed: busy || error != null
                                              ? null
                                              : () => editItem(item),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['available'] == true
                                                ? 'Đang bán'
                                                : 'Hết món',
                                            style: TextStyle(
                                              color: item['available'] == true
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: item['available'] == true,
                                          onChanged: busy || error != null
                                              ? null
                                              : (v) => availability(item, v),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class MenuPhoto extends StatelessWidget {
  final String? url;
  final String emoji;
  const MenuPhoto({super.key, this.url, required this.emoji});
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 68,
      height: 68,
      color: const Color(0xFFFFF1EB),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 32)),
    );
    return url == null || url!.isEmpty
        ? fallback
        : Image.network(
            url!,
            width: 68,
            height: 68,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
  }
}

class MenuItemEditor extends StatefulWidget {
  final StaffApi api;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? item;
  const MenuItemEditor({
    super.key,
    required this.api,
    required this.categories,
    this.item,
  });
  @override
  State<MenuItemEditor> createState() => _MenuItemEditorState();
}

class _MenuItemEditorState extends State<MenuItemEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, price, description, image, emoji;
  late int categoryId;
  late bool available;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final i = widget.item;
    name = TextEditingController(text: i?['name'] as String? ?? '');
    price = TextEditingController(
      text: i == null ? '' : (i['price'] as num).toInt().toString(),
    );
    description = TextEditingController(
      text: i?['description'] as String? ?? '',
    );
    image = TextEditingController(text: i?['imageUrl'] as String? ?? '');
    emoji = TextEditingController(text: i?['emoji'] as String? ?? '🍽️');
    categoryId =
        i?['categoryId'] as int? ?? widget.categories.first['id'] as int;
    available = i?['available'] as bool? ?? true;
  }

  @override
  void dispose() {
    for (final c in [name, price, description, image, emoji]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.saveMenuItem({
        'name': name.text.trim(),
        'price': int.parse(price.text.trim()),
        'description': description.text.trim(),
        'imageUrl': image.text.trim(),
        'emoji': emoji.text.trim(),
        'categoryId': categoryId,
        'available': available,
        if (widget.item != null) 'version': widget.item!['version'],
      }, id: widget.item?['id'] as int?);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Thêm món' : 'Sửa món')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: name,
              enabled: !saving,
              decoration: const InputDecoration(labelText: 'Tên món'),
              maxLength: 160,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nhập tên món.' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: categoryId,
              decoration: const InputDecoration(labelText: 'Danh mục'),
              items: widget.categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id'] as int,
                      child: Text(
                        c['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: saving ? null : (v) => setState(() => categoryId = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: price,
              enabled: !saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá bán (đồng)',
                hintText: 'Ví dụ: 45000',
              ),
              validator: (v) {
                final p = int.tryParse(v?.trim() ?? '');
                return p == null || p < 0 || p > 999999999
                    ? 'Nhập số nguyên từ 0 đến 999999999.'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: description,
              enabled: !saving,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            TextFormField(
              controller: image,
              enabled: !saving,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Link ảnh (http/https)',
                hintText: 'Có thể để trống',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final u = Uri.tryParse(v.trim());
                return u == null ||
                        !['http', 'https'].contains(u.scheme) ||
                        u.host.isEmpty ||
                        u.userInfo.isNotEmpty
                    ? 'Nhập link ảnh http/https hợp lệ.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: MenuPhoto(url: image.text.trim(), emoji: emoji.text),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emoji,
              enabled: !saving,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'Biểu tượng dự phòng',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nhập biểu tượng.' : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Đang bán'),
              subtitle: const Text('Tắt khi món hết hoặc tạm ngừng phục vụ.'),
              value: available,
              onChanged: saving ? null : (v) => setState(() => available = v),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Đang lưu...' : 'Lưu món'),
            ),
          ],
        ),
      ),
    ),
  );
}

class CategoryEditor extends StatefulWidget {
  final StaffApi api;
  final Map<String, dynamic>? category;
  const CategoryEditor({super.key, required this.api, this.category});
  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, sort;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: widget.category?['name'] as String? ?? '',
    );
    sort = TextEditingController(text: '${widget.category?['sortOrder'] ?? 0}');
  }

  @override
  void dispose() {
    name.dispose();
    sort.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.saveMenuCategory({
        'name': name.text.trim(),
        'sortOrder': int.parse(sort.text.trim()),
        if (widget.category != null) 'version': widget.category!['version'],
      }, id: widget.category?['id'] as int?);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Thêm danh mục' : 'Sửa danh mục'),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: name,
              enabled: !saving,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Tên danh mục'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nhập tên danh mục.' : null,
            ),
            TextFormField(
              controller: sort,
              enabled: !saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Thứ tự hiển thị'),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return n == null || n < 0 || n > 9999
                    ? 'Nhập số từ 0 đến 9999.'
                    : null;
              },
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Đang lưu...' : 'Lưu danh mục'),
            ),
          ],
        ),
      ),
    ),
  );
}
