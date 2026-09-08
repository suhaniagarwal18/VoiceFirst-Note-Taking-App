class SessionModel {
  final String sessionId;
  final String userId;
  final String subject;
  final String startTime;
  final String? endTime;
  final bool isActive;
  final int noteCount;

  SessionModel({
    required this.sessionId,
    required this.userId,
    required this.subject,
    required this.startTime,
    this.endTime,
    required this.isActive,
    this.noteCount = 0,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      sessionId: json['session_id'] ?? '',
      userId: json['user_id'] ?? '',
      subject: json['subject'] ?? 'General',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      noteCount: json['note_count'] ?? 0,
    );
  }
}
