import 'dart:io';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/coupon_story.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import '../../utils/image_picker_helper.dart';

class AdminStoriesScreen extends StatefulWidget {
  const AdminStoriesScreen({super.key});

  @override
  State<AdminStoriesScreen> createState() => _AdminStoriesScreenState();
}

class _AdminStoriesScreenState extends State<AdminStoriesScreen> {
  final AdminService _service = AdminService();
  List<StoryModel>? _stories;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final stories = await _service.stories();
      setState(() => _stories = stories);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الستوري.');
    }
  }

  Future<void> _delete(StoryModel story) async {
    try {
      await _service.deleteStory(story.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _showCreateDialog() async {
    XFile? pickedImage;
    final captionController = TextEditingController();
    final linkController = TextEditingController();
    final durationController = TextEditingController(text: '24');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const AppText('ستوري منصة جديدة (مجانية)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final result = await ImagePickerHelper.pickSingle();
                    if (result.accepted.isNotEmpty) {
                      setDialogState(() => pickedImage = result.accepted.first);
                    } else if (result.errors.isNotEmpty && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: AppText(result.errors.first)));
                    }
                  },
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.cardBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: pickedImage != null
                        ? Image.file(File(pickedImage!.path), fit: BoxFit.cover)
                        : const Icon(Icons.add_a_photo_outlined,
                            color: AppColors.emerald),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: captionController,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .translate('نص مختصر (اختياري)')),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('story-link-field'),
                  controller: linkController,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)
                        .translate('رابط الزر داخل الستوري (اختياري)'),
                    hintText: 'https://',
                    helperText: AppLocalizations.of(context).translate(
                        'انسخ رابط المنتج أو المتجر أو أي صفحة، وسيظهر للعميل زر «اكتشف الآن» يفتحه.'),
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .translate('مدة الظهور (ساعات)')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const AppText('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (pickedImage == null) return;
                final duration = int.tryParse(durationController.text) ?? 24;

                try {
                  await _service.createStory(
                      image: pickedImage!,
                      caption: captionController.text.trim(),
                      linkUrl: linkController.text.trim(),
                      durationHours: duration);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } on ApiException catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: AppText(e.message)));
                  }
                }
              },
              child: const AppText('نشر'),
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
        title: const AppText('الستوري'),
        actions: [
          IconButton(
              tooltip: context.tr('إضافة قصة'),
              icon: const Icon(Icons.add),
              onPressed: _showCreateDialog)
        ],
      ),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_stories == null) {
      return const LoadingIndicator();
    }
    if (_stories!.isEmpty) {
      return const AppStateMessage(
          message: 'لا يوجد ستوريات. اضغط + لنشر ستوري منصة مجانية.',
          icon: Icons.auto_stories_outlined);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _stories!.length,
      itemBuilder: (context, index) {
        final story = _stories![index];
        final isLive = story.isActive && !story.isExpired;
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                    imageUrl: story.image, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      story.isFromPlatform ? AppColors.gold : AppColors.emerald,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: AppText(
                  story.isFromPlatform ? 'المنصة' : (story.vendorName ?? ''),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
            if (isLive)
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: InkWell(
                  onTap: () => _delete(story),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Center(
                      child: AppText('إخفاء',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(4)),
                  child: const Center(
                    child: AppText('منتهية',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
