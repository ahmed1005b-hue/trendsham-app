import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_exception.dart';
import '../../services/buyer_seller_message_service.dart';
import '../../widgets/app_state_message.dart';

class BuyerSellerMessagesScreen extends StatefulWidget {
  final int? conversationId;

  const BuyerSellerMessagesScreen({super.key, this.conversationId});

  @override
  State<BuyerSellerMessagesScreen> createState() =>
      _BuyerSellerMessagesScreenState();
}

class _BuyerSellerMessagesScreenState extends State<BuyerSellerMessagesScreen> {
  final BuyerSellerMessageService _service = BuyerSellerMessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _conversation;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  int? _activeId;

  @override
  void initState() {
    super.initState();
    _activeId = widget.conversationId;
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_activeId == null) {
        _conversations = await _service.conversations();
      } else {
        _conversation = await _service.conversation(_activeId!);
      }
    } on ApiException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'تعذّر تحميل المحادثات.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> conversation) async {
    final id = (conversation['id'] as num).toInt();
    setState(() {
      _activeId = id;
      _conversation = null;
      _loading = true;
    });
    await _load();
  }

  Future<void> _send() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _activeId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.send(_activeId!, body);
      _messageController.clear();
      await _load();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('تعذّر إرسال الرسالة.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    return Scaffold(
      appBar: AppBar(
        title: AppText(_activeId == null ? 'محادثاتي' : 'مراسلة البائع'),
        leading: _activeId == null
            ? null
            : IconButton(
                tooltip: context.tr('العودة للمحادثات'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _activeId = null;
                    _conversation = null;
                  });
                  _load();
                },
              ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? AppStateMessage(
                  message: _error!,
                  icon: Icons.chat_bubble_outline,
                  onRetry: _load,
                )
              : _activeId == null
                  ? _buildInbox(role)
                  : _buildConversation(),
    );
  }

  Widget _buildInbox(String? role) {
    if (_conversations.isEmpty) {
      return const Center(child: AppText('لا توجد محادثات حتى الآن.'));
    }
    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _conversations[index];
        final customer = item['customer'];
        final store = item['store'];
        final counterpart = role == 'seller'
            ? (customer is Map ? customer['name']?.toString() : null)
            : (store is Map ? store['store_name']?.toString() : null);
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.goldSoft,
            child: Icon(Icons.storefront_outlined, color: AppColors.primary),
          ),
          title: AppText(counterpart ?? 'محادثة'),
          subtitle:
              AppText(item['last_message_at']?.toString() ?? 'افتح المحادثة'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _open(item),
        );
      },
    );
  }

  Widget _buildConversation() {
    final messages = (_conversation?['messages'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(child: AppText('ابدأ المحادثة برسالة قصيرة.'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final mine = message['is_mine'] == true;
                    return Align(
                      alignment: mine
                          ? AlignmentDirectional.centerStart
                          : AlignmentDirectional.centerEnd,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 9),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppColors.primary.withValues(alpha: .1)
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: AppText(
                          message['body']?.toString() ?? '',
                          style: TextStyle(
                            color: mine ? null : Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText: context.tr('اكتب رسالتك للبائع'),
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: context.tr('إرسال الرسالة'),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
