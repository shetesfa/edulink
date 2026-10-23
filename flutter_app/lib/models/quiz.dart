class Quiz {
  final int id;
  final String title;
  final String? description;
  final int? timeLimitMinutes;
  final int maxAttempts;
  final bool isPublished;
  final int questionsCount;

  Quiz({
    required this.id,
    required this.title,
    this.description,
    this.timeLimitMinutes,
    required this.maxAttempts,
    required this.isPublished,
    this.questionsCount = 0,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      timeLimitMinutes: json['time_limit_minutes'],
      maxAttempts: json['max_attempts'] ?? 1,
      isPublished: json['is_published'] ?? false,
      questionsCount: json['questions_count'] ?? 0,
    );
  }
}
