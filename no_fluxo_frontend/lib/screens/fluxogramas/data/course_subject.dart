

class CourseSubject {
  final String code;
  final String name;
  final int credits;
  final String
      status; // 'completed', 'current', 'selected', 'future', 'optative'
  final List<String> prerequisites;
  final String semester;

  CourseSubject({
    required this.code,
    required this.name,
    required this.credits,
    required this.status,
    this.prerequisites = const [],
    required this.semester,
  });
}