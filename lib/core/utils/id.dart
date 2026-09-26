import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a standard UUID v4.
String generateId() => _uuid.v4();
