import 'materia_model.dart';
import 'curso_model.dart';

/// Represents a node in the prerequisite tree
class PrerequisiteTreeNode {
  final MateriaModel materia;
  final List<PrerequisiteTreeNode> prerequisites; // Direct prerequisites
  final List<PrerequisiteTreeNode>
      dependents; // Subjects that depend on this one
  final List<PrerequisiteTreeNode> coRequisites; // Direct co-requisites
  final int depth; // Distance from root (subjects with no prerequisites)
  final bool isRoot; // Has no prerequisites
  final bool isLeaf; // No subjects depend on this one

  PrerequisiteTreeNode({
    required this.materia,
    this.prerequisites = const [],
    this.dependents = const [],
    this.coRequisites = const [],
    this.depth = 0,
    this.isRoot = false,
    this.isLeaf = true,
  });

  /// Creates a copy with updated properties
  PrerequisiteTreeNode copyWith({
    MateriaModel? materia,
    List<PrerequisiteTreeNode>? prerequisites,
    List<PrerequisiteTreeNode>? dependents,
    List<PrerequisiteTreeNode>? coRequisites,
    int? depth,
    bool? isRoot,
    bool? isLeaf,
  }) {
    return PrerequisiteTreeNode(
      materia: materia ?? this.materia,
      prerequisites: prerequisites ?? this.prerequisites,
      dependents: dependents ?? this.dependents,
      coRequisites: coRequisites ?? this.coRequisites,
      depth: depth ?? this.depth,
      isRoot: isRoot ?? this.isRoot,
      isLeaf: isLeaf ?? this.isLeaf,
    );
  }

  /// Get all prerequisite subjects recursively
  Set<String> getAllPrerequisitesCodes() {
    Set<String> allPrereqs = {};
    for (var prereq in prerequisites) {
      allPrereqs.add(prereq.materia.codigoMateria);
      allPrereqs.addAll(prereq.getAllPrerequisitesCodes());
    }
    return allPrereqs;
  }

  /// Get all dependent subjects recursively
  Set<String> getAllDependentsCodes() {
    Set<String> allDependents = {};
    for (var dependent in dependents) {
      allDependents.add(dependent.materia.codigoMateria);
      allDependents.addAll(dependent.getAllDependentsCodes());
    }
    return allDependents;
  }

  /// Get all co-requisite subjects recursively (flat, not recursive by default)
  Set<String> getAllCoRequisitesCodes() {
    Set<String> allCoReqs = {};
    for (var coReq in coRequisites) {
      allCoReqs.add(coReq.materia.codigoMateria);
    }
    return allCoReqs;
  }

  /// Check if this subject can be taken given completed subjects
  bool canBeTaken(Set<String> completedSubjects) {
    return prerequisites.every(
        (prereq) => completedSubjects.contains(prereq.materia.codigoMateria));
  }

  /// Get the prerequisite chain as a list of levels
  List<List<String>> getPrerequisiteChain() {
    Map<int, Set<String>> levelMap = {};
    _buildLevelMap(levelMap, 0);

    List<List<String>> chain = [];
    var maxDepth = levelMap.keys.isEmpty
        ? 0
        : levelMap.keys.reduce((a, b) => a > b ? a : b);

    for (int i = 0; i <= maxDepth; i++) {
      if (levelMap.containsKey(i)) {
        chain.add(levelMap[i]!.toList());
      }
    }

    return chain;
  }

  void _buildLevelMap(Map<int, Set<String>> levelMap, int currentDepth) {
    levelMap.putIfAbsent(currentDepth, () => {}).add(materia.codigoMateria);

    for (var prereq in prerequisites) {
      prereq._buildLevelMap(levelMap, currentDepth + 1);
    }
  }
}

