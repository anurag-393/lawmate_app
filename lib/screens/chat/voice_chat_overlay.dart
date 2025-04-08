import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class VoiceChatOverlay extends StatefulWidget {
  final File? activeDocument;
  final String? activeDocumentName;
  final String? activeDocumentMimeType;
  final Function(String) onAddMessage;
  final String apiUrl;

  const VoiceChatOverlay({
    Key? key,
    required this.activeDocument,
    required this.activeDocumentName,
    required this.activeDocumentMimeType,
    required this.onAddMessage,
    required this.apiUrl,
  }) : super(key: key);

  @override
  _VoiceChatOverlayState createState() =>
      _VoiceChatOverlayState();
}

class _VoiceChatOverlayState
    extends State<VoiceChatOverlay> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _transcription = "";
  String _response = "";
  String _statusText = "Tap the mic to ask a question";

  bool _disposed =
      false; // Flag to track if widget is disposed
  Timer? _listeningTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initTts();
  }

  Future<void> _requestPermissions() async {
    if (!mounted) return;

    // Request microphone permission
    PermissionStatus microphoneStatus =
        await Permission.microphone.request();

    if (!mounted) return;

    if (microphoneStatus.isDenied) {
      _updateStatus("Microphone permission denied");
      return;
    }

    if (microphoneStatus.isPermanentlyDenied) {
      // The user opted to never again see the permission request dialog.
      _showOpenSettingsDialog();
      return;
    }

    // Now initialize speech recognition
    await _initSpeech();
  }

  void _showOpenSettingsDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Voice chat requires microphone permission. Please enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  // Initialize speech recognition
  Future<void> _initSpeech() async {
    if (!mounted) return;

    try {
      // Request permission explicitly before initializing
      bool permissionGranted = await _speech.initialize(
        onStatus: (status) {
          if (mounted) _onSpeechStatus(status);
        },
        onError: (error) {
          if (mounted) {
            _updateStatus("Error: $error");
            setState(() {
              _isListening = false;
            });
          }
        },
      );

      if (!mounted) return;

      if (!permissionGranted) {
        _updateStatus(
          "Speech recognition permission denied",
        );

        // Show dialog to explain why permission is needed
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text(
                    'Microphone Permission Required',
                  ),
                  content: const Text(
                    'This app needs microphone access to enable voice chat. Please grant permission in your device settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _updateStatus("Failed to initialize speech: $e");
      }
    }
  }

  // Initialize text-to-speech
  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _flutterTts.setErrorHandler((error) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _updateStatus("TTS Error: $error");
        });
      }
    });
  }

  void _onSpeechStatus(String status) {
    debugPrint("Speech status: $status");
    if (!mounted) return;

    if (status == "listening") {
      setState(() {
        _isListening = true;
        _statusText = "Listening...";
      });
    } else if (status == "done" ||
        status == "notListening") {
      // When speech recognition completes naturally
      if (_isListening) {
        setState(() {
          _isListening = false;
        });

        // Process the query if we have transcription
        if (_transcription.isNotEmpty) {
          _processQuery(_transcription);
        }
      }
    }
  }

  void _updateStatus(String status) {
    if (mounted) {
      setState(() {
        _statusText = status;
      });
    }
  }

  // Start listening for speech
  void _startListening() async {
    if (!mounted || _isListening || _isProcessing) return;

    setState(() {
      _transcription = "";
      _response = "";
      _statusText = "Starting to listen...";
    });

    if (widget.activeDocument == null) {
      _updateStatus("Please upload a document first");
      await _speak(
        "Please upload a document first before asking questions.",
      );
      return;
    }

    try {
      // Cancel any existing timer
      _listeningTimer?.cancel();

      bool available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) _onSpeechStatus(status);
        },
        onError: (error) {
          if (mounted) {
            _updateStatus("Speech error: $error");
            setState(() {
              _isListening = false;
            });
          }
        },
      );

      if (!available) {
        _updateStatus("Speech recognition not available");
        return;
      }

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _transcription = result.recognizedWords;
              if (result.finalResult) {
                // When we get a final result, process it
                _isListening = false;
                _processQuery(_transcription);
              }
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        onSoundLevelChange: (level) {
          // Optional: visualize sound level
        },
        cancelOnError: true,
      );

      setState(() {
        _isListening = true;
        _statusText = "Listening...";
      });

      // Set up a timer to stop listening after the maximum duration
      // This ensures we always process even if callbacks fail
      _listeningTimer = Timer(
        const Duration(seconds: 30),
        () {
          if (_isListening) {
            _stopListening();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        _updateStatus(
          "Error starting speech recognition: $e",
        );
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  // Stop listening
  void _stopListening() async {
    _listeningTimer?.cancel();

    if (!mounted) return;

    try {
      await _speech.stop();

      setState(() {
        _isListening = false;
      });

      if (_transcription.isNotEmpty) {
        _processQuery(_transcription);
      }
    } catch (e) {
      if (mounted) {
        _updateStatus("Error stopping speech: $e");
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  // Send query to backend
  Future<void> _processQuery(String query) async {
    if (query.isEmpty || !mounted || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _updateStatus("Processing...");
    });

    // Add user message to main chat
    widget.onAddMessage(query);

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(widget.apiUrl),
      );

      // Add the query parameter
      request.fields['query'] = query;

      // Add the file with proper content type
      final mimeType =
          widget.activeDocumentMimeType ??
          _getMimeType(widget.activeDocument!.path);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          await widget.activeDocument!.readAsBytes(),
          filename: path.basename(
            widget.activeDocument!.path,
          ),
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(
        streamedResponse,
      );

      if (!mounted)
        return; // Check if still mounted after network call

      if (response.statusCode == 200) {
        // Parse the response
        var jsonResponse = json.decode(response.body);
        String responseText =
            jsonResponse['result'] ?? "No response data";

        setState(() {
          _response = responseText;
          _isProcessing = false;
          _updateStatus("Response received");
        });

        // Add response to main chat
        widget.onAddMessage(responseText);

        // Speak the response
        if (mounted) {
          await _speak(responseText);
        }
      } else {
        final errorMessage =
            "Error: Server returned status code ${response.statusCode}";

        setState(() {
          _response = errorMessage;
          _isProcessing = false;
          _updateStatus("Error occurred");
        });

        // Add error to main chat
        widget.onAddMessage(errorMessage);

        // Speak error message
        if (mounted) {
          await _speak(
            "Sorry, there was an error processing your request.",
          );
        }
      }
    } catch (e) {
      if (!mounted)
        return; // Check if still mounted after exception

      final errorMessage = "Network error: $e";
      setState(() {
        _response = errorMessage;
        _isProcessing = false;
        _updateStatus("Network error");
      });

      // Add error to main chat
      widget.onAddMessage(errorMessage);

      // Speak error message
      await _speak("Sorry, there was a network error.");
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

  // Speak text using TTS
  Future<void> _speak(String text) async {
    if (text.isEmpty || !mounted) return;

    // Split long text into sentences to make it more manageable
    if (text.length > 4000) {
      // Split into sentences and speak in chunks
      List<String> sentences = text.split(
        RegExp(r'(?<=[.!?])\s+'),
      );
      for (var sentence in sentences) {
        if (!mounted)
          return; // Check if still mounted in the loop

        if (_isSpeaking) await _flutterTts.stop();
        await _flutterTts.speak(sentence);
        // Wait for speaking to complete
        await Future.delayed(
          const Duration(milliseconds: 2000),
        );
      }
    } else {
      if (_isSpeaking) await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  // Stop speaking
  Future<void> _stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true; // Mark as disposed
    _listeningTimer?.cancel();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 20),
      color: Colors.black.withOpacity(1),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Voice Assistant",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _stopSpeaking();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Active document info
              if (widget.activeDocumentName != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Active: ${widget.activeDocumentName}",
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Status text with visual indicator for listening state
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isListening)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(
                        right: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Transcription display
              // Add this to your VoiceChatOverlay widget, in the widget tree
              // Specifically in the Expanded section where you display the conversation
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Dynamic conversation content
                        if (_transcription.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(
                              12,
                            ),
                            margin: const EdgeInsets.only(
                              bottom: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue
                                  .withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "You:",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _transcription,
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Loading indicator while processing
                        if (_isProcessing) ...[
                          Container(
                            padding: const EdgeInsets.all(
                              12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green
                                  .withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "AI Assistant:",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    // Animated loading spinner
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<
                                              Color
                                            >(Colors.white),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 12,
                                    ),
                                    Text(
                                      "Processing your question...",
                                      style: TextStyle(
                                        color: Colors.white
                                            .withOpacity(
                                              0.8,
                                            ),
                                        fontStyle:
                                            FontStyle
                                                .italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else if (_response
                            .isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(
                              12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green
                                  .withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "AI Assistant:",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _response,
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Optional: If no content yet, show a placeholder
                        if (_transcription.isEmpty &&
                            _response.isEmpty &&
                            !_isProcessing)
                          SizedBox(
                            height:
                                MediaQuery.of(
                                  context,
                                ).size.height *
                                0.6,
                            child: Center(
                              child: Column(
                                mainAxisSize:
                                    MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .center,
                                children: [
                                  Icon(
                                    Icons.mic_none,
                                    color: Colors.white
                                        .withOpacity(0.4),
                                    size: 48,
                                  ),
                                  const SizedBox(
                                    height: 12,
                                  ),
                                  Text(
                                    "Tap the mic button to start a conversation",
                                    style: TextStyle(
                                      color: Colors.white
                                          .withOpacity(0.5),
                                      fontStyle:
                                          FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Control buttons
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  // Mic button with animated border when listening
                  Container(
                    width: _isListening ? 74 : 70,
                    height: _isListening ? 74 : 70,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border:
                          _isListening
                              ? Border.all(
                                color: Colors.red,
                                width: 2,
                              )
                              : null,
                    ),
                    child: GestureDetector(
                      onTap:
                          _isProcessing
                              ? null
                              : (_isListening
                                  ? _stopListening
                                  : _startListening),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color:
                              _isListening
                                  ? Colors.red
                                  : Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.stop
                              : Icons.mic,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  // Speaking control button (only visible when response is available)
                  if (_response.isNotEmpty)
                    GestureDetector(
                      onTap:
                          _isSpeaking
                              ? _stopSpeaking
                              : () => _speak(_response),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isSpeaking
                              ? Icons.volume_off
                              : Icons.volume_up,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
