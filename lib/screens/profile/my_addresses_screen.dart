import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/user_address.dart';
import '../../providers/auth_provider.dart';
import '../../services/address_service.dart';
import '../../services/api_exception.dart';
import '../../services/profile_and_notifications_service.dart';
import '../../utils/device_location.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/shimmer_loading.dart';
import '../../l10n/app_localizations.dart';

const _labelIcons = {
  'home': Icons.home_outlined,
  'work': Icons.work_outline,
  'other': Icons.place_outlined,
};

/// "عناويني": حتى 3 عناوين شحن (بيت/عمل/آخر) وعنوان واحد معتمد لإرسال الشحنات.
class MyAddressesScreen extends StatefulWidget {
  const MyAddressesScreen({super.key, this.service, this.locate});

  final AddressService? service;
  final LocationLookup? locate;

  @override
  State<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<MyAddressesScreen> {
  late final AddressService _service = widget.service ?? AddressService();
  List<UserAddress>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // لا setState هنا عند الاستدعاء من initState (ممنوع قبل أول بناء)
    if (_error != null) setState(() => _error = null);
    try {
      final items = await _service.list();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل العناوين.');
    }
  }

  /// بعد أي تغيير: أعد التحميل وحدّث بيانات الحساب (نسبة الإكمال والعنوان المعتمد).
  Future<void> _changed([String? message]) async {
    await _load();
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(message)));
    }
    try {
      final user = await ProfileService().show();
      if (mounted) context.read<AuthProvider>().updateUser(user);
    } catch (_) {/* تحديث الحساب ثانوي؛ العناوين نفسها حُفظت */}
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      await _changed(done);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _openForm([UserAddress? address]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddressFormSheet(
        address: address,
        isFirst: (_items ?? const []).isEmpty,
        service: _service,
        locate: widget.locate ?? currentDeviceLocation,
      ),
    );
    if (saved == true) await _changed(address == null ? 'تم حفظ العنوان.' : 'تم تحديث العنوان.');
  }

  Future<void> _confirmDelete(UserAddress a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('حذف العنوان'),
        content: AppText('حذف عنوان "${a.labelText} - ${a.city}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const AppText('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const AppText('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _service.delete(a.id), 'تم حذف العنوان.');
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final canAdd = items != null && items.length < UserAddress.maxPerUser;

    Widget body;
    if (_error != null && items == null) {
      body = AppStateMessage(message: _error!, icon: Icons.location_off_outlined, onRetry: _load);
    } else if (items == null) {
      body = const ListSkeleton(itemCount: 3, leadingSize: 44, circleLeading: true);
    } else if (items.isEmpty) {
      body = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.local_shipping_outlined, size: 56, color: context.mutedText),
          const SizedBox(height: 12),
          const AppText('لا توجد عناوين محفوظة',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          AppText('أضف عنوان البيت أو العمل ليرسل البائع شحنتك إليه.',
              textAlign: TextAlign.center, style: TextStyle(color: context.mutedText)),
        ],
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == items.length) {
            return AppText(
              '${items.length} من ${UserAddress.maxPerUser} عناوين',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.mutedText),
            );
          }
          return _AddressCard(
            address: items[i],
            onEdit: () => _openForm(items[i]),
            onDelete: () => _confirmDelete(items[i]),
            onMakeDefault: () => _run(() => _service.makeDefault(items[i].id),
                'أصبح هذا العنوان معتمداً لإرسال الشحنات.'),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const AppText('عناويني')),
      body: RefreshIndicator(onRefresh: _load, child: body),
      floatingActionButton: items == null
          ? null
          : FloatingActionButton.extended(
              onPressed: canAdd ? () => _openForm() : null,
              backgroundColor: canAdd ? null : context.mutedSurface,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: AppText(canAdd ? 'إضافة عنوان' : 'الحد الأقصى ${UserAddress.maxPerUser} عناوين'),
            ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  final UserAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMakeDefault;

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: a.isDefault ? AppColors.brandGreen.withValues(alpha: .55) : context.softBorder,
          width: a.isDefault ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                avatar: Icon(_labelIcons[a.label] ?? Icons.place_outlined, size: 16),
                label: AppText(a.labelText),
                visualDensity: VisualDensity.compact,
              ),
              if (a.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const AppText('معتمد للشحن',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppText(a.city, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          AppText(a.details, style: TextStyle(color: context.mutedText)),
          if (a.mapUrl != null)
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(a.mapUrl!), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const AppText('عرض على الخريطة'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton(onPressed: onEdit, child: const AppText('تعديل')),
              if (!a.isDefault)
                OutlinedButton(onPressed: onMakeDefault, child: const AppText('اعتماده للشحن')),
              OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                child: const AppText('حذف'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// نموذج إضافة/تعديل عنوان (نافذة سفلية). يُرجع true عند الحفظ.
class AddressFormSheet extends StatefulWidget {
  const AddressFormSheet({
    super.key,
    this.address,
    required this.isFirst,
    required this.service,
    required this.locate,
  });

  final UserAddress? address;
  final bool isFirst;
  final AddressService service;
  final LocationLookup locate;

  @override
  State<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _label = widget.address?.label ?? 'home';
  late final _city = TextEditingController(text: widget.address?.city ?? '');
  late final _details = TextEditingController(text: widget.address?.details ?? '');
  late double? _lat = widget.address?.latitude;
  late double? _lng = widget.address?.longitude;
  // أول عنوان يُعتمد دائماً؛ والعنوان المعتمد يبقى معتمداً (يتغير باعتماد غيره)
  late bool _isDefault = widget.isFirst || (widget.address?.isDefault ?? false);
  bool get _defaultLocked => widget.isFirst || (widget.address?.isDefault ?? false);
  bool _locating = false;
  bool _saving = false;
  String? _locationMessage;
  String? _error;

  @override
  void dispose() {
    _city.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      final (lat, lng) = await widget.locate();
      if (!mounted) return;
      setState(() {
        _lat = lat;
        _lng = lng;
        _locationMessage = 'تم تحديد الموقع. جارٍ جلب اسم المنطقة...';
      });
      // نقترح المدينة والحي/الشارع ونملأ الحقول الفارغة فقط (لا نمسح ما كتبه المستخدم)
      final suggestion = await widget.service.reverseGeocode(lat, lng);
      if (!mounted) return;
      var filled = false;
      if (suggestion != null) {
        if (suggestion.city.isNotEmpty && _city.text.trim().isEmpty) {
          _city.text = suggestion.city;
          filled = true;
        }
        if (suggestion.details.isNotEmpty && _details.text.trim().isEmpty) {
          _details.text = '${suggestion.details}، ';
          _details.selection = TextSelection.collapsed(offset: _details.text.length);
          filled = true;
        }
      }
      setState(() => _locationMessage = filled
          ? 'تم تحديد الموقع وتعبئة المنطقة. راجعها وأكمل رقم البناء والطابق.'
          : 'تم تحديد الموقع على الخريطة.');
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _locationMessage = e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final a = widget.address;
      if (a == null) {
        await widget.service.create(
            label: _label,
            city: _city.text.trim(),
            details: _details.text.trim(),
            latitude: _lat,
            longitude: _lng,
            isDefault: _isDefault);
      } else {
        await widget.service.update(a.id,
            label: _label,
            city: _city.text.trim(),
            details: _details.text.trim(),
            latitude: _lat,
            longitude: _lng,
            isDefault: _isDefault);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _lat != null && _lng != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(widget.address == null ? 'إضافة عنوان' : 'تعديل العنوان',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const AppText('نوع الموقع', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  for (final e in UserAddress.labels.entries)
                    ButtonSegment(value: e.key, label: AppText(e.value), icon: Icon(_labelIcons[e.key])),
                ],
                selected: {_label},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _label = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _city,
                decoration: InputDecoration(labelText: context.tr('المدينة')),
                textInputAction: TextInputAction.next,
                maxLength: 120,
                validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('المدينة مطلوبة.') : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _details,
                decoration: InputDecoration(
                  labelText: context.tr('العنوان التفصيلي'),
                  hintText: context.tr('الحي، الشارع، البناء، الطابق، علامة مميزة'),
                ),
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('اكتب العنوان التفصيلي.') : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _locating ? null : _locate,
                    icon: _locating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                    label: const AppText('موقعي الحالي'),
                  ),
                  if (hasLocation)
                    TextButton(
                      onPressed: () => setState(() {
                        _lat = null;
                        _lng = null;
                        _locationMessage = null;
                      }),
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      child: const AppText('إزالة الموقع'),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: AppText(
                  _locationMessage ??
                      (hasLocation
                          ? 'تم تحديد الموقع على الخريطة.'
                          : 'اختياري: يساعد البائع وشركة الشحن على الوصول إليك بدقة.'),
                  style: TextStyle(fontSize: 12, color: context.mutedText),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                onChanged: _defaultLocked ? null : (v) => setState(() => _isDefault = v),
                title: const AppText('اعتماد هذا العنوان لإرسال الشحنات إليه'),
                subtitle: _defaultLocked
                    ? AppText(widget.isFirst ? 'أول عنوان يُعتمد تلقائياً.' : 'هذا هو العنوان المعتمد حالياً.',
                        style: TextStyle(fontSize: 12, color: context.mutedText))
                    : null,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppText(_error!, style: const TextStyle(color: AppColors.danger)),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : AppText(widget.address == null ? 'حفظ العنوان' : 'حفظ التعديل'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
