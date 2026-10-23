class Assignment {
  final int id;
  final String title;
  final String description;
  final double maxScore;
  final DateTime? dueDate;
  final bool allowLate;
  final Map<String, dynamic>? mySubmission;

  final String type; // individual | group
  final int maxGroupSize;
  final DateTime? startAt;

  Assignment({
    required this.id,
    required this.title,
    required this.description,
    required this.maxScore,
    this.dueDate,
    required this.allowLate,
    this.mySubmission,
    this.type = 'individual',
    this.maxGroupSize = 4,
    this.startAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      maxScore: double.tryParse(json['max_score'].toString()) ?? 100,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      allowLate: json['allow_late'] ?? false,
      mySubmission: json['my_submission'],
      type: json['type'] ?? 'individual',
      maxGroupSize: json['max_group_size'] ?? 4,
      startAt: json['start_at'] != null ? DateTime.tryParse(json['start_at']) : null,
    );
  }

  bool get isPastDue => dueDate != null && DateTime.now().isAfter(dueDate!);
}
