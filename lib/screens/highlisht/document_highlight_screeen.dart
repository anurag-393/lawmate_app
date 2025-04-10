import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:lawmate_ai_app/core/constants/app_theme.dart';
import 'package:lawmate_ai_app/core/constants/app_colors.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_view/photo_view.dart';

class DocumentAnalysisScreen extends StatefulWidget {
  const DocumentAnalysisScreen({Key? key})
    : super(key: key);

  @override
  _DocumentAnalysisScreenState createState() =>
      _DocumentAnalysisScreenState();
}

class _DocumentAnalysisScreenState
    extends State<DocumentAnalysisScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController =
      ScrollController();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isAttachmentMenuOpen = false;
  bool _isLoading = false;
  // bool _isSpeaking = false;

  // Store the source document
  File? _sourceDocument;
  String? _sourceDocumentName;
  String? _sourceDocumentMimeType;

  // Store the comparison result document
  File? _comparisonDocument;
  String? _comparisonDocumentName;
  String? _comparisonDocumentMimeType;
  bool _isViewingComparison = false;

  // Store the comparison response text
  String? _comparisonText;
  bool _isTyping = false;

  // API endpoint
  final String apiUrl =
      'http://192.168.0.198:8000/highlight/';

  // @override
  // void initState() {
  //   super.initState();
  //   _initTts();
  // }

  // void _initTts() {
  //   _flutterTts.setStartHandler(() {
  //     setState(() {
  //       _isSpeaking = true;
  //     });
  //   });

  //   _flutterTts.setCompletionHandler(() {
  //     setState(() {
  //       _isSpeaking = false;
  //     });
  //   });

  //   _flutterTts.setErrorHandler((message) {
  //     setState(() {
  //       _isSpeaking = false;
  //     });
  //   });
  // }

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

  // Future<void> _speak(String text) async {
  //   if (_isSpeaking) {
  //     await _flutterTts.stop();
  //     setState(() {
  //       _isSpeaking = false;
  //     });
  //   } else {
  //     await _flutterTts.speak(text);
  //   }
  // }

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

  // Function to download document to device storage
  Future<void> _downloadDocument(File document) async {
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

      final String fileName =
          _comparisonDocumentName ??
          'document${path.extension(document.path)}';
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

  Future _compareDocuments() async {
    if (_sourceDocument == null) return;

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

      // Add the source file with proper content type
      final sourceMimeType =
          _sourceDocumentMimeType ??
          _getMimeType(_sourceDocument!.path);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          await _sourceDocument!.readAsBytes(),
          filename: path.basename(_sourceDocument!.path),
          contentType: MediaType.parse(sourceMimeType),
        ),
      );

      // Send the request
      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        // Get filename from content-disposition header
        final contentDisposition =
            streamedResponse.headers['content-disposition'];
        String filename = 'highlighted_document.pdf';

        if (contentDisposition != null &&
            contentDisposition.contains('filename=')) {
          final filenameRegex = RegExp(r'filename=([^;]+)');
          final match = filenameRegex.firstMatch(
            contentDisposition,
          );
          if (match != null && match.groupCount >= 1) {
            filename = match.group(1)!.trim();
          }
        }

        // Get content type
        final contentType =
            streamedResponse.headers['content-type'] ??
            'application/pdf';

        // Read response bytes
        final bytes =
            await streamedResponse.stream.toBytes();

        // Save file
        final tempDir = await getTemporaryDirectory();
        final documentPath = '${tempDir.path}/$filename';
        File comparisonFile = File(documentPath);
        await comparisonFile.writeAsBytes(bytes);

        setState(() {
          _comparisonDocument = comparisonFile;
          _comparisonDocumentName = filename;
          _comparisonDocumentMimeType = contentType;
          _comparisonText =
              "Document analysis complete. View highlighted document below.";
          _isTyping = false;
          _isLoading = false;
        });

        _scrollToBottom();
      } else {
        setState(() {
          _isTyping = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: Server returned status code ${streamedResponse.statusCode}',
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
          _sourceDocument = imageFile;
          _sourceDocumentName = pickedImage.name;
          _sourceDocumentMimeType = mimeType;
          _comparisonText =
              null; // Clear previous comparison
          _comparisonDocument = null;
          _isViewingComparison = false;
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
          _sourceDocument = documentFile;
          _sourceDocumentName = file.name;
          _sourceDocumentMimeType = mimeType;
          _comparisonText =
              null; // Clear previous comparison
          _comparisonDocument = null;
          _isViewingComparison = false;
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

  void _toggleDocumentView() {
    if (_comparisonDocument != null) {
      setState(() {
        _isViewingComparison = !_isViewingComparison;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Document Analysis',
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
          if (_comparisonDocument != null)
            IconButton(
              icon: Icon(
                _isViewingComparison
                    ? Icons.text_snippet
                    : Icons.description,
              ),
              onPressed: _toggleDocumentView,
              tooltip:
                  _isViewingComparison
                      ? 'View Analysis'
                      : 'View Document',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text(
                        'About Document Analysis',
                      ),
                      content: const Text(
                        'This module allows you to analyze documents. Upload a document first, then generate an analysis.',
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
                  _sourceDocument == null
                      ? _buildEmptyState()
                      : _isViewingComparison &&
                          _comparisonDocument != null
                      ? _buildDocumentViewer()
                      : _buildComparisonContent(),
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
            Icons.file_copy,
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
            'Start by uploading a document to generate an analysis',
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

  Widget _buildComparisonContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document preview area
          if (_sourceDocument != null)
            _buildDocumentPreview(),

          const SizedBox(height: 16),

          // Comparison header
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Document Analysis',
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

          // Comparison or typing indicator
          _isTyping
              ? _buildTypingIndicator()
              : _comparisonText != null
              ? _buildComparisonText()
              : _buildGeneratePrompt(),
        ],
      ),
    );
  }

  Widget _buildDocumentViewer() {
    if (_comparisonDocument == null) {
      return Center(child: Text('No document available'));
    }

    final bool isPdf =
        _comparisonDocumentMimeType?.contains('pdf') ??
        false;
    final bool isImage =
        _comparisonDocumentMimeType?.startsWith('image/') ??
        false;

    if (isPdf) {
      return Stack(
        children: [
          PDFView(
            filePath: _comparisonDocument!.path,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false,
            pageFling: false,
            onError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error loading PDF: $error',
                  ),
                  backgroundColor: AppColors.errorColor,
                ),
              );
            },
            onPageError: (page, error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error loading page $page: $error',
                  ),
                  backgroundColor: AppColors.errorColor,
                ),
              );
            },
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed:
                  () => _downloadDocument(
                    _comparisonDocument!,
                  ),
              backgroundColor: AppColors.primaryColor,
              child: Icon(
                Icons.download,
                color: Colors.white,
              ),
              tooltip: 'Download Document',
            ),
          ),
        ],
      );
    } else if (isImage) {
      return Stack(
        children: [
          PhotoView(
            imageProvider: FileImage(_comparisonDocument!),
            backgroundDecoration: BoxDecoration(
              color: Colors.transparent,
            ),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed:
                  () => _downloadDocument(
                    _comparisonDocument!,
                  ),
              backgroundColor: AppColors.primaryColor,
              child: Icon(
                Icons.download,
                color: Colors.white,
              ),
              tooltip: 'Download Document',
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_present,
                    size: 48,
                    color: AppColors.primaryColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'This document type cannot be previewed directly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.backgroundColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please download it to view on your device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed:
                        () => _downloadDocument(
                          _comparisonDocument!,
                        ),
                    icon: Icon(Icons.download),
                    label: Text('Download Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
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
          ),
        ],
      );
    }
  }

  Widget _buildDocumentPreview() {
    final bool isImage =
        _sourceDocumentMimeType?.startsWith('image/') ??
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
                  _sourceDocumentName ?? 'Document',
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
                _sourceDocument!,
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
    if (_sourceDocumentMimeType == null)
      return Icons.insert_drive_file;

    if (_sourceDocumentMimeType!.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (_sourceDocumentMimeType!.contains('word') ||
        _sourceDocumentMimeType!.contains('doc')) {
      return Icons.description;
    } else if (_sourceDocumentMimeType!.contains('text') ||
        _sourceDocumentMimeType!.contains('txt')) {
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

  Widget _buildComparisonText() {
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
                  _comparisonText!,
                  style: const TextStyle(
                    color: AppColors.textColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),

          // Add document, speech, and download buttons
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (_comparisonDocument != null)
                  ElevatedButton.icon(
                    onPressed: _toggleDocumentView,
                    icon: Icon(Icons.description),
                    label: Text('View Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.surfaceColor,
                      foregroundColor:
                          AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          8,
                        ),
                      ),
                    ),
                  ),
                // ElevatedButton.icon(
                //   onPressed: () {
                //     if (_comparisonText != null) {
                //       _speak(_comparisonText!);
                //     }
                //   },
                //   icon: Icon(
                //     _isSpeaking
                //         ? Icons.stop
                //         : Icons.volume_up,
                //   ),
                //   label: Text(
                //     _isSpeaking ? 'Stop' : 'Speak Aloud',
                //   ),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: AppColors.primaryColor,
                //     foregroundColor: Colors.white,
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(
                //         8,
                //       ),
                //     ),
                //   ),
                // ),
                if (_comparisonDocument != null)
                  ElevatedButton.icon(
                    onPressed:
                        () => _downloadDocument(
                          _comparisonDocument!,
                        ),
                    icon: Icon(Icons.download),
                    label: Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.surfaceColor,
                      foregroundColor:
                          AppColors.primaryColor,
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
            'Your document is ready for analysis',
            style: TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: 28,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Click the "Generate Analysis" button below to get an AI-generated analysis of your document.',
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
                  _sourceDocument != null && !_isLoading
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
                      _sourceDocument != null && !_isLoading
                          ? _compareDocuments
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
                              'Generate Analysis',
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
