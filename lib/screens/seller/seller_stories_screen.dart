import 'dart:io';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/coupon_story.dart';
import '../../services/seller_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import '../../utils/image_picker_helper.dart';

class SellerStoriesScreen extends StatefulWidget {
  const SellerStoriesScreen({super.key});

  @override
  State<SellerStoriesScreen> createState() => _SellerStoriesScreenState();
}

class _SellerStoriesScreenState extends State<SellerStoriesScreen> {
  final SellerService _service = SellerService();

  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _service.myStories();
      setState(() => _data = data);
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
    final fee = (_data!['fee'] as num?)?.toDouble() ?? 0.0;
    final balance = (_data!['wallet_balance'] as num?)?.toDouble() ?? 0.0;

    if (balance < fee) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const AppText('رصيدك غير كافٍ'),
          content: AppText(
            'رسم نشر ستوري واحدة ${fee.toStringAsFixed(0)} ل.س، ورصيد محفظتك حالياً ${balance.toStringAsFixed(0)} ل.س فقط.\n\nاربح من مبيعاتك أولاً أو تواصل مع الإدارة.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const AppText('حسناً'))
          ],
        ),
      );
      return;
    }

    XFile? pickedImage;
    final captionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const AppText('ستوري جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8)),
                  child: AppText(
                    'رح يُخصم ${fee.toStringAsFixed(0)} ل.س من محفظتك (${balance.toStringAsFixed(0)} ل.س متوفر) '
                    'مقابل نشر الستوري بالصفحة الرئيسية لمدة 24 ساعة.',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
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
                    width: 140,
                    height: 200,
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
                  maxLength: 150,
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

                try {
                  await _service.createStory(
                      image: pickedImage!,
                      caption: captionController.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: AppText('تم نشر الستوري لمدة 24 ساعة.')),
                    );
                  }
                } on ApiException catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: AppText(e.message)));
                  }
                }
              },
              child: AppText('ادفع ${fee.toStringAsFixed(0)} ل.س وانشر'),
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
          if (_data != null)
            IconButton(
                tooltip: context.tr('إضافة قصة'),
                icon: const Icon(Icons.add), onPressed: _showCreateDialog),
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
    if (_data == null) {
      return const LoadingIndicator();
    }

    final fee = (_data!['fee'] as num?)?.toDouble() ?? 0.0;
    final balance = (_data!['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    final stories = (_data!['stories'] as List?)?.cast<StoryModel>() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('رصيد محفظتك',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12)),
                      AppText('${balance.toStringAsFixed(0)} ل.س',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('رسم النشر (24 ساعة)',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12)),
                      AppText('${fee.toStringAsFixed(0)} ل.س',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (stories.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: AppStateMessage(
                message: 'لسا ما نشرت أي ستوري. اضغط + بالأعلى لنشر أول واحدة.',
                icon: Icons.auto_stories_outlined),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: stories.length,
            itemBuilder: (context, index) {
              final story = stories[index];
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
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11)),
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
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
