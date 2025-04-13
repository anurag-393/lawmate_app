import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../model/conversation.dart';

class StorageService {
  final Box<Conversation> _conversationsBox = Hive.box(
    'conversations',
  );
  final Box<DocumentSummary> _summariesBox = Hive.box(
    'document_summaries',
  );
  final Box<HighlightedDocument> _highlightedDocumentsBox =
      Hive.box('highlighted_documents');
  final _uuid = Uuid();

  // Save a new conversation
  Future<String> saveConversation(
    String documentName,
    List<Message> messages, {
    String? documentPath,
    String? documentMimeType,
  }) async {
    final id = _uuid.v4();
    final conversation = Conversation(
      id: id,
      documentName: documentName,
      timestamp: DateTime.now(),
      messages: messages,
      documentPath: documentPath,
      documentMimeType: documentMimeType,
    );

    await _conversationsBox.put(id, conversation);
    return id;
  }

  Future<String> saveDocumentFile(
    File sourceFile,
    String documentName,
  ) async {
    try {
      // Get app documents directory
      final appDir =
          await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDir.path}/documents');

      // Create directory if it doesn't exist
      if (!await docsDir.exists()) {
        await docsDir.create(recursive: true);
      }

      // Generate a unique filename based on timestamp and original name
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(sourceFile.path)}';
      final targetPath = '${docsDir.path}/$fileName';

      // Copy the file to app storage
      await sourceFile.copy(targetPath);

      return targetPath;
    } catch (e) {
      print('Error saving document: $e');
      throw e;
    }
  }

  // Add a message to an existing conversation
  Future<void> addMessageToConversation(
    String conversationId,
    Message message,
  ) async {
    final conversation = _conversationsBox.get(
      conversationId,
    );
    if (conversation != null) {
      final messages = [...conversation.messages, message];
      final updatedConversation = Conversation(
        id: conversation.id,
        documentName: conversation.documentName,
        timestamp: conversation.timestamp,
        messages: messages,
        documentPath:
            conversation
                .documentPath, // Preserve document path
        documentMimeType:
            conversation
                .documentMimeType, // Preserve MIME type
      );
      await _conversationsBox.put(
        conversationId,
        updatedConversation,
      );
    }
  }

  // Get all conversations
  List<Conversation> getAllConversations() {
    return _conversationsBox.values.toList();
  }

  // Get specific conversations
  Conversation? getConversation(String id) {
    try {
      return _conversationsBox.get(id);
    } catch (e) {
      print('Error retrieving conversation: $e');
      return null;
    }
  }

  // Save document summary
  Future<String> saveDocumentSummary(
    String documentName,
    String summary,
  ) async {
    final id = _uuid.v4();
    final documentSummary = DocumentSummary(
      id: id,
      documentName: documentName,
      summary: summary,
      timestamp: DateTime.now(),
    );

    await _summariesBox.put(id, documentSummary);
    return id;
  }

  // Get all document summaries
  List<DocumentSummary> getAllDocumentSummaries() {
    return _summariesBox.values.toList();
  }

  // Get a specific document summary by ID
  DocumentSummary? getDocumentSummary(String summaryId) {
    if (_summariesBox.containsKey(summaryId)) {
      return _summariesBox.get(summaryId);
    }
    return null;
  }

  // Save highlighted document
  Future<String> saveHighlightedDocument(
    String documentName,
    String documentPath,
  ) async {
    final id = _uuid.v4();
    final highlightedDocument = HighlightedDocument(
      id: id,
      documentName: documentName,
      documentPath: documentPath,
      timestamp: DateTime.now(),
    );

    await _highlightedDocumentsBox.put(
      id,
      highlightedDocument,
    );
    return id;
  }

  // Get all highlighted documents
  List<HighlightedDocument> getAllHighlightedDocuments() {
    return _highlightedDocumentsBox.values.toList();
  }

  // Delete a conversation
  Future<void> deleteConversation(String id) async {
    await _conversationsBox.delete(id);
  }

  // Delete a document summary
  Future<void> deleteDocumentSummary(String id) async {
    await _summariesBox.delete(id);
  }

  // Delete a highlighted document
  Future<void> deleteHighlightedDocument(String id) async {
    await _highlightedDocumentsBox.delete(id);
  }
}
