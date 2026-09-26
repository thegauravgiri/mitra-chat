import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/agent/agent_runtime.dart';
import 'db/database.dart';
import 'repositories/conversation_repository.dart';
import 'repositories/message_repository.dart';
import 'repositories/settings_repository.dart';
import 'stores/attachment_store.dart';
import 'stores/prefs_store.dart';
import 'stores/secret_store.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main()');
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final secretStoreProvider = Provider<SecretStore>((ref) {
  return SecretStore();
});

final prefsStoreProvider = Provider<PrefsStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PrefsStore(prefs);
});

final attachmentStoreProvider = Provider<AttachmentStore>((ref) {
  return AttachmentStore();
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(
    db: ref.watch(databaseProvider),
    attachmentStore: ref.watch(attachmentStoreProvider),
  );
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(
    db: ref.watch(databaseProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    secretStore: ref.watch(secretStoreProvider),
    prefsStore: ref.watch(prefsStoreProvider),
    db: ref.watch(databaseProvider),
  );
});

final agentRuntimeProvider = Provider<AgentRuntime>((ref) {
  final secretStore = ref.watch(secretStoreProvider);
  final prefsStore = ref.watch(prefsStoreProvider);
  final runtime = AgentRuntime(
    secretStore: secretStore,
    prefsStore: prefsStore,
  );
  ref.onDispose(() {
    runtime.dispose();
  });
  return runtime;
});

final quickPromptsProvider = StreamProvider<List<QuickPrompt>>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return settingsRepo.watchQuickPrompts();
});

class ResolvedAttachment {
  final Attachment attachment;
  final File file;
  final File? thumbnailFile;

  const ResolvedAttachment({
    required this.attachment,
    required this.file,
    this.thumbnailFile,
  });
}

final messageAttachmentsProvider =
    FutureProvider.family<List<ResolvedAttachment>, String>((ref, messageId) async {
  final msgRepo = ref.watch(messageRepositoryProvider);
  final attStore = ref.watch(attachmentStoreProvider);
  final attachments = await msgRepo.getAttachmentsForMessage(messageId);
  final resolved = <ResolvedAttachment>[];
  for (final att in attachments) {
    final file = await attStore.resolveFile(att.relativePath);
    if (await file.exists()) {
      File? thumbFile;
      if (att.thumbRelativePath != null) {
        final tf = await attStore.resolveFile(att.thumbRelativePath!);
        if (await tf.exists()) {
          thumbFile = tf;
        }
      }
      resolved.add(ResolvedAttachment(
        attachment: att,
        file: file,
        thumbnailFile: thumbFile,
      ));
    }
  }
  return resolved;
});
