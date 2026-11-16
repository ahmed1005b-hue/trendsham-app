import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/product_options.dart';
import 'product_options_controller.dart';

/// محرر الألوان والمقاسات: يختار البائع الألوان والمقاسات مرة واحدة، وتُبنى
/// كل التركيبات تلقائياً ليملأ كمياتها وأسعارها.
class ProductOptionsEditor extends StatelessWidget {
  const ProductOptionsEditor({super.key, required this.controller});

  final ProductOptionsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _EditorBody(controller: controller),
    );
  }
}

/// نافذة "لون آخر": اسم اللون ودرجته (درجة اللون والتشبع والسطوع).
/// تعيد null عند الإلغاء، وإلا الاسم والدرجة بصيغة `#RRGGBB`.
Future<({String name, String hex})?> showCustomColorDialog(
  BuildContext context, {
  String? initialName,
}) {
  return showDialog<({String name, String hex})>(
    context: context,
    builder: (_) => _CustomColorDialog(initialName: initialName),
  );
}

String _comboKey(String? colorKey, String? size) =>
    '${colorKey ?? ''}|${size ?? ''}';

/// نفس مقارنة المقاسات في المتحكم: بلا مسافات ولا فرق بين الحروف الكبيرة والصغيرة.
String _foldSize(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

final _digitsOnly = FilteringTextInputFormatter.digitsOnly;
final _decimalPattern = RegExp(r'^\d*\.?\d*$');

/// يرفض التعديل الذي يكسر الرقم (نقطة ثانية أو حرف) ويُبقي ما كتبه البائع،
/// بدل FilteringTextInputFormatter.allow الذي يمسح الخانة كلها عند عدم التطابق.
final _decimalOnly = TextInputFormatter.withFunction(
  (oldValue, newValue) =>
      _decimalPattern.hasMatch(newValue.text) ? newValue : oldValue,
);

class _EditorBody extends StatefulWidget {
  const _EditorBody({required this.controller});

  final ProductOptionsController controller;

  @override
  State<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<_EditorBody> {
  /// حقول التركيبات وحقول "تطبيق على هذا اللون"، كل حقل بمفتاحه حتى لا
  /// يفقد البائع مكان الكتابة عند إعادة البناء.
  final Map<String, TextEditingController> _fields = {};
  final _bulkStock = TextEditingController();
  final _bulkPrice = TextEditingController();
  final _customSize = TextEditingController();

  String? _systemKey;
  bool? _showSku;

  ProductOptionsController get _options => widget.controller;

  @override
  void didUpdateWidget(covariant _EditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      for (final field in _fields.values) {
        field.dispose();
      }
      _fields.clear();
      return;
    }
    _syncComboFields();
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _bulkStock.dispose();
    _bulkPrice.dispose();
    _customSize.dispose();
    super.dispose();
  }

  /// قيم غيّرها المتحكم (تطبيق جماعي، تحميل) تظهر في حقولها المفتوحة.
  void _syncComboFields() {
    for (final e in _options.combinations) {
      final key = _comboKey(e.color?.key, e.size);
      final combo = _options.combo(e.color?.key, e.size);
      _syncField('stock:$key', combo.stock);
      _syncField('price:$key', combo.priceIncrease);
      _syncField('sku:$key', combo.sku);
    }
  }

  void _syncField(String id, String value) {
    final field = _fields[id];
    if (field != null && field.text != value) {
      field.text = value;
    }
  }

  TextEditingController _field(String id, [String value = '']) {
    return _fields.putIfAbsent(id, () => TextEditingController(text: value));
  }

  bool get _isSkuShown =>
      _showSku ??
      _options.combinations
          .any((e) => _options.combo(e.color?.key, e.size).sku.isNotEmpty);

  String _colorLabel(OptionColor color) =>
      _options.catalog.byHex(color.key)?.label ?? color.name;

  bool _isSizeSelected(String size) =>
      _options.sizes.any((s) => _foldSize(s) == _foldSize(size));

  void _showError(String? error) {
    if (error == null) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: AppText(error)));
  }

  Future<void> _addCustomColor() async {
    final picked = await showCustomColorDialog(context);
    if (picked == null || !mounted) {
      return;
    }
    _showError(_options.addCustomColor(picked.name, picked.hex));
  }

  Future<void> _recolor(OptionColor color) async {
    final picked =
        await showCustomColorDialog(context, initialName: _colorLabel(color));
    if (picked == null || !mounted) {
      return;
    }
    _showError(_options.recolor(color.key, picked.hex));
  }

  void _addCustomSize() {
    if (_options.addCustomSize(_customSize.text)) {
      _customSize.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _options.enabled,
          onChanged: _options.setEnabled,
          title: const AppText('هذا المنتج له ألوان أو مقاسات',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: AppText(
              'اختر الألوان والمقاسات مرة واحدة، وتُنشأ كل التركيبات تلقائياً لتملأ كمياتها.',
              style: TextStyle(fontSize: 12, color: context.mutedText)),
        ),
        if (_options.enabled) ...[
          const SizedBox(height: 8),
          const _Heading('الألوان'),
          _buildColors(context),
          const SizedBox(height: 20),
          const _Heading('المقاسات'),
          _buildSizes(context),
          const SizedBox(height: 20),
          const _Heading('الكميات والأسعار'),
          _buildMatrix(context),
        ],
      ],
    );
  }

  Widget _buildColors(BuildContext context) {
    final customColors = _options.colors
        .where((c) => _options.catalog.byHex(c.key) == null)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 10,
          children: [
            for (final option in _options.catalog.colors)
              _PaletteSwatch(
                label: option.label,
                fill: colorFromHex(option.hex),
                selected: _options.isPaletteSelected(option),
                onTap: () => _options.togglePaletteColor(option),
              ),
            _OtherColorTile(onTap: _addCustomColor),
          ],
        ),
        if (customColors.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in customColors) _customColorChip(color),
            ],
          ),
        ],
      ],
    );
  }

  Widget _customColorChip(OptionColor color) {
    final isLegacy = color.hex == null;
    return InputChip(
      key: ValueKey('options-custom-color:${color.key}'),
      avatar: _SwatchDot(fill: colorFromHex(color.hex), size: 22),
      label: Text(_colorLabel(color)),
      tooltip:
          isLegacy ? context.tr('لون مكتوب سابقاً — اضغط لاختيار درجته') : null,
      onPressed: isLegacy ? () => _recolor(color) : null,
      onDeleted: () => _options.removeColor(color.key),
      deleteButtonTooltipMessage: context.tr('إزالة'),
    );
  }

  Widget _buildSizes(BuildContext context) {
    final systems = _options.catalog.sizeSystems;
    final active = systems.where((s) => s.key == _systemKey).firstOrNull ??
        systems.firstOrNull;
    final systemSizes = {
      for (final s in systems)
        for (final size in s.sizes) _foldSize(size),
    };
    final customSizes =
        _options.sizes.where((s) => !systemSizes.contains(_foldSize(s)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final system in systems)
              ChoiceChip(
                label: Text(system.label),
                selected: system == active,
                onSelected: (_) => setState(() => _systemKey = system.key),
              ),
          ],
        ),
        if (active != null) ...[
          Wrap(
            children: [
              TextButton(
                onPressed: () => _selectAllSizes(active),
                child: const AppText('تحديد الكل'),
              ),
              TextButton(
                onPressed: () => _clearSizes(active),
                child: const AppText('مسح'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in active.sizes)
                FilterChip(
                  label: Text(size),
                  selected: _isSizeSelected(size),
                  onSelected: (_) => _options.toggleSize(size),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customSize,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addCustomSize(),
                decoration: InputDecoration(
                  hintText: context.tr('مقاس آخر (مثال: 42 عريض)'),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _addCustomSize,
              child: const AppText('إضافة مقاس'),
            ),
          ],
        ),
        if (customSizes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in customSizes)
                InputChip(
                  label: Text(size),
                  selected: true,
                  showCheckmark: false,
                  onDeleted: () => _options.toggleSize(size),
                  deleteButtonTooltipMessage: context.tr('إزالة'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _selectAllSizes(SizeSystem system) {
    for (final size in system.sizes) {
      if (!_isSizeSelected(size)) {
        _options.toggleSize(size);
      }
    }
  }

  void _clearSizes(SizeSystem system) {
    for (final size in system.sizes) {
      if (_isSizeSelected(size)) {
        _options.toggleSize(size);
      }
    }
  }

  Widget _buildMatrix(BuildContext context) {
    final rows = _options.combinations;
    final grouped = _options.colors.isNotEmpty && _options.sizes.isNotEmpty;
    final showSku = _isSkuShown;
    final totals = context
        .tr('المجموع: :stock قطعة في :count خيار')
        .replaceAll(':stock', '${_options.totalStock}')
        .replaceAll(':count', '${_options.availableCount}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BulkField(
          label: 'الكمية لكل الخيارات',
          controller: _bulkStock,
          formatter: _digitsOnly,
          keyboardType: TextInputType.number,
          onApply: () {
            final value = _bulkStock.text.trim();
            if (value.isNotEmpty) {
              _options.setAllStock(value);
            }
          },
        ),
        const SizedBox(height: 8),
        _BulkField(
          label: 'زيادة السعر لكل الخيارات',
          controller: _bulkPrice,
          formatter: _decimalOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onApply: () {
            final value = _bulkPrice.text.trim();
            if (value.isNotEmpty) {
              _options.setAllPriceIncrease(value);
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _isSkuShown,
          onChanged: (v) => setState(() => _showSku = v),
          title: const AppText('إظهار رمز SKU لكل خيار'),
        ),
        if (rows.isEmpty)
          AppText(
            'اختر لوناً أو مقاساً واحداً على الأقل لتظهر الخيارات هنا.',
            style: TextStyle(fontSize: 13, color: context.mutedText),
          )
        else if (grouped)
          for (final color in _options.colors)
            _colorCard(context, color, showSku: showSku)
        else
          _Panel(
            children: [
              for (final row in rows)
                _comboRow(context, row.color, row.size,
                    grouped: false, showSku: showSku),
            ],
          ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(totals, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  Widget _colorCard(
    BuildContext context,
    OptionColor color, {
    required bool showSku,
  }) {
    final colorStock = _field('color-stock:${color.key}');
    return _Panel(
      children: [
        Row(
          children: [
            _SwatchDot(fill: colorFromHex(color.hex), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _colorLabel(color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: colorStock,
                keyboardType: TextInputType.number,
                inputFormatters: [_digitsOnly],
                decoration: InputDecoration(
                  labelText: context.tr('الكمية'),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 3,
              child: OutlinedButton(
                onPressed: () {
                  final value = colorStock.text.trim();
                  if (value.isNotEmpty) {
                    _options.setColorStock(color.key, value);
                  }
                },
                child: const AppText('تطبيق على هذا اللون',
                    maxLines: 2, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
        for (final size in _options.sizes)
          _comboRow(context, color, size,
              grouped: true, showSku: showSku),
      ],
    );
  }

  Widget _comboRow(
    BuildContext context,
    OptionColor? color,
    String? size, {
    required bool grouped,
    required bool showSku,
  }) {
    final key = _comboKey(color?.key, size);
    final combo = _options.combo(color?.key, size);
    final label = grouped || color == null ? (size ?? '') : _colorLabel(color);
    final muted = TextStyle(fontSize: 12, color: context.mutedText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 16),
        MergeSemantics(
          child: Row(
            children: [
              if (!grouped && color != null) ...[
                _SwatchDot(fill: colorFromHex(color.hex), size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              AppText('متوفر', style: muted),
              Switch(
                key: ValueKey('options-available:$key'),
                value: combo.available,
                onChanged: (v) {
                  combo.available = v;
                  _options.comboChanged();
                },
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ValueKey('options-stock:$key'),
                controller: _field('stock:$key', combo.stock),
                enabled: combo.available,
                keyboardType: TextInputType.number,
                inputFormatters: [_digitsOnly],
                onChanged: (v) {
                  combo.stock = v;
                  _options.comboChanged();
                },
                decoration: InputDecoration(
                  labelText: context.tr('الكمية'),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: ValueKey('options-price:$key'),
                controller: _field('price:$key', combo.priceIncrease),
                enabled: combo.available,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_decimalOnly],
                onChanged: (v) {
                  combo.priceIncrease = v;
                  _options.comboChanged();
                },
                decoration: InputDecoration(
                  labelText: context.tr('زيادة السعر (ل.س)'),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        if (showSku) ...[
          const SizedBox(height: 8),
          TextField(
            key: ValueKey('options-sku:$key'),
            controller: _field('sku:$key', combo.sku),
            enabled: combo.available,
            inputFormatters: [LengthLimitingTextInputFormatter(100)],
            onChanged: (v) {
              combo.sku = v;
              _options.comboChanged();
            },
            decoration: InputDecoration(
              labelText: context.tr('رمز SKU'),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppText(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

/// إطار بطاقة لون (أو قائمة التركيبات بلا ألوان) بحدود تناسب الوضعين.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      decoration: BoxDecoration(
        border: Border.all(color: context.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _BulkField extends StatelessWidget {
  const _BulkField({
    required this.label,
    required this.controller,
    required this.formatter,
    required this.keyboardType,
    required this.onApply,
  });

  final String label;
  final TextEditingController controller;
  final TextInputFormatter formatter;
  final TextInputType keyboardType;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: [formatter],
            onSubmitted: (_) => onApply(),
            decoration: InputDecoration(
              labelText: context.tr(label),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onApply, child: const AppText('تطبيق')),
      ],
    );
  }
}

/// دائرة اللون. بلا درجة (لون قديم مكتوب كلمة) تُرسم مخططة بألوان محايدة.
class _SwatchDot extends StatelessWidget {
  const _SwatchDot({required this.fill, required this.size, this.selected = false});

  final Color? fill;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = fill;
    Widget inner;
    if (color == null) {
      inner = ClipOval(
        child: CustomPaint(
          size: Size.square(size),
          painter: _StripesPainter(
            background: scheme.surfaceContainerHighest,
            stripe: scheme.outline,
          ),
        ),
      );
    } else {
      final ink = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : Colors.black87;
      inner = DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: selected
            ? Icon(Icons.check, size: size * 0.5, color: ink)
            : const SizedBox.expand(),
      );
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(selected ? 3 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? scheme.primary : context.cardBorder,
          width: selected ? 2.5 : 1,
        ),
      ),
      child: inner,
    );
  }
}

class _StripesPainter extends CustomPainter {
  const _StripesPainter({required this.background, required this.stripe});

  final Color background;
  final Color stripe;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = stripe
      ..strokeWidth = size.width / 10;
    final step = size.width / 4;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.stripe != stripe;
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.label,
    required this.fill,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? fill;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SwatchDot(fill: fill, size: 40, selected: selected),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtherColorTile extends StatelessWidget {
  const _OtherColorTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('لون آخر');
    return SizedBox(
      width: 58,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.cardBorder),
                  ),
                  child: Icon(Icons.add, color: context.accent),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({this.initialName});

  final String? initialName;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName ?? '');
  double _hue = 200;
  double _saturation = 0.6;
  double _brightness = 0.7;
  String? _error;

  Color get _color =>
      HSVColor.fromAHSV(1, _hue, _saturation, _brightness).toColor();

  String get _hex {
    final rgb = _color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتب اسم اللون.');
      return;
    }
    Navigator.of(context).pop((name: name, hex: _hex));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: const AppText('لون آخر'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              decoration: InputDecoration(
                labelText: context.tr('اسم اللون'),
                errorText: error == null ? null : context.tr(error),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.cardBorder),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _hex,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _slider('درجة اللون', _hue, 360, (v) => _hue = v),
            _slider('التشبع', _saturation, 1, (v) => _saturation = v),
            _slider('السطوع', _brightness, 1, (v) => _brightness = v),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const AppText('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const AppText('إضافة')),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, style: TextStyle(fontSize: 12, color: context.mutedText)),
        Slider(
          value: value,
          max: max,
          semanticFormatterCallback: (v) =>
              '${context.tr(label)} ${v.toStringAsFixed(max > 1 ? 0 : 2)}',
          onChanged: (v) => setState(() => onChanged(v)),
        ),
      ],
    );
  }
}
