import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../image_picker_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../models/return_request.dart';
import '../../services/api_exception.dart';
import '../../services/return_service.dart';
import '../../widgets/app_state_message.dart';
import 'create_return_screen.dart' show maxReturnPhotos;
import 'return_detail_body.dart';

/// تفاصيل طلب إرجاع: السطور والمبالغ والمواعيد والسجل، والأزرار حسب actions.
class ReturnDetailScreen extends StatefulWidget {
  const ReturnDetailScreen({super.key, required this.returnId, this.service});

  final int returnId;

  /// قابل للاستبدال في الاختبارات.
  final ReturnService? service;

  @override
  State<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends State<ReturnDetailScreen> {
  late final ReturnService _service = widget.service ?? ReturnService();
  ReturnRequest? _request;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final request = await _service.show(widget.returnId);
      if (mounted) setState(() => _request = request);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل طلب الإرجاع.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('سحب طلب الإرجاع'),
        content: const AppText('هل أنت متأكد من سحب طلب الإرجاع؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('نعم، اسحب الطلب',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final updated = await _service.withdraw(widget.returnId);
      if (!mounted) return;
      setState(() => _request = updated);
      _toast('تم سحب طلب الإرجاع.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('تعذّر سحب طلب الإرجاع.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dispute() async {
    final note = TextEditingController();
    final photos = <XFile>[];
    String? error;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const AppText('اعتراض على قرار البائع'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: note,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                      labelText: ctx.tr('سبب الاعتراض'),
                      border: const OutlineInputBorder()),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in photos)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(p.path),
                          width: 56, height: 56, fit: BoxFit.cover),
                    ),
                  if (photos.length < maxReturnPhotos)
                    TextButton.icon(
                      onPressed: submitting
                          ? null
                          : () async {
                              final result =
                                  await ImagePickerHelper.pickMultiple();
                              setDialogState(() {
                                for (final f in result.accepted) {
                                  if (photos.length < maxReturnPhotos) photos.add(f);
                                }
                                if (result.errors.isNotEmpty) {
                                  error = result.errors.first;
                                }
                              });
                            },
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const AppText('إضافة صور'),
                    ),
                ]),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AppText(error!,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const AppText('إلغاء')),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (note.text.trim().isEmpty) {
                        setDialogState(() => error = 'اكتب سبب الاعتراض.');
                        return;
                      }
                      setDialogState(() {
                        error = null;
                        submitting = true;
                      });
                      try {
                        final updated = await _service.dispute(
                            widget.returnId,
                            note: note.text,
                            photos: photos);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() => _request = updated);
                        _toast('تم إرسال اعتراضك للإدارة.');
                      } on ApiException catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() {
                            error = e.message;
                            submitting = false;
                          });
                        }
                      } catch (_) {
                        if (ctx.mounted) {
                          setDialogState(() {
                            error = 'تعذّر إرسال الاعتراض.';
                            submitting = false;
                          });
                        }
                      }
                    },
              child: const AppText('إرسال الاعتراض'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppText(_request?.number ?? 'تفاصيل الإرجاع')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    final r = _request;
    if (r == null) return const LoadingIndicator();

    return ReturnDetailBody(
      request: r,
      onRefresh: _load,
      actions: [
        if (r.canWithdraw)
          OutlinedButton(
            onPressed: _busy ? null : _withdraw,
            child: const AppText('سحب الطلب',
                style: TextStyle(color: AppColors.danger)),
          ),
        if (r.canDispute)
          FilledButton(
            onPressed: _busy ? null : _dispute,
            child: const AppText('اعتراض على القرار'),
          ),
      ],
    );
  }
}
