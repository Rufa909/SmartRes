import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'restaurant_theme.dart';
import 'staff_api.dart';

const employeeRoleLabels = {
  'staff': 'Nhân viên',
  'kitchen': 'Bếp',
  'cashier': 'Thu ngân',
};

class PersonnelManagementPage extends StatefulWidget {
  final StaffApi api;
  const PersonnelManagementPage({super.key, required this.api});
  @override
  State<PersonnelManagementPage> createState() =>
      _PersonnelManagementPageState();
}

class _PersonnelManagementPageState extends State<PersonnelManagementPage> {
  List<Map<String, dynamic>> users = [];
  bool loading = true, fetching = false, deleting = false;
  String query = '', role = 'all';
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (fetching) return;
    setState(() => fetching = true);
    try {
      final data = await widget.api.managedUsers();
      if (!mounted) return;
      setState(() {
        users = (data['users'] as List).cast<Map<String, dynamic>>();
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          fetching = false;
        });
      }
    }
  }

  Future<void> edit({Map<String, dynamic>? account, bool reset = false}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _AccountEditor(api: widget.api, account: account, reset: reset),
    );
    if (!mounted || result == null) return;
    await load();
    if (!mounted) return;
    if (result['password'] != null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(reset ? 'Đã cấp lại mật khẩu' : 'Đã tạo tài khoản'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Giao thông tin sau cho nhân sự. Mật khẩu chỉ hiển thị trong lần cấp này.',
              ),
              const SizedBox(height: 16),
              SelectableText('Tên đăng nhập: ${result['username']}'),
              const SizedBox(height: 8),
              SelectableText('Mật khẩu: ${result['password']}'),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        'Tên đăng nhập: ${result['username']}\nMật khẩu: ${result['password']}',
                  ),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép thông tin đăng nhập.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật tài khoản.')));
    }
  }

  Future<void> remove(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: Text(
          'Xóa tài khoản ${account['username']} của ${account['displayName']}? Tài khoản sẽ không thể đăng nhập. Các dữ liệu nghiệp vụ đã tạo được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => deleting = true);
    try {
      await widget.api.deleteEmployee(
        account['id'] as int,
        account['version'] as int,
      );
      if (!mounted) return;
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã xóa tài khoản.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = users
        .where(
          (u) =>
              (role == 'all' || u['role'] == role) &&
              matchesSearch('${u['username']} ${u['displayName']}', query),
        )
        .toList();
    return Theme(
      data: restaurantTheme(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý nhân sự'),
          actions: [
            IconButton(
              tooltip: 'Tải lại nhân sự',
              onPressed: fetching || deleting ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: loading || deleting ? null : () => edit(),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Thêm tài khoản'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : AbsorbPointer(
                absorbing: deleting,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: RefreshIndicator(
                      onRefresh: load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (fetching || deleting)
                            const LinearProgressIndicator(),
                          if (error != null)
                            MaterialBanner(
                              content: Text(error!),
                              actions: [
                                TextButton(
                                  onPressed: load,
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          Text(
                            '${users.length} tài khoản nhân sự',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: (value) => setState(() => query = value),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Tìm họ tên hoặc tên đăng nhập',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final entry in {
                                'all': 'Tất cả',
                                ...employeeRoleLabels,
                              }.entries)
                                ChoiceChip(
                                  label: Text(entry.value),
                                  selected: role == entry.key,
                                  onSelected: (_) =>
                                      setState(() => role = entry.key),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (visible.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                users.isEmpty
                                    ? 'Chưa có tài khoản nhân sự. Bấm Thêm tài khoản để bắt đầu.'
                                    : 'Không tìm thấy tài khoản phù hợp.',
                              ),
                            ),
                          for (final account in visible)
                            Card(
                              color: Colors.white,
                              child: ListTile(
                                key: ValueKey('employee-${account['id']}'),
                                leading: const CircleAvatar(
                                  child: Icon(Icons.badge_outlined),
                                ),
                                title: Text(account['displayName'] as String),
                                subtitle: Text(
                                  '${account['username']} · ${employeeRoleLabels[account['role']]}',
                                ),
                                onTap: () => edit(account: account),
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Thao tác ${account['username']}',
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      edit(account: account);
                                    }
                                    if (action == 'password') {
                                      edit(account: account, reset: true);
                                    }
                                    if (action == 'delete') {
                                      remove(account);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Sửa tài khoản'),
                                    ),
                                    PopupMenuItem(
                                      value: 'password',
                                      child: Text('Cấp lại mật khẩu'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Xóa tài khoản'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _AccountEditor extends StatefulWidget {
  final StaffApi api;
  final Map<String, dynamic>? account;
  final bool reset;
  const _AccountEditor({required this.api, this.account, this.reset = false});
  @override
  State<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends State<_AccountEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController username, displayName;
  final password = TextEditingController(),
      repeatPassword = TextEditingController();
  late String role;
  bool busy = false, obscure = true;
  String? error;
  bool get assigningPassword => widget.account == null || widget.reset;
  @override
  void initState() {
    super.initState();
    username = TextEditingController(
      text: widget.account?['username'] as String? ?? '',
    );
    displayName = TextEditingController(
      text: widget.account?['displayName'] as String? ?? '',
    );
    role = widget.account?['role'] as String? ?? 'staff';
  }

  @override
  void dispose() {
    username.dispose();
    displayName.dispose();
    password.dispose();
    repeatPassword.dispose();
    super.dispose();
  }

  void generatePassword() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    password.text =
        'SR!${List.generate(12, (_) => letters[random.nextInt(letters.length)]).join()}';
    repeatPassword.text = password.text;
    setState(() => obscure = false);
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.reset) {
        await widget.api.resetEmployeePassword(
          widget.account!['id'] as int,
          widget.account!['version'] as int,
          password.text,
        );
      } else {
        await widget.api.saveEmployee({
          'username': username.text.trim(),
          'displayName': displayName.text.trim(),
          'role': role,
          if (widget.account == null)
            'password': password.text
          else
            'version': widget.account!['version'],
        }, id: widget.account?['id'] as int?);
      }
      if (mounted) {
        Navigator.pop(context, {
          'username': username.text.trim(),
          if (assigningPassword) 'password': password.text,
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        widget.reset
            ? 'Cấp lại mật khẩu'
            : widget.account == null
            ? 'Thêm tài khoản'
            : 'Sửa tài khoản',
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.reset) ...[
                  Text(
                    '${widget.account!['displayName']} · ${widget.account!['username']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mật khẩu cũ và các phiên đăng nhập cũ sẽ mất hiệu lực.',
                  ),
                ] else ...[
                  TextFormField(
                    key: const Key('employee-name'),
                    controller: displayName,
                    enabled: !busy,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nhập họ và tên.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('employee-username'),
                    controller: username,
                    enabled: !busy,
                    maxLength: 60,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                      helperText: '3–60 ký tự: chữ không dấu, số, dấu . _ -',
                    ),
                    validator: (value) =>
                        RegExp(r'^[A-Za-z0-9._-]{3,60}$')
                            .hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Tên đăng nhập chưa hợp lệ.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('employee-role'),
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Vai trò'),
                    items: employeeRoleLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (value) => setState(() => role = value!),
                  ),
                ],
                if (assigningPassword) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('employee-password'),
                    controller: password,
                    enabled: !busy,
                    obscureText: obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: widget.reset
                          ? 'Mật khẩu mới'
                          : 'Mật khẩu cấp cho nhân sự',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 6
                        ? 'Mật khẩu tối thiểu 6 ký tự.'
                        : null,
                  ),
                  TextFormField(
                    key: const Key('employee-password-repeat'),
                    controller: repeatPassword,
                    enabled: !busy,
                    obscureText: obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mật khẩu',
                    ),
                    validator: (value) => value != password.text
                        ? 'Mật khẩu nhập lại chưa khớp.'
                        : null,
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : generatePassword,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Tạo mật khẩu ngẫu nhiên'),
                  ),
                ],
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? 'Đang lưu...'
                : widget.reset
                ? 'Cấp lại mật khẩu'
                : 'Lưu tài khoản',
          ),
        ),
      ],
    ),
  );
}
