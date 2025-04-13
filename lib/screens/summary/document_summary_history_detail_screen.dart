import 'package:flutter/material.dart';
import 'package:lawmate_ai_app/core/services/storage_service.dart';
import 'package:lawmate_ai_app/core/constants/app_theme.dart';
import 'package:lawmate_ai_app/core/constants/app_colors.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ViewSummaryScreen extends StatefulWidget {
  final String summaryId;

  const ViewSummaryScreen({
    Key? key,
    required this.summaryId,
  }) : super(key: key);

  @override
  _ViewSummaryScreenState createState() =>
      _ViewSummaryScreenState();
}

class _ViewSummaryScreenState
    extends State<ViewSummaryScreen> {
  final ScrollController _scrollController =
      ScrollController();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isLoading = false;
  bool _isSpeaking = false;

  // Store the summary data
  String? _activeDocumentName;
  String? _summary;

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadSummary(widget.summaryId);
  }

  Future<void> _loadSummary(String summaryId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load the summary from storage
      final documentSummary = _storageService
          .getDocumentSummary(summaryId);

      if (documentSummary != null) {
        // Set the document name
        setState(() {
          _activeDocumentName =
              documentSummary.documentName;
          _summary = documentSummary.summary;
        });

        print(
          "Summary loaded successfully for: ${documentSummary.documentName}",
        );
      } else {
        print("Summary not found with ID: $summaryId");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Summary not found'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } catch (e) {
      print('Error loading summary: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading summary: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
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
                        'This shows an AI-generated summary of your document.',
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
        child:
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : _summary == null
                ? Center(child: Text('Summary not found'))
                : _buildSummaryContent(),
      ),
    );
  }

  Widget _buildSummaryContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document name card
          if (_activeDocumentName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _activeDocumentName!,
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
            ),

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

          // Summary text
          _buildSummaryText(),
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
                    backgroundColor: AppColors.primaryColor,
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
}
