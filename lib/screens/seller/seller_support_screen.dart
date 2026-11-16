import 'package:flutter/material.dart';

import '../../services/support_service.dart';
import 'seller_support_create_screen.dart';
import 'seller_support_detail_screen.dart';
import '../../l10n/app_localizations.dart';

class SellerSupportScreen extends StatefulWidget {
  const SellerSupportScreen({super.key});

  @override
  State<SellerSupportScreen> createState() => _SellerSupportScreenState();
}

class _SellerSupportScreenState extends State<SellerSupportScreen> {
  final SupportService _service = SupportService();
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final conversations = await _service.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل المحادثات.';
        _loading = false;
      });
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            AppText(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: const AppText('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    if (_conversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headset, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            AppText('لا توجد محادثات دعم بعد.'),
            AppText('انقر على زر "+" لبدء محادثة جديدة.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final c = _conversations[index];
          return ListTile(
            leading: CircleAvatar(
              child: AppText(c['staff_name']?.substring(0, 1) ?? 'س'),
            ),
            title: AppText(
              c['subject'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  c['staff_name'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                AppText(
                  c['last_message'] ?? '',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      overflow: TextOverflow.ellipsis),
                  maxLines: 1,
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppText(
                  c['status'] == 'open' ? 'مفتوحة' : 'مغلقة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: c['status'] == 'open' ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                if (c['unread_count'] != null && c['unread_count'] > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AppText(
                      '${c['unread_count']}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SellerSupportDetailScreen(
                  conversationId: c['id'],
                  subject: c['subject'] ?? '',
                  staffName: c['staff_name'] ?? '',
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('الدعم الفني'),
        actions: [
          IconButton(
            tooltip: context.tr('تذكرة جديدة'),
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SellerSupportCreateScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
