import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lawmate_ai_app/core/constants/app_colors.dart';
import 'package:lawmate_ai_app/core/services/storage_service.dart';
import 'package:lawmate_ai_app/screens/chat/chat_screen.dart';
import 'package:lawmate_ai_app/screens/summary/document_summary_history_detail_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SavedItemsScreen extends StatelessWidget {
  final StorageService _storageService = StorageService();

  // Define category colors
  static const Color conversationColor = Color(
    0xFF6B4EFF,
  ); // Purple for conversations
  static const Color summaryColor = Color(
    0xFFB476FF,
  ); // Lavender for summaries
  static const Color highlightedDocsColor = Color(
    0xFFFF6B8A,
  ); // Pink for highlighted docs

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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed:
                () => Share.shareXFiles([
                  XFile(filePath),
                ], text: 'Sharing $fileName'),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving document: $e'),
          backgroundColor: AppColors.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          iconTheme: IconThemeData(
            color: AppColors.textColor,
          ),
          elevation: 0,
          backgroundColor: AppColors.backgroundColor,
          title: Text(
            'History',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: AppColors.textColor,
            ),
          ),
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 18,
            ),
            tabs: [
              Tab(
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: conversationColor,
                ),
                text: 'Chats',
              ),
              Tab(
                icon: Icon(
                  Icons.summarize_outlined,
                  color: summaryColor,
                ),
                text: 'Summaries',
              ),
              Tab(
                icon: Icon(
                  Icons.description_outlined,
                  color: highlightedDocsColor,
                ),
                text: 'Analysis',
              ),
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

    if (conversations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline,
        message: "No saved conversations yet",
        color: conversationColor,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _buildCard(
          context,
          title: conversation.documentName,
          subtitle:
              'Messages: ${conversation.messages.length} • ${_formatDate(conversation.timestamp)}',
          icon: Icons.chat_bubble_outline,
          color: conversationColor,
          onTap: () {
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

    if (summaries.isEmpty) {
      return _buildEmptyState(
        icon: Icons.summarize_outlined,
        message: "No saved summaries yet",
        color: summaryColor,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return _buildCard(
          context,
          title: summary.documentName,
          subtitle: _formatDate(summary.timestamp),
          icon: Icons.summarize_outlined,
          color: summaryColor,
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

    if (documents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.description_outlined,
        message: "No highlighted documents yet",
        color: highlightedDocsColor,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        return _buildCard(
          context,
          title: document.documentName,
          subtitle: _formatDate(document.timestamp),
          icon: Icons.description_outlined,
          color: highlightedDocsColor,
          onTap: () {
            // Open the document
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.remove_red_eye_outlined,
                  color: Colors.white70,
                ),
                tooltip: "View document",
                onPressed: () {
                  // View document implementation
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.download_outlined,
                  color: Colors.white70,
                ),
                tooltip: "Download document",
                onPressed: () {
                  // Create a File object from the stored path
                  final File documentFile = File(
                    document.documentPath,
                  );
                  _downloadDocument(documentFile, context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      color: AppColors.surfaceColor,
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),

                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.descriptiveText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.secondaryTextColor,
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
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
