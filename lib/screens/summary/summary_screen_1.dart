import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:lawmate_ai_app/core/constants/app_theme.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({Key? key}) : super(key: key);

  @override
  _SummaryScreenState createState() =>
      _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  File? _selectedFile;
  String? _pdfContent;
  String _userText = '';
  bool _isLoading = false;
  String? _errorMessage;

  // Change this to your computer's IP address on your local network
  final String baseUrl =
      "http://192.168.0.197:8000"; // Replace X with your actual IP

  final TextEditingController _textController =
      TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _errorMessage = null; // Clear any previous errors
      });
    }
  }

  Future<void> _uploadDocument() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some text'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _pdfContent = null;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/'),
      );

      // Add the text field - required by your API
      request.fields['text'] = _textController.text;

      // Add the file to the request if selected
      if (_selectedFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'pdf_file',
            _selectedFile!.path,
          ),
        );
      }

      // Send the request
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'Connection timed out. Please check your server.',
          );
        },
      );

      var response = await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode == 200) {
        // Parse the JSON response
        var jsonResponse = json.decode(response.body);
        setState(() {
          _userText = jsonResponse['text'] ?? '';
          _pdfContent =
              jsonResponse['pdf_file_content'] ??
              'No PDF content available';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Server error: ${response.statusCode}. ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Document Summarizer',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Text Input Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter Legal Text',
                        style:
                            Theme.of(
                              context,
                            ).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _textController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Enter text to summarize...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // File Selection Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 64,
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedFile == null
                            ? 'No PDF selected (optional)'
                            : 'Selected: ${_selectedFile!.path.split('/').last}',
                        style:
                            Theme.of(
                              context,
                            ).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration:
                            AppTheme
                                .gradientButtonDecoration,
                        child: ElevatedButton(
                          onPressed: _pickFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.transparent,
                          ),
                          child: const Text(
                            'Select PDF (Optional)',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Upload Button
              Container(
                decoration:
                    AppTheme.gradientButtonDecoration,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : _uploadDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                          : const Text('Process Document'),
                ),
              ),

              // Error Message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Card(
                    color: Colors.red.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color:
                                      Colors.red.shade300,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Display Text Input
              if (_userText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Input',
                            style:
                                Theme.of(
                                  context,
                                ).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _userText,
                            style:
                                Theme.of(
                                  context,
                                ).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // PDF Content Display
              if (_pdfContent != null &&
                  _pdfContent!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PDF Content',
                            style:
                                Theme.of(
                                  context,
                                ).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _pdfContent!,
                            style:
                                Theme.of(
                                  context,
                                ).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
