import 'package:flutter_test/flutter_test.dart';
import '../lib/core/models/note_model.dart';
import '../lib/core/models/flashcard_model.dart';
import '../lib/core/services/dialogue_manager.dart';

void main() {
  group('DialogueManager Context & State Tests', () {
    test('Initial state is home with empty session', () {
      final dm = DialogueManager();
      expect(dm.currentMode, equals('home'));
      expect(dm.currentSessionId, isNull);
      expect(dm.searchResults, isEmpty);
    });

    test('toContextMap produces complete context payload', () {
      final dm = DialogueManager();
      dm.currentMode = 'active_lecture';
      dm.currentSessionId = 'sess_123';
      dm.currentSubject = 'Biology';
      dm.lastNoteId = 'note_456';
      dm.lastNoteText = 'Mitosis is cell division.';

      final map = dm.toContextMap();
      expect(map['current_mode'], equals('active_lecture'));
      expect(map['current_session_id'], equals('sess_123'));
      expect(map['current_subject'], equals('Biology'));
      expect(map['last_note_id'], equals('note_456'));
      expect(map['last_note_text'], equals('Mitosis is cell division.'));
    });

    test('updateFromBackend modifies dialogue state correctly', () {
      final dm = DialogueManager();
      dm.updateFromBackend({
        'current_mode': 'retrieval',
        'search_query': 'photosynthesis',
        'current_index': 1,
        'search_results': [
          {'note_id': 'n1', 'text': 'First note'},
          {'note_id': 'n2', 'text': 'Second note'},
        ]
      });

      expect(dm.currentMode, equals('retrieval'));
      expect(dm.searchQuery, equals('photosynthesis'));
      expect(dm.currentIndex, equals(1));
      expect(dm.searchResults.length, equals(2));
    });
  });

  group('Model Serialization Tests', () {
    test('NoteModel fromJson and toJson roundtrip', () {
      final json = {
        'note_id': 'n_1',
        'user_id': 'user_1',
        'session_id': 's_1',
        'subject': 'Biology',
        'text': 'Mitosis is cell division.',
        'tag': 'Definition',
        'timestamp': '10:42 AM',
        'confidence': 0.98,
        'created_at': '2026-08-23T10:42:00',
        'updated_at': '2026-08-23T10:42:00',
      };

      final note = NoteModel.fromJson(json);
      expect(note.noteId, equals('n_1'));
      expect(note.subject, equals('Biology'));
      expect(note.tag, equals('Definition'));
      expect(note.confidence, equals(0.98));

      final serialized = note.toJson();
      expect(serialized['note_id'], equals('n_1'));
      expect(serialized['text'], equals('Mitosis is cell division.'));
    });

    test('FlashcardModel fromJson parses accurately', () {
      final json = {
        'id': 'f_1',
        'source_note_id': 'n_1',
        'user_id': 'user_1',
        'subject': 'Biology',
        'tag': 'Definition',
        'question': 'What is Mitosis?',
        'answer': 'Mitosis is cell division.',
        'difficulty': 'Easy',
        'review_count': 3,
        'correct_count': 3,
      };

      final card = FlashcardModel.fromJson(json);
      expect(card.question, equals('What is Mitosis?'));
      expect(card.answer, equals('Mitosis is cell division.'));
      expect(card.difficulty, equals('Easy'));
      expect(card.correctCount, equals(3));
    });
  });
}
