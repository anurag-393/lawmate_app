import 'package:flutter/material.dart';
import 'package:lawmate_ai_app/screens/welcome_screen.dart';

import 'package:hive_flutter/hive_flutter.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:lawmate_ai_app/core/model/conversation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(ConversationAdapter());
  Hive.registerAdapter(MessageAdapter());
  Hive.registerAdapter(DocumentSummaryAdapter());
  Hive.registerAdapter(HighlightedDocumentAdapter());

  // Open boxes
  await Hive.openBox<Conversation>('conversations');
  await Hive.openBox<DocumentSummary>('document_summaries');
  await Hive.openBox<HighlightedDocument>(
    'highlighted_documents',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BE Project',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
