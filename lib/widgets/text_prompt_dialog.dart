import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../l10n/app_localizations.dart';

/// نافذة تطلب نصاً (سبب أو ملاحظة) وتعيده، أو null عند الإلغاء.
/// النافذة تملك حقلها، فلا يُغلق الحقل قبل انتهاء حركة الإغلاق.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  bool required = false,
  String emptyError = 'هذا الحقل مطلوب.',
  int maxLength = 2000,
  int maxLines = 4,
  Key? fieldKey,
  Key? sendKey,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextPromptDialog(
        title: title,
        label: label,
        required: required,
        emptyError: emptyError,
        maxLength: maxLength,
        maxLines: maxLines,
        fieldKey: fieldKey,
        sendKey: sendKey,
      ),
    );

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.required,
    required this.emptyError,
    required this.maxLength,
    required this.maxLines,
    this.fieldKey,
    this.sendKey,
  });

  final String title;
  final String label;
  final bool required;
  final String emptyError;
  final int maxLength;
  final int maxLines;
  final Key? fieldKey;
  final Key? sendKey;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final value = _text.text.trim();
    if (widget.required && value.isEmpty) {
      setState(() => _error = widget.emptyError);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: AppText(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          key: widget.fieldKey,
          controller: _text,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
              labelText: context.tr(widget.label),
              border: const OutlineInputBorder()),
        ),
        if (_error != null)
          AppText(_error!, style: const TextStyle(color: AppColors.danger)),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('إلغاء')),
        FilledButton(
          key: widget.sendKey,
          onPressed: _send,
          child: const AppText('إرسال'),
        ),
      ],
    );
  }
}
