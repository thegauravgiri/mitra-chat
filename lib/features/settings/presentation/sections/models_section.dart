import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/tokens.dart';
import '../../../../core/ui/mitra_icon_button.dart';
import '../../../../core/ui/mitra_section.dart';
import '../../../../data/providers.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../integrations/llm/llm_types.dart';
import '../../application/settings_controller.dart';

class ModelsSection extends ConsumerStatefulWidget {
  final AppSettings settings;

  const ModelsSection({
    super.key,
    required this.settings,
  });

  @override
  ConsumerState<ModelsSection> createState() => _ModelsSectionState();
}

class _ModelsSectionState extends ConsumerState<ModelsSection> {
  final TextEditingController _geminiKeyCtrl = TextEditingController();
  final TextEditingController _anthropicKeyCtrl = TextEditingController();
  final TextEditingController _openAiKeyCtrl = TextEditingController();

  final FocusNode _geminiFocus = FocusNode();
  final FocusNode _anthropicFocus = FocusNode();
  final FocusNode _openAiFocus = FocusNode();

  bool _obscureGemini = true;
  bool _obscureAnthropic = true;
  bool _obscureOpenAi = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final secStore = ref.read(secretStoreProvider);
    _geminiKeyCtrl.text = await secStore.getGeminiApiKey() ?? '';
    _anthropicKeyCtrl.text = await secStore.getAnthropicApiKey() ?? '';
    _openAiKeyCtrl.text = await secStore.getOpenAiApiKey() ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _geminiKeyCtrl.dispose();
    _anthropicKeyCtrl.dispose();
    _openAiKeyCtrl.dispose();
    _geminiFocus.dispose();
    _anthropicFocus.dispose();
    _openAiFocus.dispose();
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

  Widget _buildSecretField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
    required bool obscured,
    required bool isConfigured,
    required VoidCallback onToggleObscure,
    required Future<void> Function(String) onSave,
  }) {
    final space = context.space;
    final status = context.status;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscured,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: const [],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: isConfigured ? '✓ Configured & saved' : 'Not configured',
        helperStyle: TextStyle(
          color: isConfigured ? status.success.color : null,
          fontWeight: isConfigured ? FontWeight.w600 : null,
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
                  controller.text = data.text!.trim();
                  await onSave(controller.text.trim());
                  _showSnackBar('$label pasted and saved');
                }
              },
            ),
            MitraIconButton(
              icon: Icon(
                obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18,
              ),
              semanticLabel: obscured ? 'Reveal secret' : 'Hide secret',
              onPressed: onToggleObscure,
            ),
            MitraIconButton(
              icon: const Icon(Icons.check_rounded, size: 18),
              semanticLabel: 'Save key',
              tooltip: 'Save',
              onPressed: () async {
                await onSave(controller.text.trim());
                _showSnackBar('$label saved');
              },
            ),
            SizedBox(width: space.xs),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final settingsCtrl = ref.read(settingsControllerProvider.notifier);
    final settings = widget.settings;

    final currentProviderModels = kAvailableModels
        .where((m) => m.providerId == settings.providerId)
        .toList();

    return MitraSection(
      title: 'AI Models',
      subtitle: 'Configure multimodal models and provider API keys',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: settings.providerId,
            decoration: const InputDecoration(
              labelText: 'Default Provider',
            ),
            items: const [
              DropdownMenuItem(
                value: 'gemini',
                child: Text('Google Gemini (Multimodal Vision)'),
              ),
              DropdownMenuItem(
                value: 'anthropic',
                child: Text('Anthropic Claude'),
              ),
              DropdownMenuItem(
                value: 'openai',
                child: Text('OpenAI GPT-4o'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                final defaultModel = kAvailableModels
                    .firstWhere((m) => m.providerId == val)
                    .id;
                settingsCtrl.setProviderAndModel(val, defaultModel);
              }
            },
          ),
          SizedBox(height: space.md),
          DropdownButtonFormField<String>(
            initialValue: currentProviderModels.any((m) => m.id == settings.modelId)
                ? settings.modelId
                : currentProviderModels.first.id,
            decoration: const InputDecoration(
              labelText: 'Selected Model',
            ),
            items: currentProviderModels.map((m) {
              return DropdownMenuItem(
                value: m.id,
                child: Text('${m.name}${m.isCheap ? " (Cheap)" : ""}'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                settingsCtrl.setProviderAndModel(
                  settings.providerId,
                  val,
                );
              }
            },
          ),
          SizedBox(height: space.lg),
          _buildSecretField(
            controller: _geminiKeyCtrl,
            focusNode: _geminiFocus,
            label: 'Gemini API Key',
            hintText: 'AI Studio Gemini API Key',
            obscured: _obscureGemini,
            isConfigured: settings.hasGeminiKey,
            onToggleObscure: () => setState(() => _obscureGemini = !_obscureGemini),
            onSave: (val) => settingsCtrl.setGeminiApiKey(val),
          ),
          SizedBox(height: space.md),
          _buildSecretField(
            controller: _anthropicKeyCtrl,
            focusNode: _anthropicFocus,
            label: 'Anthropic API Key',
            hintText: 'sk-ant-...',
            obscured: _obscureAnthropic,
            isConfigured: settings.hasAnthropicKey,
            onToggleObscure: () => setState(() => _obscureAnthropic = !_obscureAnthropic),
            onSave: (val) => settingsCtrl.setAnthropicApiKey(val),
          ),
          SizedBox(height: space.md),
          _buildSecretField(
            controller: _openAiKeyCtrl,
            focusNode: _openAiFocus,
            label: 'OpenAI API Key',
            hintText: 'sk-...',
            obscured: _obscureOpenAi,
            isConfigured: settings.hasOpenAiKey,
            onToggleObscure: () => setState(() => _obscureOpenAi = !_obscureOpenAi),
            onSave: (val) => settingsCtrl.setOpenAiApiKey(val),
          ),
        ],
      ),
    );
  }
}
