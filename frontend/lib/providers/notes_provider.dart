import 'package:flutter/foundation.dart';
import '../core/models/note_model.dart';
import '../core/models/session_model.dart';
import '../core/models/flashcard_model.dart';
import '../core/network/api_client.dart';

class NotesProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<NoteModel> _notes = [];
  NoteModel? _lastNote;
  SessionModel? _activeSession;
  
  List<NoteModel> _searchResults = [];
  String _searchQuery = "";
  int _searchIndex = 0;

  List<NoteModel> _reviewNotes = [];
  int _reviewIndex = 0;

  List<FlashcardModel> _flashcards = [];
  int _flashcardIndex = 0;
  bool _isCardFlipped = false;

  List<QuizQuestionModel> _quizItems = [];
  int _quizIndex = 0;
  double _quizScore = 0.0;
  QuizEvaluationModel? _lastQuizEvaluation;

  List<Map<String, dynamic>> _bookmarks = [];
  List<Map<String, dynamic>> _weakTopics = [];

  List<NoteModel> get notes => _notes;
  NoteModel? get lastNote => _lastNote;
  SessionModel? get activeSession => _activeSession;
  bool get hasActiveLecture => _activeSession != null && _activeSession!.isActive;

  List<NoteModel> get searchResults => _searchResults;
  String get searchQuery => _searchQuery;
  int get searchIndex => _searchIndex;
  NoteModel? get currentSearchNote => (_searchResults.isNotEmpty && _searchIndex < _searchResults.length) ? _searchResults[_searchIndex] : null;

  List<NoteModel> get reviewNotes => _reviewNotes;
  int get reviewIndex => _reviewIndex;
  NoteModel? get currentReviewNote => (_reviewNotes.isNotEmpty && _reviewIndex < _reviewNotes.length) ? _reviewNotes[_reviewIndex] : null;

  List<FlashcardModel> get flashcards => _flashcards;
  int get flashcardIndex => _flashcardIndex;
  bool get isCardFlipped => _isCardFlipped;
  FlashcardModel? get currentFlashcard => (_flashcards.isNotEmpty && _flashcardIndex < _flashcards.length) ? _flashcards[_flashcardIndex] : null;

  List<QuizQuestionModel> get quizItems => _quizItems;
  int get quizIndex => _quizIndex;
  double get quizScore => _quizScore;
  QuizEvaluationModel? get lastQuizEvaluation => _lastQuizEvaluation;
  QuizQuestionModel? get currentQuizItem => (_quizItems.isNotEmpty && _quizIndex < _quizItems.length) ? _quizItems[_quizIndex] : null;

  List<Map<String, dynamic>> get bookmarks => _bookmarks;
  List<Map<String, dynamic>> get weakTopics => _weakTopics;

  NotesProvider({required this.apiClient});

  Future<void> fetchNotes({String? subject, String? tag, String? timeframe}) async {
    _notes = await apiClient.getNotes(subject: subject, tag: tag, timeframe: timeframe);
    notifyListeners();
  }

  Future<void> fetchActiveSession() async {
    _activeSession = await apiClient.getActiveSession();
    notifyListeners();
  }

  Future<void> fetchLastNote() async {
    _lastNote = await apiClient.getLastNote();
    notifyListeners();
  }

  Future<void> fetchBookmarks() async {
    _bookmarks = await apiClient.getBookmarks();
    notifyListeners();
  }

  void toggleCardFlip() {
    _isCardFlipped = !_isCardFlipped;
    notifyListeners();
  }

  void nextFlashcard() {
    if (_flashcardIndex + 1 < _flashcards.length) {
      _flashcardIndex++;
      _isCardFlipped = false;
      notifyListeners();
    }
  }

  void previousFlashcard() {
    if (_flashcardIndex > 0) {
      _flashcardIndex--;
      _isCardFlipped = false;
      notifyListeners();
    }
  }

  void selectQuizOption(String optionLetter) {
    if (currentQuizItem != null) {
      final cleanLetter = optionLetter.trim().toUpperCase();
      currentQuizItem!.selectedOption = cleanLetter;
      if (cleanLetter == currentQuizItem!.correctAnswer) {
        _quizScore += 1.0;
      }
      notifyListeners();
    }
  }

  void nextQuizQuestion() {
    if (_quizIndex + 1 < _quizItems.length) {
      _quizIndex++;
      notifyListeners();
    }
  }

  void previousQuizQuestion() {
    if (_quizIndex > 0) {
      _quizIndex--;
      notifyListeners();
    }
  }

  void handleAction(String action, Map<String, dynamic> data) {
    switch (action) {
      case "NAVIGATE_ACTIVE_LECTURE":
        if (data.containsKey("session")) {
          _activeSession = SessionModel.fromJson(data["session"]);
        }
        break;

      case "NAVIGATE_HOME":
        _activeSession = null;
        break;

      case "NOTE_CREATED":
        if (data.containsKey("note")) {
          final newNote = NoteModel.fromJson(data["note"]);
          _notes.insert(0, newNote);
          _lastNote = newNote;
        }
        break;

      case "NOTE_UPDATED":
      case "NOTE_CORRECTED":
        if (data.containsKey("note")) {
          final updated = NoteModel.fromJson(data["note"]);
          _lastNote = updated;
          final idx = _notes.indexWhere((n) => n.noteId == updated.noteId);
          if (idx != -1) {
            _notes[idx] = updated;
          } else {
            _notes.insert(0, updated);
          }
        }
        break;

      case "NAVIGATE_RETRIEVAL":
        if (data.containsKey("results")) {
          final List list = data["results"];
          _searchResults = list.map((item) => NoteModel.fromJson(item)).toList();
          _searchQuery = data["query"] ?? "";
          _searchIndex = data["current_index"] ?? 0;
        }
        break;

      case "NAVIGATE_AUDIO_REVIEW":
        if (data.containsKey("notes")) {
          final List list = data["notes"];
          _reviewNotes = list.map((item) => NoteModel.fromJson(item)).toList();
          _reviewIndex = data["current_index"] ?? 0;
        }
        break;

      case "AUDIO_INDEX_UPDATED":
        if (data.containsKey("current_index")) {
          _searchIndex = data["current_index"];
          _reviewIndex = data["current_index"];
        }
        break;

      case "NAVIGATE_FLASHCARDS":
        final rawCards = data["flashcards"] ?? data["cards"];
        if (rawCards != null && rawCards is List) {
          _flashcards = rawCards.map((item) => FlashcardModel.fromJson(Map<String, dynamic>.from(item))).toList();
          _flashcardIndex = data["current_index"] ?? 0;
          _isCardFlipped = false;
        }
        break;

      case "NAVIGATE_QUIZ":
        final rawQuiz = data["questions"] ?? data["quiz_items"];
        if (rawQuiz != null && rawQuiz is List) {
          _quizItems = rawQuiz.map((item) => QuizQuestionModel.fromJson(Map<String, dynamic>.from(item))).toList();
          _quizIndex = data["current_index"] ?? 0;
          _quizScore = 0.0;
        }
        break;
    }
    notifyListeners();
  }
}
