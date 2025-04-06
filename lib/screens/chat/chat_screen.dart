import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:lawmate_ai_app/core/constants/app_theme.dart';
import 'package:path/path.dart' as path;
import 'package:lawmate_ai_app/core/constants/app_colors.dart';
import 'package:http_parser/http_parser.dart'; // Add this import

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController =
      TextEditingController();
  final ScrollController _scrollController =
      ScrollController();
  final List<ChatMessage> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isAttachmentMenuOpen = false;
  bool _isLoading = false;

  // Store the currently active document for multiple queries
  File? _activeDocument;
  String? _activeDocumentName;
  String?
  _activeDocumentMimeType; // Add this to track the mime type

  // API endpoint
  final String apiUrl = 'http://192.168.0.198:8000/query/';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Add user message to chat
    setState(() {
      _messages.add(
        ChatMessage(
          text: messageText,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _messageController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Check if we have an active document to query against
      if (_activeDocument != null) {
        await _sendQueryToBackend(
          messageText,
          _activeDocument!,
        );
      } else {
        // No document to query against
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  "Please upload a document first to query against it.",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Error processing your request: $e",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  // Helper function to determine MIME type
  String _getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream'; // Default binary type
    }
  }

  Future<void> _sendQueryToBackend(
    String query,
    File documentFile,
  ) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      // Add the query parameter
      request.fields['query'] = query;

      // Add the file with proper content type
      final mimeType =
          _activeDocumentMimeType ??
          _getMimeType(documentFile.path);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          await documentFile.readAsBytes(),
          filename: path.basename(documentFile.path),
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Show typing indicator
      setState(() {
        _messages.add(
          ChatMessage(
            text: "",
            isUser: false,
            timestamp: DateTime.now(),
            isTyping: true,
          ),
        );
      });
      _scrollToBottom();

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(
        streamedResponse,
      );

      // Remove typing indicator
      setState(() {
        _messages.removeLast();
      });

      if (response.statusCode == 200) {
        // Parse the response
        var jsonResponse = json.decode(response.body);
        String responseText =
            jsonResponse['result'] ?? "No response data";

        setState(() {
          _messages.add(
            ChatMessage(
              text: responseText,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  "Error: Server returned status code ${response.statusCode}. ${response.body}",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Network error: $e",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedImage = await _imagePicker
          .pickImage(source: source);
      if (pickedImage != null) {
        final File imageFile = File(pickedImage.path);
        final String mimeType = _getMimeType(
          pickedImage.path,
        );

        setState(() {
          _messages.add(
            ChatMessage(
              text: "Image uploaded: ${pickedImage.name}",
              isUser: true,
              timestamp: DateTime.now(),
              attachment: AttachmentInfo(
                path: pickedImage.path,
                name: pickedImage.name,
                type: AttachmentType.image,
              ),
            ),
          );
          _isLoading = true;
        });

        _scrollToBottom();

        // Set as active document with MIME type
        _activeDocument = imageFile;
        _activeDocumentName = pickedImage.name;
        _activeDocumentMimeType = mimeType;

        // Ask for the first query
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  "Image uploaded successfully. What would you like to know about this document?",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
    setState(() => _isAttachmentMenuOpen = false);
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(
            type: FileType.custom,
            allowedExtensions: [
              'pdf',
              'doc',
              'docx',
              'txt',
            ],
          );

      if (result != null &&
          result.files.single.path != null) {
        final PlatformFile file = result.files.first;
        final File documentFile = File(file.path!);
        final String mimeType = _getMimeType(file.path!);

        setState(() {
          _messages.add(
            ChatMessage(
              text: "Document uploaded: ${file.name}",
              isUser: true,
              timestamp: DateTime.now(),
              attachment: AttachmentInfo(
                path: file.path!,
                name: file.name,
                type: AttachmentType.document,
              ),
            ),
          );
          _isLoading = true;
        });

        _scrollToBottom();

        // Set as active document with MIME type
        _activeDocument = documentFile;
        _activeDocumentName = file.name;
        _activeDocumentMimeType = mimeType;

        // Ask for the first query
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  "Document uploaded successfully. What would you like to know about this document?",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking document: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
    setState(() => _isAttachmentMenuOpen = false);
  }

  // Rest of the code remains unchanged
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Lawmate AI',
              style: TextStyle(color: AppColors.textColor),
            ),
            if (_activeDocumentName != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Active: ${_activeDocumentName!}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppColors.surfaceColor,
        iconTheme: const IconThemeData(
          color: AppColors.secondaryTextColor,
        ),
        elevation: 0,
        actions: [
          if (_activeDocument != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _activeDocument = null;
                  _activeDocumentName = null;
                  _activeDocumentMimeType = null;
                  _messages.add(
                    ChatMessage(
                      text:
                          "Document removed. Please upload a new document to continue.",
                      isUser: false,
                      timestamp: DateTime.now(),
                    ),
                  );
                });
                _scrollToBottom();
              },
              tooltip: 'Clear active document',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text(
                        'About Chat Assistant',
                      ),
                      content: const Text(
                        'This chat module allows you to communicate with the LawMate AI assistant. Upload a document first, then ask questions about its content.',
                      ),
                      actions: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor:
                                const Color.fromRGBO(
                                  255,
                                  255,
                                  255,
                                  1,
                                ), // Text color
                            overlayColor: AppColors
                                .primaryColor
                                .withOpacity(
                                  0.2,
                                ), // Color when pressed
                          ),
                          onPressed:
                              () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat messages list
            Expanded(
              child:
                  _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageItem(
                            _messages[index],
                          );
                        },
                      ),
            ),

            // Attachment menu (conditionally visible)
            if (_isAttachmentMenuOpen)
              _buildAttachmentMenu(),

            // Message input area
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Icon(
            Icons.upload_file,
            size: 40,
            color: AppColors.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
          ),
          child: Text(
            'Upload a Document',
            style:
                Theme.of(context).textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
          ),
          child: Text(
            'Start by uploading a document, then ask questions about its content',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _isAttachmentMenuOpen = true;
            });
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Container(
            decoration: AppTheme.gradientButtonDecoration,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 12,
            ),
            child: const Text(
              'Upload Document',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final bool isUser = message.isUser;
    final formattedTime = DateFormat(
      'h:mm a',
    ).format(message.timestamp);

    // For typing indicator
    if (message.isTyping == true) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(false),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(
                  16,
                ).copyWith(
                  bottomLeft: const Radius.circular(4),
                ),
              ),
              child: const SizedBox(
                width: 40,
                child: Row(
                  children: [
                    _TypingDot(delay: 0),
                    _TypingDot(delay: 300),
                    _TypingDot(delay: 600),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(isUser),

          const SizedBox(width: 8),

          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                    0.75,
              ),
              decoration: BoxDecoration(
                color:
                    isUser
                        ? AppColors.primaryColor
                        : AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(
                  16,
                ).copyWith(
                  bottomRight:
                      isUser
                          ? const Radius.circular(4)
                          : null,
                  bottomLeft:
                      !isUser
                          ? const Radius.circular(4)
                          : null,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Display attachment if present
                  if (message.attachment != null)
                    _buildAttachmentPreview(
                      message.attachment!,
                    ),

                  // Message text
                  Text(
                    message.text,
                    style: TextStyle(
                      color:
                          isUser
                              ? Colors.white
                              : AppColors.textColor,
                      fontSize: 14,
                    ),
                  ),

                  // Timestamp
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      formattedTime,
                      style: TextStyle(
                        color:
                            isUser
                                ? Colors.white.withOpacity(
                                  0.7,
                                )
                                : AppColors
                                    .secondaryTextColor,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          if (isUser) _buildAvatar(isUser),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color:
            isUser
                ? AppColors.buttonGradientEnd.withOpacity(
                  0.2,
                )
                : AppColors.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Icon(
          isUser ? Icons.person : Icons.auto_awesome,
          size: 16,
          color:
              isUser
                  ? AppColors.buttonGradientEnd
                  : AppColors.primaryColor,
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(
    AttachmentInfo attachment,
  ) {
    final bool isImage =
        attachment.type == AttachmentType.image;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child:
          isImage
              ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(attachment.path),
                  height: 150,
                  fit: BoxFit.cover,
                ),
              )
              : ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                leading: const Icon(
                  Icons.insert_drive_file,
                ),
                title: Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                dense: true,
              ),
    );
  }

  Widget _buildAttachmentMenu() {
    return Container(
      color: AppColors.backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAttachmentOption(
            icon: Icons.photo_library,
            label: 'Gallery',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
          _buildAttachmentOption(
            icon: Icons.camera_alt,
            label: 'Camera',
            onTap: () => _pickImage(ImageSource.camera),
          ),
          _buildAttachmentOption(
            icon: Icons.insert_drive_file,
            label: 'Document',
            onTap: _pickDocument,
          ),
          _buildAttachmentOption(
            icon: Icons.close,
            label: 'Cancel',
            onTap:
                () => setState(
                  () => _isAttachmentMenuOpen = false,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.backgroundColor,
      child: Row(
        children: [
          // Attachment button
          GestureDetector(
            onTap: () {
              setState(() {
                _isAttachmentMenuOpen =
                    !_isAttachmentMenuOpen;
              });
            },
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.attach_file,
                color:
                    _isAttachmentMenuOpen
                        ? AppColors.primaryColor
                        : AppColors.secondaryTextColor,
              ),
            ),
          ),

          // Message text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                textCapitalization:
                    TextCapitalization.sentences,
                style: const TextStyle(
                  color: AppColors.textColor,
                ),
                maxLines: null,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText:
                      _activeDocument == null
                          ? 'Upload a document first...'
                          : 'Ask a question about the document...',
                  hintStyle: const TextStyle(
                    color: AppColors.secondaryTextColor,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          // Send button
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(left: 8),
              decoration:
                  _isLoading
                      ? BoxDecoration(
                        color: AppColors.surfaceColor,
                        borderRadius: BorderRadius.circular(
                          20,
                        ),
                      )
                      : AppTheme.gradientButtonDecoration,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                        ),
                      )
                      : const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

// Small animated typing indicator component
class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  __TypingDotState createState() => __TypingDotState();
}

class __TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    Future.delayed(
      Duration(milliseconds: widget.delay),
      () {
        if (mounted) {
          _controller.repeat(reverse: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(
              0.5 + _animation.value * 0.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

// Models
enum AttachmentType { image, document }

class AttachmentInfo {
  final String path;
  final String name;
  final AttachmentType type;

  AttachmentInfo({
    required this.path,
    required this.name,
    required this.type,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final AttachmentInfo? attachment;
  final bool isTyping;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.attachment,
    this.isTyping = false,
  });
}
