class AppConstants {
  static const String appName = "Voice-First";
  static const String defaultBackendUrl = "http://127.0.0.1:5000";
  static const String defaultUserId = "student_user_1";

  // Spoken Greetings
  static const String initialGreeting = "Voice-First is ready. What would you like to do?";

  // Core Voice Commands Help Text
  static const List<String> coreVoiceCommands = [
    "Start [Subject] lecture (e.g. Start Biology lecture)",
    "Note: [content] (e.g. Note: Mitosis is cell division)",
    "Tag this as important / definition / example / general",
    "Correct [wrong word] to [right word]",
    "Find my notes about [topic]",
    "Read today's [Subject] notes",
    "Next / Previous / Repeat / Stop / Exit",
    "End lecture",
  ];

  static const List<String> extendedVoiceCommands = [
    "Start flashcard revision for [Subject]",
    "Easy / Medium / Hard / Skip / Explain",
    "Quiz me on everything important from this week",
    "Revise my weak topics",
    "Bookmark this / Read my bookmarks",
    "Where did I note [topic]?",
    "What did I note around 11 AM?",
    "What topics did I cover today?",
  ];
}
