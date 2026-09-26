import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db/database.dart';
import '../../../data/providers.dart';

final conversationSearchQueryProvider = StateProvider<String>((ref) => '');

final activeConversationIdProvider = StateProvider<String?>((ref) => null);

final conversationListProvider = StreamProvider<List<Conversation>>((ref) {
  final repo = ref.watch(conversationRepositoryProvider);
  final search = ref.watch(conversationSearchQueryProvider);
  return repo.watchConversations(search: search);
});

final recentConversationsProvider =
    FutureProvider.family<List<Conversation>, int>((ref, limit) async {
  final repo = ref.watch(conversationRepositoryProvider);
  return repo.getRecentConversations(limit: limit);
});

final lastMessagePreviewsProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final convosAsync = ref.watch(conversationListProvider);
  final convos = convosAsync.valueOrNull ?? [];
  final ids = convos.map((c) => c.id).toList();
  if (ids.isEmpty) return {};
  final messageRepo = ref.watch(messageRepositoryProvider);
  return messageRepo.lastMessagePreviewFor(ids);
});

final conversationListControllerProvider =
    Provider<ConversationListController>((ref) {
  return ConversationListController(ref);
});

class ConversationListController {
  ConversationListController(this._ref);

  final Ref _ref;

  Future<Conversation> createNewConversation({String? title, bool force = false}) async {
    if (!force) {
      final activeId = _ref.read(activeConversationIdProvider);
      if (activeId != null) {
        final messageRepo = _ref.read(messageRepositoryProvider);
        final messages = await messageRepo.getMessages(activeId);
        if (messages.isEmpty) {
          final convoRepo = _ref.read(conversationRepositoryProvider);
          final currentConvo = await convoRepo.getConversationById(activeId);
          if (currentConvo != null) {
            return currentConvo;
          }
        }
      }
    }

    final repo = _ref.read(conversationRepositoryProvider);
    final convo = await repo.createConversation(title: title ?? 'New chat');
    _ref.read(activeConversationIdProvider.notifier).state = convo.id;
    return convo;
  }

  Future<void> selectConversation(String id) async {
    _ref.read(activeConversationIdProvider.notifier).state = id;
  }

  Future<void> renameConversation(String id, String title) async {
    final repo = _ref.read(conversationRepositoryProvider);
    await repo.renameConversation(id, title);
  }

  Future<void> togglePin(String id, bool pinned) async {
    final repo = _ref.read(conversationRepositoryProvider);
    await repo.togglePin(id, pinned);
  }

  Future<void> togglePinned(String id) async {
    final repo = _ref.read(conversationRepositoryProvider);
    final convo = await repo.getConversationById(id);
    if (convo != null) {
      await repo.togglePin(id, !convo.pinned);
    }
  }

  Future<void> toggleArchive(String id, bool archived) async {
    final repo = _ref.read(conversationRepositoryProvider);
    await repo.toggleArchive(id, archived);
  }

  Future<void> toggleArchived(String id) async {
    final repo = _ref.read(conversationRepositoryProvider);
    final convo = await repo.getConversationById(id);
    if (convo != null) {
      await repo.toggleArchive(id, !convo.archived);
    }
  }

  Future<void> deleteConversation(String id) async {
    final repo = _ref.read(conversationRepositoryProvider);
    if (_ref.read(activeConversationIdProvider) == id) {
      _ref.read(activeConversationIdProvider.notifier).state = null;
    }
    await repo.deleteConversation(id);
  }
}