/// Represents the entire prerequisite tree structure for a course
class PrerequisiteTree {
  final Map<String, PrerequisiteTreeNode> nodes;
  final List<PrerequisiteTreeNode> rootNodes; // Subjects with no prerequisites
  final List<PrerequisiteTreeNode>
      leafNodes; // Subjects that are not prerequisites for others
  final int maxDepth;

  PrerequisiteTree({
    required this.nodes,
    required this.rootNodes,
    required this.leafNodes,
    required this.maxDepth,
  });

  /// Build prerequisite tree from course data
  static PrerequisiteTree fromCourse(CursoModel curso) {
    Map<String, PrerequisiteTreeNode> nodes = {};
    Map<String, MateriaModel> materiaMap = {};

    // Create map of all materias by code
    for (var materia in curso.materias) {
      materiaMap[materia.codigoMateria] = materia;
    }

    // Initialize all nodes
    for (var materia in curso.materias) {
      nodes[materia.codigoMateria] = PrerequisiteTreeNode(
        materia: materia,
        prerequisites: [],
        dependents: [],
        coRequisites: [],
        isRoot: true,
        isLeaf: true,
      );
    }

    // Build prerequisite relationships
    for (var prereq in curso.preRequisitos) {
      var materiaCode = _getMateriaCodeById(curso.materias, prereq.idMateria);
      var prereqCode = prereq.codigoMateriaRequisito;

      if (materiaCode != null &&
          nodes.containsKey(materiaCode) &&
          nodes.containsKey(prereqCode)) {
        var materiaNode = nodes[materiaCode]!;
        var prereqNode = nodes[prereqCode]!;

        // Add prerequisite relationship
        var updatedMateriaNode = materiaNode.copyWith(
          prerequisites: [...materiaNode.prerequisites, prereqNode],
          isRoot: false,
        );
        nodes[materiaCode] = updatedMateriaNode;

        // Add dependent relationship
        var updatedPrereqNode = prereqNode.copyWith(
          dependents: [...prereqNode.dependents, updatedMateriaNode],
          isLeaf: false,
        );
        nodes[prereqCode] = updatedPrereqNode;
      }
    }

    // Build co-requisite relationships
    for (var coreq in curso.coRequisitos) {
      var materiaCode = _getMateriaCodeById(curso.materias, coreq.idMateria);
      var coreqCode = coreq.codigoMateriaCoRequisito;
      if (materiaCode != null &&
          nodes.containsKey(materiaCode) &&
          nodes.containsKey(coreqCode)) {
        var materiaNode = nodes[materiaCode]!;
        var coreqNode = nodes[coreqCode]!;
        // Add co-requisite relationship (bidirectional)
        var updatedMateriaNode = materiaNode.copyWith(
          coRequisites: [...materiaNode.coRequisites, coreqNode],
        );
        nodes[materiaCode] = updatedMateriaNode;
        var updatedCoreqNode = coreqNode.copyWith(
          coRequisites: [...coreqNode.coRequisites, materiaNode],
        );
        nodes[coreqCode] = updatedCoreqNode;
      }
    }

    // Calculate depths
    Map<String, int> depths = {};
    _calculateDepths(nodes, depths);

    // Update nodes with calculated depths
    int maxDepth = 0;
    for (var entry in nodes.entries) {
      var depth = depths[entry.key] ?? 0;
      if (depth > maxDepth) maxDepth = depth;

      nodes[entry.key] = entry.value.copyWith(depth: depth);
    }

    // Get root and leaf nodes
    var rootNodes = nodes.values.where((node) => node.isRoot).toList();
    var leafNodes = nodes.values.where((node) => node.isLeaf).toList();

    return PrerequisiteTree(
      nodes: nodes,
      rootNodes: rootNodes,
      leafNodes: leafNodes,
      maxDepth: maxDepth,
    );
  }

  /// Get nodes organized by depth level
  Map<int, List<PrerequisiteTreeNode>> getNodesByLevel() {
    Map<int, List<PrerequisiteTreeNode>> levelMap = {};

    for (var node in nodes.values) {
      levelMap.putIfAbsent(node.depth, () => []).add(node);
    }

    return levelMap;
  }

