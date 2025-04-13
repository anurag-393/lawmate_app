import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lawmate_ai_app/core/constants/app_colors.dart';
import 'package:lawmate_ai_app/core/services/storage_service.dart';
import 'package:lawmate_ai_app/screens/chat/chat_screen.dart';
import 'package:lawmate_ai_app/screens/summary/document_summary_history_detail_screen.dart';
import 'package:lawmate_ai_app/screens/summary/summary_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SavedItemsScreen extends StatelessWidget {
  final StorageService _storageService = StorageService();

  Future<void> _downloadDocument(
    File document,
    BuildContext context,
  ) async {
    try {
      // For simplicity, we'll save it to the downloads directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception(
          'Could not access storage directory',
        );
      }

      final downloadsDir = Directory(
        '${directory.path}/Downloads',
      );
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final String fileName = "highlighted_document.pdf";
      final String filePath =
          '${downloadsDir.path}/$fileName';

      // Copy the file
      await document.copy(filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Document saved to Downloads: $fileName',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed:
                () => Share.shareXFiles([
                  XFile(
                    filePath,
                  ), // Convert the string path to an XFile
                ], text: 'Sharing $fileName'),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving document: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Saved Items'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Conversations'),
              Tab(text: 'Summaries'),
              Tab(text: 'Highlighted Docs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildConversationsTab(),
            _buildSummariesTab(),
            _buildHighlightedDocsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsTab() {
    final conversations =
        _storageService.getAllConversations();

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return ListTile(
          title: Text(conversation.documentName),
          subtitle: Text(
            'Messages: ${conversation.messages.length} • ${_formatDate(conversation.timestamp)}',
          ),
          onTap: () {
            // Navigate to view conversation
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => ChatScreen(
                      conversationId: conversation.id,
                    ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummariesTab() {
    final summaries =
        _storageService.getAllDocumentSummaries();

    return ListView.builder(
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return ListTile(
          title: Text(summary.documentName),
          subtitle: Text(_formatDate(summary.timestamp)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => ViewSummaryScreen(
                      summaryId: summary.id,
                    ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHighlightedDocsTab() {
    final documents =
        _storageService.getAllHighlightedDocuments();

    return ListView.builder(
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        return ListTile(
          title: Text(document.documentName),
          subtitle: Text(_formatDate(document.timestamp)),
          trailing: IconButton(
            icon: Icon(Icons.download),
            onPressed: () {
              // Create a File object from the stored path
              final File documentFile = File(
                document.documentPath,
              );
              _downloadDocument(documentFile, context);
            },
          ),
          onTap: () {
            // Open the document
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
