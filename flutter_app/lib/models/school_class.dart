class SchoolClass {
  final int id;
  final String name;
  final String? subject;
  final String? description;
  final String color;
  final String joinCode;
  final bool isActive;
  final int studentsCount;
  final String? teacherName;
  final int? teacherId;

  SchoolClass({
    required this.id,
    required this.name,
    this.subject,
    this.description,
    required this.color,
    required this.joinCode,
    required this.isActive,
    this.studentsCount = 0,
    this.teacherName,
    this.teacherId,
  });

  factory SchoolClass.fromJson(Map<String, dynamic> json) {
    return SchoolClass(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? '',
      subject: json['subject'],
      description: json['description'],
      color: json['color'] ?? '#7C3AED',
      joinCode: json['join_code'] ?? '',
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
      studentsCount: json['students_count'] is int
          ? json['students_count']
          : int.tryParse(json['students_count']?.toString() ?? '0') ?? 0,
      teacherName: json['teacher'] != null
          ? (json['teacher']['full_name'] ?? '${json['teacher']['first_name'] ?? ''} ${json['teacher']['last_name'] ?? ''}'.trim())
          : null,
      teacherId: json['teacher_id'] is int
          ? json['teacher_id']
          : (json['teacher'] != null && json['teacher']['id'] is int ? json['teacher']['id'] : int.tryParse(json['teacher_id']?.toString() ?? '')),
    );
  }
}
