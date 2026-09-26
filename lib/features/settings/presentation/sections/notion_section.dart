import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/ui/mitra_icon_button.dart';
import '../../../../core/ui/mitra_section.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../application/settings_controller.dart';

class NotionSection extends ConsumerStatefulWidget {
  final AppSettings settings;

  const NotionSection({
    super.key,
    required this.settings,
  });

  @override
  ConsumerState<NotionSection> createState() => _NotionSectionState();
}

class _NotionSectionState extends ConsumerState<NotionSection> {
  final TextEditingController _notionTokenCtrl = TextEditingController();
  final TextEditingController _notionDbCtrl = TextEditingController();
  final TextEditingController _notionDsCtrl = TextEditingController();

  final FocusNode _notionTokenFocus = FocusNode();
  final FocusNode _notionDbFocus = FocusNode();
  final FocusNode _notionDsFocus = FocusNode();

  bool _obscureNotion = true;
  String? _notionTestStatus;
  bool _isTestingNotion = false;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final secStore = ref.read(secretStoreProvider);
    final prefsStore = ref.read(prefsStoreProvider);

    final token = await secStore.getNotionToken() ?? '';
    if (!mounted) return;

    _notionTokenCtrl.text = token;
    _notionDbCtrl.text = prefsStore.notionDatabaseId ?? '';
    _notionDsCtrl.text = prefsStore.notionDataSourceId ?? '';
    setState(() {});
  }

  @override
  void dispose() {
    _notionTokenCtrl.dispose();
    _notionDbCtrl.dispose();
    _notionDsCtrl.dispose();
    _notionTokenFocus.dispose();
    _notionDbFocus.dispose();
    _notionDsFocus.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.space;
    final status = context.status;
    final settingsCtrl = ref.read(settingsControllerProvider.notifier);
    final settings = widget.settings;

    return MitraSection(
      title: 'Notion Integration',
      subtitle: 'Direct BYOK Notion sync via 2025-09-03 API',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _notionTokenCtrl,
            focusNode: _notionTokenFocus,
            obscureText: _obscureNotion,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [],
            decoration: InputDecoration(
              labelText: 'Notion Integration Token',
              hintText: 'secret_...',
              helperText: settings.hasNotionToken
                  ? '✓ Configured & saved'
                  : 'Not configured',
              helperStyle: TextStyle(
                color: settings.hasNotionToken ? status.success.color : null,
                fontWeight: settings.hasNotionToken ? FontWeight.w600 : null,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MitraIconButton(
                    icon: const Icon(Icons.paste_rounded, size: 18),
                    semanticLabel: 'Paste from clipboard',
                    tooltip: 'Paste',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null && data!.text!.isNotEmpty) {
                        _notionTokenCtrl.text = data.text!.trim();
                        await settingsCtrl.setNotionToken(data.text!.trim());
                        _showSnackBar('Notion token pasted and saved');
                      }
                    },
                  ),
                  MitraIconButton(
                    icon: Icon(
                      _obscureNotion
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    semanticLabel: _obscureNotion ? 'Reveal secret' : 'Hide secret',
                    onPressed: () => setState(() => _obscureNotion = !_obscureNotion),
                  ),
                  MitraIconButton(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    semanticLabel: 'Save token',
                    tooltip: 'Save',
                    onPressed: () async {
                      await settingsCtrl.setNotionToken(_notionTokenCtrl.text.trim());
                      _showSnackBar('Notion token saved');
                    },
                  ),
                  SizedBox(width: space.xs),
                ],
              ),
            ),
          ),
          SizedBox(height: space.md),
          TextField(
            controller: _notionDbCtrl,
            focusNode: _notionDbFocus,
            decoration: const InputDecoration(
              labelText: 'Database ID / URL (Optional)',
              hintText: 'Optional: Auto-discovered by agent skills',
            ),
            onSubmitted: (val) => settingsCtrl.setNotionDatabaseId(val.trim()),
          ),
          SizedBox(height: space.md),
          TextField(
            controller: _notionDsCtrl,
            focusNode: _notionDsFocus,
            decoration: const InputDecoration(
              labelText: 'Data Source ID (Optional / Auto-resolved)',
              hintText: 'Auto-resolved from database schema',
            ),
            onSubmitted: (val) => settingsCtrl.setNotionDataSourceId(val.trim()),
          ),
          SizedBox(height: space.lg),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _isTestingNotion
                    ? null
                    : () async {
                        setState(() {
                          _isTestingNotion = true;
                          _notionTestStatus = null;
                        });

                        await settingsCtrl
                            .setNotionToken(_notionTokenCtrl.text.trim());
                        await settingsCtrl
                            .setNotionDatabaseId(_notionDbCtrl.text.trim());
                        if (_notionDsCtrl.text.trim().isNotEmpty) {
                          await settingsCtrl.setNotionDataSourceId(
                              _notionDsCtrl.text.trim());
                        }

                        final res = await settingsCtrl.testNotionConnection();
                        setState(() {
                          _isTestingNotion = false;
                          _notionTestStatus = res.when(
                            ok: (msg) => '✅ $msg',
                            err: (f) => '❌ ${f.message}',
                          );
                        });
                      },
                icon: _isTestingNotion
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 18),
                label: const Text('Test Notion Connection'),
              ),
            ],
          ),
          if (_notionTestStatus != null) ...[
            SizedBox(height: space.sm),
            Text(
              _notionTestStatus!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
