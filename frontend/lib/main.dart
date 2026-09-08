import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/theme.dart';
import 'core/constants/constants.dart';
import 'core/network/api_client.dart';
import 'core/services/tts_service.dart';
import 'core/services/stt_service.dart';
import 'core/services/voice_commander.dart';
import 'providers/notes_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/active_lecture_screen.dart';
import 'screens/voice_retrieval_screen.dart';
import 'screens/audio_review_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/flashcards_screen.dart';
import 'screens/quiz_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final ttsService = TTSService();
  final sttService = STTService();

  await ttsService.init();
  await sttService.init();

  final voiceCommander = VoiceCommander(
    ttsService: ttsService,
    sttService: sttService,
    apiClient: apiClient,
  );

  final notesProvider = NotesProvider(apiClient: apiClient);
  final settingsProvider = SettingsProvider();

  // Route automatic voice-triggered navigation
  voiceCommander.onActionTriggered = (action, data) {
    notesProvider.handleAction(action, data);

    switch (action) {
      case "NAVIGATE_ACTIVE_LECTURE":
        navigatorKey.currentState?.pushNamed('/active_lecture');
        break;
      case "NAVIGATE_RETRIEVAL":
        navigatorKey.currentState?.pushNamed('/retrieval');
        break;
      case "NAVIGATE_AUDIO_REVIEW":
        navigatorKey.currentState?.pushNamed('/audio_review');
        break;
      case "NAVIGATE_FLASHCARDS":
        navigatorKey.currentState?.pushNamed('/flashcards');
        break;
      case "NAVIGATE_QUIZ":
        navigatorKey.currentState?.pushNamed('/quiz');
        break;
      case "NAVIGATE_HOME":
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
        break;
    }
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: voiceCommander),
        ChangeNotifierProvider.value(value: notesProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: const VoiceFirstApp(),
    ),
  );
}

class VoiceFirstApp extends StatelessWidget {
  const VoiceFirstApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      navigatorKey: navigatorKey,
      theme: AccessibleTheme.themeData,
      debugShowCheckedModeBanner: false,
      initialRoute: '/home',
      routes: {
        '/': (context) => const HomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/active_lecture': (context) => const ActiveLectureScreen(),
        '/retrieval': (context) => const VoiceRetrievalScreen(),
        '/audio_review': (context) => const AudioReviewScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/flashcards': (context) => const FlashcardsScreen(),
        '/quiz': (context) => const QuizScreen(),
      },
    );
  }
}
