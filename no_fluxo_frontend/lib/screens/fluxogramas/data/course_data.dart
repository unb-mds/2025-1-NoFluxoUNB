import 'course_subject.dart';

class CourseData {
  final String name;
  final String degree; // 'Bacharelado', 'Licenciatura', etc.
  final int totalSemesters;
  final int totalCredits;
  final Map<String, List<CourseSubject>> subjectsBySemester;
  final Map<String, int>
      creditRequirements; // 'obrigatorias', 'optativas', 'livre'

  CourseData({
    required this.name,
    required this.degree,
    required this.totalSemesters,
    required this.totalCredits,
    required this.subjectsBySemester,
    required this.creditRequirements,
  });
}
