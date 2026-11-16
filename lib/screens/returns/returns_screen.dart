import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/return_request.dart';
import '../../services/api_exception.dart';
import '../../services/return_service.dart';
import '../../widgets/app_state_message.dart';
import 'return_detail_screen.dart';

/// قائمة طلبات الإرجاع للعميل.
class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key, this.service});

  /// قابل للاستبدال في الاختبارات.
  final ReturnService? service;

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  late final ReturnService _service = widget.service ?? ReturnService();
  final List<ReturnRequest> _returns = [];
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.list();
      if (!mounted) return;
      setState(() {
        _returns
          ..clear()
          ..addAll(result.items);
        _page = result.currentPage;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذّر تحميل طلبات الإرجاع.';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _service.list(page: _page + 1);
      if (!mounted) return;
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
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(ReturnRequest request) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ReturnDetailScreen(returnId: request.id)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('طلبات الإرجاع')),
      body: _body(),
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
          message: 'لا توجد طلبات إرجاع.', icon: Icons.assignment_return_outlined);
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
