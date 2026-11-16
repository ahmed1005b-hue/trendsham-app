import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/support_service.dart';
import '../../l10n/app_localizations.dart';

class SellerSupportDetailScreen extends StatefulWidget {
  final int conversationId;
  final String subject;
  final String staffName;

  const SellerSupportDetailScreen({
    super.key,
    required this.conversationId,
    required this.subject,
    required this.staffName,
  });

  @override
  State<SellerSupportDetailScreen> createState() =>
      _SellerSupportDetailScreenState();
}

class _SellerSupportDetailScreenState extends State<SellerSupportDetailScreen> {
  final SupportService _service = SupportService();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getConversation(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages = (data['messages'] as List? ?? [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل المحادثة.';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_messageController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(
        conversationId: widget.conversationId,
        body: _messageController.text.trim(),
      );
      if (!mounted) return;
      _messageController.clear();
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر إرسال الرسالة.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildMessage(Map<String, dynamic> m) {
    final isMe = m['is_me'] == true;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? context.softTint(Colors.green)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            AppText(
              m['sender_name'] ?? '',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
            const SizedBox(height: 4),
            AppText(
              m['body'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            AppText(
              m['created_at'] ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(widget.subject),
            AppText(
              widget.staffName,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Material(
                    color: context.softTint(Colors.red),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppText(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh, color: Colors.red),
                            tooltip: context.tr('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: AppText('لا توجد رسائل بعد.'),
                        )
                      : ListView.builder(
                          itemCount: _messages.length,
                          itemBuilder: (context, index) =>
                              _buildMessage(_messages[index]),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.cardSurface,
                    border: Border(
                      top: BorderSide(color: context.cardBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: context.tr('اكتب ردك...'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _sending
                          ? const SizedBox(
                              height: 32,
                              width: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : IconButton(
                              tooltip: context.tr('إرسال'),
                              icon: const Icon(Icons.send),
                              onPressed: _sending ? null : _send,
                              color: Colors.green,
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
