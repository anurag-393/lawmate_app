import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:lawmate_ai_app/core/services/storage_service.dart';
import 'package:path/path.dart' as path;
import 'package:lawmate_ai_app/core/constants/app_theme.dart';
import 'package:lawmate_ai_app/core/constants/app_colors.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DocumentSummaryScreen extends StatefulWidget {
  const DocumentSummaryScreen({super.key});

  @override
  _DocumentSummaryScreenState createState() =>
      _DocumentSummaryScreenState();
}

class _DocumentSummaryScreenState
    extends State<DocumentSummaryScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController =
      ScrollController();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isAttachmentMenuOpen = false;
  bool _isLoading = false;
  bool _isSpeaking = false;

  // Store the active document
  File? _activeDocument;
  String? _activeDocumentName;
  String? _activeDocumentMimeType;

  // Store the summary response
  String? _summary;
  bool _isTyping = false;

  final StorageService _storageService = StorageService();

  // API endpoint
  final String apiUrl =
      'http://192.168.0.197:8000/summarize/';

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> saveDocumentSummary(
    String documentName,
    String summary,
  ) async {
    final summaryId = await _storageService
        .saveDocumentSummary(documentName, summary);

    // You might want to display a success message or navigate to a summary view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Summary saved successfully')),
    );
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setErrorHandler((message) {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _flutterTts.stop();
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

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
    } else {
      await _flutterTts.speak(text);
    }
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

  Future<void> _generateSummary() async {
    if (_activeDocument == null) return;

    setState(() {
      _isLoading = true;
      _isTyping = true;
    });

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      // Add the file with proper content type
      final mimeType =
          _activeDocumentMimeType ??
          _getMimeType(_activeDocument!.path);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          await _activeDocument!.readAsBytes(),
          filename: path.basename(_activeDocument!.path),
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode == 200) {
        // Parse the response
        var jsonResponse = json.decode(response.body);
        String summaryText =
            jsonResponse['gemini_result'] ??
            "No summary data available";

        setState(() {
          _summary = summaryText;
          _isTyping = false;
          _isLoading = false;
        });

        // Automatically save the summary after it's generated
        if (_activeDocumentName != null) {
          await saveDocumentSummary(
            _activeDocumentName!,
            summaryText,
          );
        }

        _scrollToBottom();
      } else {
        setState(() {
          _isTyping = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: Server returned status code ${response.statusCode}',
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
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
          _activeDocument = imageFile;
          _activeDocumentName = pickedImage.name;
          _activeDocumentMimeType = mimeType;
          _summary = null; // Clear previous summary
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
          _activeDocument = documentFile;
          _activeDocumentName = file.name;
          _activeDocumentMimeType = mimeType;
          _summary = null; // Clear previous summary
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Document Summary',
              style: TextStyle(
                color: AppColors.textColor,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceColor,
        iconTheme: const IconThemeData(
          color: AppColors.secondaryTextColor,
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text(
                        'About Document Summary',
                      ),
                      content: const Text(
                        'This module allows you to get an AI-generated summary of your document. Upload a document first, then generate a summary.',
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
                                ),
                            overlayColor: AppColors
                                .primaryColor
                                .withOpacity(0.2),
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
            // Main content area
            Expanded(
              child:
                  _activeDocument == null
                      ? _buildEmptyState()
                      : _buildSummaryContent(),
            ),

            // Attachment menu (conditionally visible)
            if (_isAttachmentMenuOpen)
              _buildAttachmentMenu(),

            // Bottom action area
            _buildBottomActions(),
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
            'Start by uploading a document to generate an AI summary',
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

  Widget _buildSummaryContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document preview area
          if (_activeDocument != null)
            _buildDocumentPreview(),

          const SizedBox(height: 16),

          // Summary header
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Document Summary',
                style: TextStyle(fontSize: 25),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: AppTheme.pillDecoration,
                child: const Text(
                  'AI Generated',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Summary or typing indicator
          _isTyping
              ? _buildTypingIndicator()
              : _summary != null
              ? _buildSummaryText()
              : _buildGeneratePrompt(),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview() {
    final bool isImage =
        _activeDocumentMimeType?.startsWith('image/') ??
        false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isImage
                    ? Icons.image
                    : Icons.insert_drive_file,
                color: AppColors.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _activeDocumentName ?? 'Document',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Show image preview if it's an image
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _activeDocument!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          // For non-image documents, show an icon
          if (!isImage)
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  _getMimeTypeIcon(),
                  size: 32,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getMimeTypeIcon() {
    if (_activeDocumentMimeType == null)
      return Icons.insert_drive_file;

    if (_activeDocumentMimeType!.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (_activeDocumentMimeType!.contains('word') ||
        _activeDocumentMimeType!.contains('doc')) {
      return Icons.description;
    } else if (_activeDocumentMimeType!.contains('text') ||
        _activeDocumentMimeType!.contains('txt')) {
      return Icons.text_snippet;
    } else {
      return Icons.insert_drive_file;
    }
  }

  Widget _buildTypingIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(
                0.2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Row(
            children: [
              _TypingDot(delay: 0),
              _TypingDot(delay: 300),
              _TypingDot(delay: 600),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryText() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(
                    0.2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _summary!,
                  style: const TextStyle(
                    color: AppColors.textColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          // Add Speak Aloud button at the bottom of summary text
          if (_summary != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_summary != null) {
                        _speak(_summary!);
                      }
                    },
                    icon: Icon(
                      _isSpeaking
                          ? Icons.stop
                          : Icons.volume_up,
                    ),
                    label: Text(
                      _isSpeaking ? 'Stop' : 'Speak Aloud',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGeneratePrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Your document is ready for summarization',
            style: TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: 28,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Click the "Generate Summary" button below to get an AI-generated summary of your document.',
            style: TextStyle(
              color: AppColors.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

  Widget _buildBottomActions() {
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

          // Generate button (expanded)
          Expanded(
            child: Container(
              height: 48,
              decoration:
                  _activeDocument != null && !_isLoading
                      ? AppTheme.gradientButtonDecoration
                      : BoxDecoration(
                        color: AppColors.surfaceColor,
                        borderRadius: BorderRadius.circular(
                          24,
                        ),
                      ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      _activeDocument != null && !_isLoading
                          ? _generateSummary
                          : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<
                                      Color
                                    >(Colors.white),
                              ),
                            )
                            : const Text(
                              'Generate Summary',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
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
        curve: const Interval(
          0.0,
          1.0,
          curve: Curves.easeInOut,
        ),
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
