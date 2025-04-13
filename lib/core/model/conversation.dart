import 'package:hive/hive.dart';

part 'conversation.g.dart';

@HiveType(typeId: 0)
class Conversation {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String documentName;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final List<Message> messages;

  @HiveField(4)
  final String? documentPath; // Add this field

  @HiveField(5)
  final String? documentMimeType; // Also useful to store

  Conversation({
    required this.id,
    required this.documentName,
    required this.timestamp,
    required this.messages,
    this.documentPath,
    this.documentMimeType,
  });
}

@HiveType(typeId: 1)
class Message {
  @HiveField(0)
  final bool isUser;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final DateTime timestamp;

  Message({
    required this.isUser,
    required this.content,
    required this.timestamp,
  });
}

@HiveType(typeId: 2)
class DocumentSummary {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String documentName;

  @HiveField(2)
  final String summary;

  @HiveField(3)
  final DateTime timestamp;

  DocumentSummary({
    required this.id,
    required this.documentName,
    required this.summary,
    required this.timestamp,
  });
}

@HiveType(typeId: 3)
class HighlightedDocument {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String documentName;

  @HiveField(2)
  final String documentPath; // This could be a path to the stored document

  @HiveField(3)
  final DateTime timestamp;

  HighlightedDocument({
    required this.id,
    required this.documentName,
    required this.documentPath,
    required this.timestamp,
  });
}
