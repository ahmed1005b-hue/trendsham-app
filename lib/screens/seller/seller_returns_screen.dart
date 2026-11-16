import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/return_request.dart';
import '../../services/api_exception.dart';
import '../../services/seller_return_service.dart';
import '../../widgets/app_state_message.dart';
import 'seller_return_detail_screen.dart';

/// حالات طلب الإرجاع للتصفية (المفاتيح كما يقبلها السيرفر).
const _statusFilters = <(String?, String)>[
  (null, 'الكل'),
  ('requested', 'بانتظار رد البائع'),
  ('approved', 'تمت الموافقة'),
  ('rejected', 'مرفوض'),
  ('escalated', 'تحت مراجعة الإدارة'),
  ('received', 'تم الاستلام'),
  ('refunded', 'تم الاسترداد'),
  ('closed', 'مغلق'),
];

/// قائمة طلبات الإرجاع لمتجر البائع.
class SellerReturnsScreen extends StatefulWidget {
  const SellerReturnsScreen({super.key, this.service});

  /// قابل للاستبدال في الاختبارات.
  final SellerReturnService? service;

  @override
  State<SellerReturnsScreen> createState() => _SellerReturnsScreenState();
}

class _SellerReturnsScreenState extends State<SellerReturnsScreen> {
  late final SellerReturnService _service =
      widget.service ?? SellerReturnService();
  final List<ReturnRequest> _returns = [];
  String? _status;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = _status;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.list(status: status);
      if (!mounted || status != _status) return;
      setState(() {
        _returns
          ..clear()
          ..addAll(result.items);
        _page = result.currentPage;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted && status == _status) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted && status == _status) {
        setState(() {
          _loading = false;
          _error = 'تعذّر تحميل طلبات الإرجاع.';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final status = _status;
    setState(() => _loadingMore = true);
    try {
      final result = await _service.list(status: status, page: _page + 1);
      if (!mounted || status != _status) return;
      setState(() {
        _returns.addAll(result.items);
        _page = result.currentPage;
        _hasMore = result.hasMore;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('تعذّر تحميل طلبات الإرجاع.')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _select(String? status) {
    if (status == _status) return;
    _status = status;
    _load();
  }

  Future<void> _open(ReturnRequest request) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SellerReturnDetailScreen(returnId: request.id)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('طلبات الإرجاع')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 12, vertical: 8),
              children: [
                for (final (key, label) in _statusFilters)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: AppText(label),
                      selected: _status == key,
                      onSelected: (_) => _select(key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingIndicator();
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_returns.isEmpty) {
      return const AppStateMessage(
          message: 'لا توجد طلبات إرجاع.',
          icon: Icons.assignment_return_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final r in _returns)
            Card(
              child: ListTile(
                onTap: () => _open(r),
                title: AppText(r.number,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.customerName != null)
                      AppText(r.customerName!,
                          style: const TextStyle(fontSize: 12)),
                    if (r.orderNumber != null)
                      AppText('الطلب: ${r.orderNumber}',
                          style: const TextStyle(fontSize: 12)),
                    AppText(r.reasonLabel,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                    AppText('${r.refundAmount.toStringAsFixed(0)} ل.س',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
                trailing: Chip(label: AppText(r.statusLabel)),
              ),
            ),
          if (_hasMore)
            Center(
              child: TextButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: _loadingMore
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const AppText('عرض المزيد'),
              ),
            ),
        ],
      ),
    );
  }
}
