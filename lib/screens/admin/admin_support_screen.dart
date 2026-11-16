import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/admin_operations_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// محادثات الدعم بين الإدارة والبائعين.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key, this.service});

  final AdminOperationsService? service;

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  late final AdminOperationsService _service =
      widget.service ?? AdminOperationsService();
  List<Map<String, dynamic>>? _conversations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await _service.supportConversations();
      if (mounted) setState(() => _conversations = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المحادثات.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('دعم البائعين')),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_conversations == null) return const LoadingIndicator();
    if (_conversations!.isEmpty) {
      return const AppStateMessage(
          message: 'لا توجد محادثات دعم.', icon: Icons.support_agent);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _conversations!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = _conversations![index];
        final unread = (c['unread_count'] as num?)?.toInt() ?? 0;
        final closed = c['status'] == 'closed';
        return Card(
          child: ListTile(
            leading: Icon(
              closed ? Icons.lock_outline : Icons.forum_outlined,
              color: closed ? AppColors.muted : AppColors.emerald,
            ),
            title: AppText('${c['subject'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: AppText(
              '${c['store_name'] ?? c['vendor_name'] ?? ''}\n${c['last_message'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: unread > 0
                ? Badge(
                    label: AppText('$unread'),
                    backgroundColor: AppColors.danger)
                : null,
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AdminSupportDetailScreen(
                  conversationId: (c['id'] as num).toInt(),
                  service: _service,
                ),
              ));
              _load();
            },
          ),
        );
      },
    );
  }
}

class AdminSupportDetailScreen extends StatefulWidget {
  const AdminSupportDetailScreen({
    super.key,
    required this.conversationId,
    this.service,
  });

  final int conversationId;
  final AdminOperationsService? service;

  @override
  State<AdminSupportDetailScreen> createState() =>
      _AdminSupportDetailScreenState();
}

class _AdminSupportDetailScreenState extends State<AdminSupportDetailScreen> {
  late final AdminOperationsService _service =
      widget.service ?? AdminOperationsService();
  final _controller = TextEditingController();
  Map<String, dynamic>? _conversation;
  List<Map<String, dynamic>> _messages = [];
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _service.supportConversation(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _conversation = data['conversation'] is Map
            ? Map<String, dynamic>.from(data['conversation'] as Map)
            : {};
        _messages = (data['messages'] as List? ?? [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المحادثة.');
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.replySupport(widget.conversationId, body);
      _controller.clear();
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleStatus() async {
    final closed = _conversation?['status'] == 'closed';
    try {
      await _service.setSupportOpen(widget.conversationId, closed);
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }

  @override
  Widget build(BuildContext context) {
    final closed = _conversation?['status'] == 'closed';
    return Scaffold(
      appBar: AppBar(
        title: AppText('${_conversation?['subject'] ?? 'محادثة'}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_conversation != null)
            TextButton.icon(
              onPressed: _toggleStatus,
              icon: Icon(closed ? Icons.lock_open : Icons.lock_outline),
              label: AppText(closed ? 'إعادة فتح' : 'إغلاق'),
            ),
        ],
      ),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : _conversation == null
              ? const LoadingIndicator()
              : Column(
                  children: [
                    Expanded(
                      child: _messages.isEmpty
                          ? const AppStateMessage(
                              message: 'لا توجد رسائل بعد.',
                              icon: Icons.chat_bubble_outline)
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _messages.length,
                              itemBuilder: (_, i) => _bubble(_messages[i]),
                            ),
                    ),
                    if (closed)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: AppText('المحادثة مغلقة. أعد فتحها للرد.',
                            style: TextStyle(color: AppColors.muted)),
                      )
                    else
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  minLines: 1,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context)
                                        .translate('اكتب ردك...'),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _sending ? null : _send,
                                tooltip: context.tr('إرسال'),
                                icon: const Icon(Icons.send),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final isMe = m['is_me'] == true;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isMe
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.emerald.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText('${m['sender_name'] ?? ''}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.muted)),
            const SizedBox(height: 2),
            AppText('${m['body'] ?? ''}'),
          ],
        ),
      ),
    );
  }
}
