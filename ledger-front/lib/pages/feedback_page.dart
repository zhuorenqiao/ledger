import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../auth/auth_session.dart';
import '../data/api_client.dart';
import '../data/feedback_repository.dart';
import '../l10n/app_localizations.dart';

/// 意见反馈：写一段话（最多 1000 字），可附最多 3 张图；提交成功后回到上一页。
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, required this.session, this.repository});

  final AuthSession session;

  /// 测试可注入假实现；默认走真实后端接口。
  final FeedbackRepository? repository;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  /// 与后端 spring.servlet.multipart.max-file-size 保持一致，先在前端拦一次。
  static const _maxImageBytes = 2 * 1024 * 1024;

  late final FeedbackRepository _repository =
      widget.repository ?? FeedbackRepository(widget.session.api);

  final _content = TextEditingController();
  final List<FormFile> _images = [];

  bool _busy = false;
  String? _error;

  /// TextField 自己不会让父级重建，按钮的可用态需要在输入时刷新。
  bool get _canSubmit => !_busy && _content.text.trim().isNotEmpty;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.of(context);
    if (_images.length >= FeedbackRepository.maxImages) return;
    final picked = await FilePicker.pickFiles(type: FileType.image);
    if (picked.isEmpty || !mounted) return; // 空列表表示用户取消了选择

    // 系统选择器限不了数量，多出来的在这里截断；超尺寸的单独挑出来提示
    final added = <FormFile>[];
    final rejected = <String>[];
    for (final file in picked) {
      if (_images.length + added.length >= FeedbackRepository.maxImages) {
        rejected.add(l10n.imageTooMany(file.name, FeedbackRepository.maxImages));
        continue;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        rejected.add(l10n.imageTooBig(file.name));
        continue;
      }
      added.add((filename: file.name, bytes: bytes));
    }
    if (!mounted) return;
    setState(() {
      _images.addAll(added);
      if (rejected.isNotEmpty) {
        _error = l10n.imagesRejected(l10n.joinList(rejected));
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final content = _content.text.trim();
    if (content.isEmpty) {
      setState(() => _error = l10n.feedbackEmpty);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.submit(content: content, images: List.of(_images));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.errorText(e);
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(l10n.feedbackSubmitted)));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedbackTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.feedbackHeading, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    l10n.feedbackIntro,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _content,
                    enabled: !_busy,
                    maxLength: FeedbackRepository.maxContentLength,
                    minLines: 6,
                    maxLines: 10,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.feedbackHint,
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.imagesField, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    l10n.imagesLimit(FeedbackRepository.maxImages),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < _images.length; i++) _thumbnail(i),
                      if (_images.length < FeedbackRepository.maxImages) _addButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: kExpense, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.submit),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(int index) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            _images[index].bytes,
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            // 扩展名和内容对不上的图不该让整页崩掉
            errorBuilder: (context, error, stack) => Container(
              width: 88,
              height: 88,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.outline),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: Tooltip(
              message: l10n.removeImage,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _busy ? null : () => setState(() => _images.removeAt(index)),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addButton() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.pickImage,
      child: InkWell(
        onTap: _busy ? null : _pickImages,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text(l10n.addImage, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
