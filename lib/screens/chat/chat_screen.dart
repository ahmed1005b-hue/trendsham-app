import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/api_exception.dart';
import '../../services/chat_service.dart';
import '../auth/login_screen.dart';
import '../coupons/my_coupons_screen.dart';
import '../orders/order_detail_screen.dart';
import '../product/product_detail_screen.dart';
import '../seller/seller_orders_screen.dart';
import '../seller/seller_products_screen.dart';
import '../seller/seller_support_create_screen.dart';
import '../seller/seller_wallet_screen.dart';

const _defaultChips = ['تتبع طلبي', 'كوبوناتي', 'عروض اليوم', 'تحدث مع موظف'];
const _sellerChips = [
  'مبيعاتي هالشهر',
  'الطلبات اللي بانتظاري',
  'المنتجات اللي قربت تخلص',
  'نصائح لزيد مبيعاتي',
];

class ChatScreen extends StatefulWidget {
  /// مساعد المتجر للبائع (نفس المحادثة، والخادم يختار عقل البائع)
  final bool seller;

  const ChatScreen({super.key, this.seller = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _escalated = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversation();
  }

  /// التطبيق بالخلفية: نوقف التحقق الدوري، ونستأنفه عند الرجوع
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setEscalated(_escalated);
    } else {
      _pausePolling();
    }
  }

  void _pausePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _lastId => _messages.fold(0, (m, e) => e.id > m ? e.id : m);

  Future<void> _loadConversation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await _chatService.conversation();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history.messages);
        _loading = false;
      });
      _setEscalated(history.escalated);
      if (_messages.isEmpty) {
        _addLocalAssistantMessage(widget.seller
            ? 'أهلاً فيك! أنا مساعد متجرك 📊 اسألني عن مبيعاتك وطلباتك ومخزونك، أو قلّي "اكتب وصف لمنتج ...".'
            : 'أهلاً فيك! أنا مساعد تريندشام. دورلك على منتج بالسعر واللون اللي بدك، تابعلك طلباتك، وفرجيك كوبوناتك 🙂');
      }
      _scrollToBottom();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحميل المحادثة: $e';
          _loading = false;
        });
      }
    }
  }

  /// المحادثة عند موظف: نتحقق من ردوده كل 15 ثانية
  void _setEscalated(bool escalated) {
    _escalated = escalated;
    if (escalated && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
    } else if (!escalated) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _poll() async {
    if (_sending) return;
    try {
      final history = await _chatService.conversation();
      if (!mounted) return;
      final fresh = history.messages.where((m) => m.id > _lastId).toList();
      if (fresh.isNotEmpty) {
        setState(() => _messages.addAll(fresh));
        _scrollToBottom();
      }
      _setEscalated(history.escalated);
    } catch (_) {
      // نحاول بالدورة التالية
    }
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _sending) return;

    if (preset == null) _inputController.clear();
    final local = ChatMessage(role: 'user', content: text);
    setState(() {
      _sending = true;
      _error = null;
      _messages.add(local);
    });
    _scrollToBottom();

    try {
      final result = await _chatService.send(text);
      if (!mounted) return;
      setState(() {
        // النسخة المحفوظة برقمها: حتى لا يعيد التحقق الدوري عرضها
        final i = _messages.indexOf(local);
        if (result.message != null && i >= 0) _messages[i] = result.message!;
        if (result.reply != null) _messages.add(result.reply!);
      });
      _setEscalated(result.escalated);
      _scrollToBottom();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'تعذّر إرسال الرسالة: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _addLocalAssistantMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
          role: 'assistant',
          content: text,
          chips: widget.seller ? _sellerChips : _defaultChips));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _openCard(ChatCard card) {
    final Widget? screen = switch (card.type) {
      'product' when card.slug != null => ProductDetailScreen(slug: card.slug!),
      'order' when card.id > 0 => OrderDetailScreen(orderId: card.id),
      'link' => switch (card.route) {
          'login' => const LoginScreen(returnAfterAuth: true),
          'coupons' => const MyCouponsScreen(),
          'seller_orders' => const SellerOrdersScreen(),
          'seller_products' => const SellerProductsScreen(),
          'seller_wallet' => const SellerWalletScreen(),
          'seller_support' => const SellerSupportCreateScreen(),
          _ => null,
        },
      _ => null,
    };
    if (screen == null) return;
    _pausePolling(); // لا تحقق دوري والعميل بشاشة أخرى
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then(
      (_) {
        if (!mounted) return;
        // بعد تسجيل الدخول تصبح المحادثة باسم الحساب
        if (card.route == 'login') {
          _loadConversation();
        } else {
          _setEscalated(_escalated);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // الاقتراحات تخص آخر رد فقط
    final lastAssistant = _messages.lastIndexWhere((m) => m.role != 'user');

    return Scaffold(
      appBar: AppBar(
        title: AppText(_escalated
            ? 'خدمة العملاء'
            : widget.seller
                ? 'مساعد المتجر'
                : 'مساعد تريندشام'),
        actions: [
          IconButton(
            tooltip: context.tr('تحديث'),
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _sending ? null : _loadConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_escalated)
            Container(
              width: double.infinity,
              color: AppColors.primary.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const AppText(
                'محادثتك عند فريق الدعم، رح يرد عليك موظف هون.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _error != null && _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppText(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _loadConversation,
                                child: const AppText('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_sending && index == _messages.length) {
                            return const _TypingIndicator();
                          }
                          final message = _messages[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MessageBubble(message: message),
                              if (message.cards.isNotEmpty)
                                _CardsRow(
                                    cards: message.cards, onTap: _openCard),
                              if (index == lastAssistant &&
                                  message.chips.isNotEmpty)
                                _ChipsRow(
                                  chips: message.chips,
                                  enabled: !_sending,
                                  onTap: _sendMessage,
                                ),
                            ],
                          );
                        },
                      ),
          ),
          if (_error != null && _messages.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AppText(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
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
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)
                            .translate('اكتب سؤالك هنا...'),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: context.tr('إرسال'),
                    onPressed: _sending ? null : () => _sendMessage(),
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
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : scheme.surface,
          border: isUser
              ? null
              : Border.all(
                  color: message.isAgent ? AppColors.gold : AppColors.border,
                  width: message.isAgent ? 1.5 : 1,
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 4 : 16),
            bottomRight: Radius.circular(isUser ? 16 : 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isAgent)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: AppText(
                  'موظف الدعم${message.agentName != null ? ' · ${message.agentName}' : ''}',
                  style: TextStyle(
                    color: context.goldText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            AppText(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : scheme.onSurface,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsRow extends StatelessWidget {
  final List<ChatCard> cards;
  final ValueChanged<ChatCard> onTap;

  const _CardsRow({required this.cards, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasProducts = cards.any((c) => c.type == 'product');
    return SizedBox(
      height: hasProducts ? 216 : 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final card = cards[i];
          final scheme = Theme.of(context).colorScheme;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(card),
            child: Container(
              width: card.type == 'product' ? 136 : null,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: card.type == 'product'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 84,
                            width: double.infinity,
                            child: card.image != null
                                ? Image.network(card.image!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.image_outlined))
                                : const Icon(Icons.image_outlined),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AppText(card.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        AppText(card.subtitle ?? '',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800)),
                        if (!card.inStock)
                          const AppText('غير متوفر',
                              style: TextStyle(
                                  color: AppColors.danger, fontSize: 10.5)),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        if (card.subtitle != null) ...[
                          const SizedBox(height: 2),
                          AppText(
                            card.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: context.goldText, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final List<String> chips;
  final bool enabled;
  final ValueChanged<String> onTap;

  const _ChipsRow(
      {required this.chips, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips
            .map((chip) => ActionChip(
                  label: AppText(chip, style: const TextStyle(fontSize: 12)),
                  side: const BorderSide(color: AppColors.primary),
                  onPressed: enabled ? () => onTap(chip) : null,
                ))
            .toList(),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