  /// Get prerequisite chain for a specific subject
  List<List<String>> getPrerequisiteChain(String subjectCode) {
    var node = nodes[subjectCode];
    return node?.getPrerequisiteChain() ?? [];
  }

  /// Get all subjects that can be taken given completed subjects
  List<String> getAvailableSubjects(Set<String> completedSubjects) {
    return nodes.values
        .where((node) =>
            !completedSubjects.contains(node.materia.codigoMateria) &&
            node.canBeTaken(completedSubjects))
        .map((node) => node.materia.codigoMateria)
        .toList();
  }

  /// Get subjects organized by semester considering prerequisites
  Map<int, List<String>> getOptimalSemesterOrganization() {
    Map<int, List<String>> semesterMap = {};
    Set<String> scheduled = {};

    for (int semester = 1; semester <= maxDepth + 1; semester++) {
      List<String> semesterSubjects = [];

      for (var node in nodes.values) {
        if (!scheduled.contains(node.materia.codigoMateria) &&
            node.canBeTaken(scheduled)) {
          semesterSubjects.add(node.materia.codigoMateria);
          scheduled.add(node.materia.codigoMateria);
        }
      }

      if (semesterSubjects.isNotEmpty) {
        semesterMap[semester] = semesterSubjects;
      }

      if (scheduled.length == nodes.length) break;
    }

    return semesterMap;
  }

  /// Find cycles in the prerequisite graph (which shouldn't exist)
  List<List<String>> findCycles() {
    List<List<String>> cycles = [];
    Set<String> visited = {};
    Set<String> recursionStack = {};

    for (var nodeCode in nodes.keys) {
      if (!visited.contains(nodeCode)) {
        _dfsForCycles(nodeCode, visited, recursionStack, [], cycles);
      }
    }

    return cycles;
  }

  void _dfsForCycles(
      String nodeCode,
      Set<String> visited,
      Set<String> recursionStack,
      List<String> path,
      List<List<String>> cycles) {
    visited.add(nodeCode);
    recursionStack.add(nodeCode);
    path.add(nodeCode);

    var node = nodes[nodeCode];
    if (node != null) {
      for (var prereq in node.prerequisites) {
        var prereqCode = prereq.materia.codigoMateria;

        if (!visited.contains(prereqCode)) {
          _dfsForCycles(prereqCode, visited, recursionStack, path, cycles);
        } else if (recursionStack.contains(prereqCode)) {
          // Found a cycle
          var cycleStart = path.indexOf(prereqCode);
          cycles.add(path.sublist(cycleStart) + [prereqCode]);
        }
      }
    }

    path.removeLast();
    recursionStack.remove(nodeCode);
  }

  static void _calculateDepths(
      Map<String, PrerequisiteTreeNode> nodes, Map<String, int> depths) {
    // Initialize all depths to 0
    for (var code in nodes.keys) {
      depths[code] = 0;
    }

    // Calculate depths using topological sort approach
    bool changed = true;
    while (changed) {
      changed = false;

      for (var entry in nodes.entries) {
        var maxPrereqDepth = 0;
        for (var prereq in entry.value.prerequisites) {
          var prereqDepth = depths[prereq.materia.codigoMateria] ?? 0;
          if (prereqDepth >= maxPrereqDepth) {
            maxPrereqDepth = prereqDepth + 1;
          }
        }

        if (depths[entry.key]! < maxPrereqDepth) {
          depths[entry.key] = maxPrereqDepth;
          changed = true;
        }
      }
    }
  }

  static String? _getMateriaCodeById(List<MateriaModel> materias, int id) {
    try {
      return materias.firstWhere((m) => m.idMateria == id).codigoMateria;
    } catch (e) {
      return null;
    }
  }
}
