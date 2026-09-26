import 'package:drift/drift.dart';
import '../../domain/models/enums.dart';

@TableIndex(name: 'idx_conversations_updated_at', columns: {#updatedAt})
class Conversations extends Table {
  TextColumn get id => text()(); // uuid v4
  TextColumn get title => text().withDefault(const Constant('New chat'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()(); // index; list ordering
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get providerId => text().nullable()(); // pinned model per convo
  TextColumn get modelId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_messages_convo_seq', columns: {#conversationId, #seq})
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().customConstraint('NOT NULL REFERENCES conversations(id) ON DELETE CASCADE')();
  TextColumn get role => text().map(const EnumNameConverter(MessageRole.values))(); // user|assistant|tool|system
  TextColumn get status => text().map(const EnumNameConverter(MessageStatus.values))(); // pending|streaming|complete|failed
  TextColumn get content => text().named('text').withDefault(const Constant(''))();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get seq => integer()(); // monotonic per conversation
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get messageId =>
      text().customConstraint('NOT NULL REFERENCES messages(id) ON DELETE CASCADE')();
  TextColumn get relativePath => text()(); // under <appSupport>/attachments/
  TextColumn get thumbRelativePath => text().nullable()();
  TextColumn get mimeType => text()();
  IntColumn get byteSize => integer()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_tool_invocations_msg_id', columns: {#messageId})
class ToolInvocations extends Table {
  TextColumn get id => text()();
  TextColumn get messageId =>
      text().customConstraint('NOT NULL REFERENCES messages(id) ON DELETE CASCADE')();
  TextColumn get toolName => text()(); // e.g. notion.create_tasks
  TextColumn get source => text().map(const EnumNameConverter(ToolSource.values))(); // builtin|mcp
  TextColumn get serverId => text().nullable()(); // which MCP server
  TextColumn get argumentsJson => text()();
  TextColumn get resultJson => text().nullable()();
  TextColumn get status => text().map(const EnumNameConverter(ToolStatus.values))(); // pending|running|ok|error|undone
  TextColumn get errorMessage => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class QuickPrompts extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get promptText => text()();
  IntColumn get sortOrder => integer()();
  BoolColumn get builtin => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
