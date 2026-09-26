import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/ui/mitra_icon_button.dart';
import '../../../../core/ui/mitra_section.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../application/settings_controller.dart';

class McpSection extends ConsumerStatefulWidget {
  final AppSettings settings;

  const McpSection({
    super.key,
    required this.settings,
  });

  @override
  ConsumerState<McpSection> createState() => _McpSectionState();
}

class _McpSectionState extends ConsumerState<McpSection> {
  final TextEditingController _mcpUrlCtrl = TextEditingController();
  final TextEditingController _mcpTokenCtrl = TextEditingController();

  final FocusNode _mcpUrlFocus = FocusNode();
  final FocusNode _mcpTokenFocus = FocusNode();

  bool _obscureMcp = true;
  String? _mcpTestStatus;
  bool _isTestingMcp = false;

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final secStore = ref.read(secretStoreProvider);
    final prefsStore = ref.read(prefsStoreProvider);

    _mcpUrlCtrl.text = prefsStore.mcpBaseUrl;
    _mcpTokenCtrl.text = await secStore.getMcpToken('mitra') ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mcpUrlCtrl.dispose();
    _mcpTokenCtrl.dispose();
    _mcpUrlFocus.dispose();
    _mcpTokenFocus.dispose();
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

    return MitraSection(
      title: 'Mitra MCP Gateway',
      subtitle:
          'Connect to MCP tools for Azure DevOps, Clockify, Calendar & WakaTime',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _mcpUrlCtrl,
            focusNode: _mcpUrlFocus,
            decoration: const InputDecoration(
              labelText: 'MCP Server Base URL',
              hintText: 'http://localhost:8080',
            ),
            onSubmitted: (val) => settingsCtrl.setMcpBaseUrl(val.trim()),
          ),
          SizedBox(height: space.md),
          TextField(
            controller: _mcpTokenCtrl,
            focusNode: _mcpTokenFocus,
            obscureText: _obscureMcp,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [],
            decoration: InputDecoration(
              labelText: 'Bearer Token (Optional)',
              hintText: 'Bearer token for Mitra gateway',
              helperText: _mcpTokenCtrl.text.isNotEmpty
                  ? '✓ Configured & saved'
                  : 'Not configured (Optional)',
              helperStyle: TextStyle(
                color: _mcpTokenCtrl.text.isNotEmpty ? status.success.color : null,
                fontWeight: _mcpTokenCtrl.text.isNotEmpty ? FontWeight.w600 : null,
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
                        _mcpTokenCtrl.text = data.text!.trim();
                        await settingsCtrl.setMcpToken('mitra', data.text!.trim());
                        _showSnackBar('MCP token pasted and saved');
                      }
                    },
                  ),
                  MitraIconButton(
                    icon: Icon(
                      _obscureMcp
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    semanticLabel: _obscureMcp ? 'Reveal secret' : 'Hide secret',
                    onPressed: () => setState(() => _obscureMcp = !_obscureMcp),
                  ),
                  MitraIconButton(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    semanticLabel: 'Save token',
                    tooltip: 'Save',
                    onPressed: () async {
                      await settingsCtrl.setMcpToken('mitra', _mcpTokenCtrl.text.trim());
                      _showSnackBar('MCP token saved');
                    },
                  ),
                  SizedBox(width: space.xs),
                ],
              ),
            ),
          ),
          SizedBox(height: space.lg),
          Wrap(
            spacing: space.sm,
            runSpacing: space.sm,
            children: [
              FilledButton.tonalIcon(
                onPressed: _isTestingMcp
                    ? null
                    : () async {
                        setState(() {
                          _isTestingMcp = true;
                          _mcpTestStatus = null;
                        });

                        await settingsCtrl.setMcpBaseUrl(_mcpUrlCtrl.text.trim());
                        await settingsCtrl.setMcpToken(
                            'mitra', _mcpTokenCtrl.text.trim());

                        final res = await settingsCtrl.testMcpConnection(
                          _mcpUrlCtrl.text.trim(),
                          token: _mcpTokenCtrl.text.trim(),
                        );
                        setState(() {
                          _isTestingMcp = false;
                          _mcpTestStatus = res.when(
                            ok: (msg) => '✅ $msg',
                            err: (f) => '❌ ${f.message}',
                          );
                        });
                      },
                icon: _isTestingMcp
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cable_rounded, size: 18),
                label: const Text('Test MCP Connection'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(agentRuntimeProvider).ensureReady(force: true);
                  final runtime = ref.read(agentRuntimeProvider);
                  final count = runtime.toolRegistry.all.length;
                  _showSnackBar('MCP skills reloaded! $count tools available.');
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reload Skills & Tools'),
              ),
            ],
          ),
          if (_mcpTestStatus != null) ...[
            SizedBox(height: space.sm),
            Text(
              _mcpTestStatus!,
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
