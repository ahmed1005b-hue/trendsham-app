import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_tools_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// المساعد الذكي للمدير (نفس صفحات الموقع): محادثات حوّلها العملاء لموظف،
/// والأسئلة الشائعة التي يجيب منها المساعد.
class AdminAssistantScreen extends StatelessWidget {
  const AdminAssistantScreen(
      {super.key, this.service, this.employeeMode = false});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminToolsService? service;

  /// الموظف: محادثات العملاء فقط، والأسئلة الشائعة يديرها المدير.
  final bool employeeMode;

  @override
  Widget build(BuildContext context) {
    final s = service ??
        (employeeMode ? AdminToolsService.employee() : AdminToolsService());
    if (employeeMode) {
      return Scaffold(
        appBar: AppBar(title: const AppText('محادثات العملاء')),
        body: _ChatsTab(service: s),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('المساعد الذكي'),
          bottom: const TabBar(tabs: [
            Tab(
                key: ValueKey('assistant-tab-chats'),
                child: AppText('المحادثات')),
            Tab(
                key: ValueKey('assistant-tab-faqs'),
                child: AppText('الأسئلة الشائعة')),
          ]),
        ),
        body: TabBarView(children: [
          _ChatsTab(service: s),
          _FaqsTab(service: s),
        ]),
      ),
    );
  }
}

class _ChatsTab extends StatefulWidget {
  const _ChatsTab({required this.service});

  final AdminToolsService service;

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> {
  bool _closed = false;
  List<ChatSummary>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await widget.service.chats(closed: _closed);
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المحادثات.');
    }
  }

  Future<void> _open(ChatSummary c) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            AdminChatScreen(chatId: c.id, service: widget.service)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: AppText('بانتظار الرد')),
            ButtonSegment(value: true, label: AppText('مغلقة')),
          ],
          selected: {_closed},
          onSelectionChanged: (s) {
            setState(() => _closed = s.first);
            _load();
          },
        ),
      ),
      Expanded(
        child: _error != null
            ? AppStateMessage(
                message: _error!, icon: Icons.error_outline, onRetry: _load)
            : items == null
                ? const LoadingIndicator()
                : items.isEmpty
                    ? const AppStateMessage(
                        message: 'لا توجد محادثات هنا.',
                        icon: Icons.forum_outlined)
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          children: [
                            for (final c in items)
                              Card(
                                key: ValueKey('chat-${c.id}'),
                                child: ListTile(
                                  onTap: () => _open(c),
                                  leading: const Icon(Icons.support_agent),
                                  title: AppText(c.customer,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(c.lastMessage ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  trailing: c.escalatedAt == null
                                      ? null
                                      : Text(
                                          DateFormat('MM-dd HH:mm')
                                              .format(c.escalatedAt!.toLocal()),
                                          style: const TextStyle(fontSize: 11)),
                                ),
                              ),
                          ],
                        ),
                      ),
      ),
    ]);
  }
}

/// محادثة واحدة: رسائل العميل والمساعد، ورد الموظف، والإغلاق.
class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key, required this.chatId, this.service});

  final int chatId;
  final AdminToolsService? service;

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  late final AdminToolsService _service = widget.service ?? AdminToolsService();
  final _reply = TextEditingController();
  ChatThread? _thread;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final t = await _service.chat(widget.chatId);
      if (mounted) setState(() => _thread = t);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المحادثة.');
    }
  }

  Future<void> _run(Future<ChatThread> Function() action) async {
    setState(() => _busy = true);
    try {
      final t = await action();
      if (mounted) setState(() => _thread = t);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('تعذّر الاتصال بالسيرفر.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    await _run(() => _service.reply(widget.chatId, text));
    if (mounted && _thread?.messages.any((m) => m.content == text) == true) {
      _reply.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _thread;
    return Scaffold(
      appBar: AppBar(
        title: AppText(t?.customer ?? 'المحادثة'),
        actions: [
          if (t != null && t.isOpen)
            TextButton(
              key: const ValueKey('chat-close'),
              onPressed:
                  _busy ? null : () => _run(() => _service.closeChat(t.id)),
              child: const AppText('إغلاق المحادثة'),
            ),
        ],
      ),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : t == null
              ? const LoadingIndicator()
              : Column(children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (final m in t.messages)
                          Align(
                            alignment: m.fromCustomer
                                ? AlignmentDirectional.centerStart
                                : AlignmentDirectional.centerEnd,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: m.fromCustomer
                                    ? Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                    : (m.agent
                                        ? AppColors.primary
                                            .withValues(alpha: 0.15)
                                        : AppColors.emerald
                                            .withValues(alpha: 0.08)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m.agent)
                                    Text(m.agentName ?? '',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  Text(m.content),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (t.isOpen)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('chat-reply'),
                              controller: _reply,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 2000,
                              decoration: InputDecoration(
                                  counterText: '',
                                  hintText: context.tr('اكتب الرد')),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('chat-send'),
                            onPressed: _busy ? null : _send,
                            icon: const Icon(Icons.send),
                          ),
                        ]),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: AppText(
                          'المحادثة مغلقة؛ العميل يعود للمساعد الآلي.',
                          style: TextStyle(color: AppColors.muted)),
                    ),
                ]),
    );
  }
}

