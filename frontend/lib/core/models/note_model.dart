class NoteModel {
  final String noteId;
  final String userId;
  final String? sessionId;
  final String subject;
  final String text;
  final String tag;
  final String timestamp;
  final double confidence;
  final String createdAt;
  final String updatedAt;

  NoteModel({
    required this.noteId,
    required this.userId,
    this.sessionId,
    required this.subject,
    required this.text,
    required this.tag,
    required this.timestamp,
    this.confidence = 1.0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      noteId: json['note_id'] ?? '',
      userId: json['user_id'] ?? '',
      sessionId: json['session_id'],
      subject: json['subject'] ?? 'General',
      text: json['text'] ?? '',
      tag: json['tag'] ?? 'General',
      timestamp: json['timestamp'] ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'note_id': noteId,
      'user_id': userId,
      'session_id': sessionId,
      'subject': subject,
      'text': text,
      'tag': tag,
      'timestamp': timestamp,
      'confidence': confidence,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  NoteModel copyWith({
    String? noteId,
    String? userId,
    String? sessionId,
    String? subject,
    String? text,
    String? tag,
    String? timestamp,
    double? confidence,
    String? createdAt,
    String? updatedAt,
  }) {
    return NoteModel(
      noteId: noteId ?? this.noteId,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      subject: subject ?? this.subject,
      text: text ?? this.text,
      tag: tag ?? this.tag,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CorrectionHistoryModel {
  final int id;
  final String noteId;
  final String originalText;
  final String correctedText;
  final String correctionTimestamp;
  final String? changeReason;

  CorrectionHistoryModel({
    required this.id,
    required this.noteId,
    required this.originalText,
    required this.correctedText,
    required this.correctionTimestamp,
    this.changeReason,
  });

  factory CorrectionHistoryModel.fromJson(Map<String, dynamic> json) {
    return CorrectionHistoryModel(
      id: json['id'] ?? 0,
      noteId: json['note_id'] ?? '',
      originalText: json['original_text'] ?? '',
      correctedText: json['corrected_text'] ?? '',
      correctionTimestamp: json['correction_timestamp'] ?? '',
      changeReason: json['change_reason'],
    );
  }
}
