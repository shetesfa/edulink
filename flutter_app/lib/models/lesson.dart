class Lesson {
  final int id;
  final String title;
  final String? description;
  final String? content;
  final bool isPublished;
  final int views;

  Lesson({required this.id, required this.title, this.description, this.content, required this.isPublished, this.views = 0});

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      content: json['content'],
      isPublished: json['is_published'] ?? true,
      views: json['views'] ?? 0,
    );
  }
}