class _FaqsTab extends StatefulWidget {
  const _FaqsTab({required this.service});

  final AdminToolsService service;

  @override
  State<_FaqsTab> createState() => _FaqsTabState();
}

class _FaqsTabState extends State<_FaqsTab> {
  List<AssistantFaq>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await widget.service.faqs();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الأسئلة الشائعة.');
    }
  }

  Future<void> _edit([AssistantFaq? faq]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FaqSheet(service: widget.service, faq: faq),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _delete(AssistantFaq faq) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const AppText('حذف هذا السؤال؟ يمكن استرجاعه من المحذوفات.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.deleteFaq(faq.id!);
      if (mounted) _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('faq-add'),
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : items == null
              ? const LoadingIndicator()
              : items.isEmpty
                  ? const AppStateMessage(
                      message: 'لا توجد أسئلة شائعة بعد.',
                      icon: Icons.quiz_outlined)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      children: [
                        for (final f in items)
                          Card(
                            key: ValueKey('faq-${f.id}'),
                            child: ListTile(
                              onTap: () => _edit(f),
                              title: Text(f.question,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          f.isActive ? null : AppColors.muted)),
                              subtitle: Text(f.answer,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.danger),
                                onPressed: () => _delete(f),
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class _FaqSheet extends StatefulWidget {
  const _FaqSheet({required this.service, this.faq});

  final AdminToolsService service;
  final AssistantFaq? faq;

  @override
  State<_FaqSheet> createState() => _FaqSheetState();
}

class _FaqSheetState extends State<_FaqSheet> {
  late final _question = TextEditingController(text: widget.faq?.question);
  late final _keywords = TextEditingController(text: widget.faq?.keywords);
  late final _answer = TextEditingController(text: widget.faq?.answer);
  late final _order =
      TextEditingController(text: '${widget.faq?.sortOrder ?? 0}');
  late bool _active = widget.faq?.isActive ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    _keywords.dispose();
    _answer.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.saveFaq(AssistantFaq(
        id: widget.faq?.id,
        question: _question.text.trim(),
        keywords: _keywords.text.trim(),
        answer: _answer.text.trim(),
        isActive: _active,
        sortOrder: int.tryParse(_order.text.trim()) ?? 0,
      ));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر الاتصال بالسيرفر.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(widget.faq == null ? 'سؤال جديد' : 'تعديل السؤال',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (_error != null)
              AppText(_error!, style: const TextStyle(color: AppColors.danger)),
            TextField(
              key: const ValueKey('faq-question'),
              controller: _question,
              maxLength: 255,
              decoration: InputDecoration(labelText: context.tr('السؤال')),
            ),
            TextField(
              key: const ValueKey('faq-keywords'),
              controller: _keywords,
              maxLength: 1000,
              decoration: InputDecoration(
                  labelText: context.tr('كلمات يعرف بها المساعد السؤال'),
                  helperText: context.tr('افصل بينها بفاصلة، مثل: شحن، توصيل')),
            ),
            TextField(
              key: const ValueKey('faq-answer'),
              controller: _answer,
              maxLength: 3000,
              maxLines: 4,
              decoration: InputDecoration(labelText: context.tr('الجواب')),
            ),
            TextField(
              controller: _order,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('الترتيب')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const AppText('مفعّل'),
            ),
            FilledButton(
              key: const ValueKey('faq-save'),
              onPressed: _busy ? null : _save,
              child: const AppText('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
