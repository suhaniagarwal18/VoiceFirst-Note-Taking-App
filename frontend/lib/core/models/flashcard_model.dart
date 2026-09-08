class FlashcardModel {
  final String id;
  final String? sourceNoteId;
  final String userId;
  final String subject;
  final String tag;
  final String front;
  final String back;
  final String difficulty;
  final int reviewCount;
  final int correctCount;

  String get question => front;
  String get answer => back;

  FlashcardModel({
    required this.id,
    this.sourceNoteId,
    this.userId = '',
    this.subject = 'General',
    this.tag = 'General',
    required this.front,
    required this.back,
    this.difficulty = 'Medium',
    this.reviewCount = 0,
    this.correctCount = 0,
  });

  factory FlashcardModel.fromJson(Map<String, dynamic> json) {
    final frontText = json['front'] ?? json['question'] ?? '';
    final backText = json['back'] ?? json['answer'] ?? '';
    return FlashcardModel(
      id: json['id'] ?? '',
      sourceNoteId: json['source_note_id'],
      userId: json['user_id'] ?? '',
      subject: json['subject'] ?? 'General',
      tag: json['tag'] ?? 'General',
      front: frontText,
      back: backText,
      difficulty: json['difficulty'] ?? 'Medium',
      reviewCount: json['review_count'] ?? 0,
      correctCount: json['correct_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_note_id': sourceNoteId,
      'user_id': userId,
      'subject': subject,
      'tag': tag,
      'front': front,
      'back': back,
      'question': front,
      'answer': back,
      'difficulty': difficulty,
      'review_count': reviewCount,
      'correct_count': correctCount,
    };
  }
}

class QuizQuestionModel {
  final String questionId;
  final String? sourceNoteId;
  final String subject;
  final String tag;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String expectedAnswer;
  final String originalNote;
  String? selectedOption;

  QuizQuestionModel({
    required this.questionId,
    this.sourceNoteId,
    this.subject = 'General',
    this.tag = 'General',
    required this.question,
    this.options = const [],
    this.correctAnswer = '',
    this.expectedAnswer = '',
    this.originalNote = '',
    this.selectedOption,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List?;
    final optionsList = rawOptions != null ? rawOptions.map((e) => e.toString()).toList() : <String>[];
    return QuizQuestionModel(
      questionId: json['question_id'] ?? '',
      sourceNoteId: json['source_note_id'],
      subject: json['subject'] ?? 'General',
      tag: json['tag'] ?? 'General',
      question: json['question'] ?? '',
      options: optionsList,
      correctAnswer: (json['correct_answer'] ?? '').toString().toUpperCase(),
      expectedAnswer: json['expected_answer'] ?? json['explanation'] ?? '',
      originalNote: json['original_note'] ?? '',
      selectedOption: json['selected_option'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'source_note_id': sourceNoteId,
      'subject': subject,
      'tag': tag,
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
      'expected_answer': expectedAnswer,
      'original_note': originalNote,
      'selected_option': selectedOption,
    };
  }
}

class QuizEvaluationModel {
  final String result; // Correct, Partially correct, Incorrect
  final double score;
  final String feedback;
  final String spokenFeedback;

  QuizEvaluationModel({
    required this.result,
    required this.score,
    required this.feedback,
    required this.spokenFeedback,
  });

  factory QuizEvaluationModel.fromJson(Map<String, dynamic> json) {
    return QuizEvaluationModel(
      result: json['result'] ?? 'Incorrect',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      feedback: json['feedback'] ?? '',
      spokenFeedback: json['spoken_feedback'] ?? '',
    );
  }
}
