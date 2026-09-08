class DialogueManager {
  String currentMode = "home"; // home, active_lecture, retrieval, audio_review, flashcard_active, quiz_active
  String? currentSessionId;
  String? currentSubject;
  String? lastNoteId;
  String? lastNoteText;
  
  List<dynamic> searchResults = [];
  String searchQuery = "";
  List<dynamic> reviewNotes = [];
  int currentIndex = 0;

  List<dynamic> flashcards = [];
  int currentCardIndex = 0;

  List<dynamic> quizItems = [];
  int currentQuizIndex = 0;
  double quizScore = 0.0;

  Map<String, dynamic> toContextMap() {
    return {
      "current_mode": currentMode,
      "current_session_id": currentSessionId,
      "current_subject": currentSubject,
      "last_note_id": lastNoteId,
      "last_note_text": lastNoteText,
      "search_results": searchResults,
      "search_query": searchQuery,
      "review_notes": reviewNotes,
      "current_index": currentIndex,
      "flashcards": flashcards,
      "current_card_index": currentCardIndex,
      "quiz_items": quizItems,
      "current_quiz_index": currentQuizIndex,
      "quiz_score": quizScore,
    };
  }

  void updateFromBackend(Map<String, dynamic> nextContext) {
    if (nextContext.containsKey("current_mode")) {
      currentMode = nextContext["current_mode"] ?? "home";
    }
    if (nextContext.containsKey("current_session_id")) {
      currentSessionId = nextContext["current_session_id"];
    }
    if (nextContext.containsKey("current_subject")) {
      currentSubject = nextContext["current_subject"];
    }
    if (nextContext.containsKey("last_note_id")) {
      lastNoteId = nextContext["last_note_id"];
    }
    if (nextContext.containsKey("last_note_text")) {
      lastNoteText = nextContext["last_note_text"];
    }
    if (nextContext.containsKey("search_results")) {
      searchResults = nextContext["search_results"] ?? [];
    }
    if (nextContext.containsKey("search_query")) {
      searchQuery = nextContext["search_query"] ?? "";
    }
    if (nextContext.containsKey("review_notes")) {
      reviewNotes = nextContext["review_notes"] ?? [];
    }
    if (nextContext.containsKey("current_index")) {
      currentIndex = nextContext["current_index"] ?? 0;
    }
    if (nextContext.containsKey("flashcards")) {
      flashcards = nextContext["flashcards"] ?? [];
    }
    if (nextContext.containsKey("current_card_index")) {
      currentCardIndex = nextContext["current_card_index"] ?? 0;
    }
    if (nextContext.containsKey("quiz_items")) {
      quizItems = nextContext["quiz_items"] ?? [];
    }
    if (nextContext.containsKey("current_quiz_index")) {
      currentQuizIndex = nextContext["current_quiz_index"] ?? 0;
    }
    if (nextContext.containsKey("quiz_score")) {
      quizScore = (nextContext["quiz_score"] as num?)?.toDouble() ?? 0.0;
    }
  }

  void resetToHome() {
    currentMode = "home";
    currentSessionId = null;
    currentSubject = null;
    searchResults = [];
    reviewNotes = [];
    currentIndex = 0;
    flashcards = [];
    quizItems = [];
  }
}
