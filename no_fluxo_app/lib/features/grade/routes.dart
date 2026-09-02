import 'package:go_router/go_router.dart';

import 'ui/grade_screen.dart';

/// Rotas da aba Grade (grade horária semanal do aluno).
final List<RouteBase> gradeRoutes = [
  GoRoute(
    path: '/grade',
    name: 'grade',
    builder: (context, state) => const GradeScreen(),
  ),
];
