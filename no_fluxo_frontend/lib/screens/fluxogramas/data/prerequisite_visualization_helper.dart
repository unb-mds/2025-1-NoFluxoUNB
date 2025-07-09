import 'curso_model.dart';
import 'prerequisite_tree_model.dart';
import 'materia_model.dart';

/// Helper class for creating prerequisite visualizations
class PrerequisiteVisualizationHelper {
  /// Generate data for a network graph visualization (like D3.js, vis.js, etc.)
  static Map<String, dynamic> generateNetworkGraphData(CursoModel curso) {
    var tree = curso.buildPrerequisiteTree();

    // Create nodes
    List<Map<String, dynamic>> nodes = tree.nodes.values.map((node) {
      var completedSubjects = curso.materias
          .where((m) => m.status == 'completed')
          .map((m) => m.codigoMateria)
          .toSet();

      return {
        'id': node.materia.codigoMateria,
        'label': node.materia.nomeMateria,
        'code': node.materia.codigoMateria,
        'credits': node.materia.creditos,
        'semester': node.materia.nivel,
        'status': node.materia.status ?? 'pending',
        'level': node.depth,
        'isRoot': node.isRoot,
        'isLeaf': node.isLeaf,
        'canBeTaken': node.canBeTaken(completedSubjects),
        'group': _getNodeGroup(node),
        'color': _getNodeColor(node, completedSubjects),
      };
    }).toList();

    // Create edges (connections between prerequisites)
    List<Map<String, dynamic>> edges = [];
    for (var node in tree.nodes.values) {
      for (var prereq in node.prerequisites) {
        edges.add({
          'from': prereq.materia.codigoMateria,
          'to': node.materia.codigoMateria,
          'type': 'prerequisite',
          'arrows': 'to',
        });
      }
    }

    return {
      'nodes': nodes,
      'edges': edges,
      'metadata': {
        'maxDepth': tree.maxDepth,
        'totalSubjects': nodes.length,
        'totalConnections': edges.length,
        'rootNodes': tree.rootNodes.length,
        'leafNodes': tree.leafNodes.length,
      }
    };
  }

  /// Generate data for a hierarchical tree visualization
  static Map<String, dynamic> generateHierarchicalTreeData(CursoModel curso) {
    var tree = curso.buildPrerequisiteTree();
    var levels = tree.getNodesByLevel();

    return {
      'levels': levels.map((level, nodes) => MapEntry(
            level.toString(),
            nodes
                .map((node) => {
                      'code': node.materia.codigoMateria,
                      'name': node.materia.nomeMateria,
                      'credits': node.materia.creditos,
                      'semester': node.materia.nivel,
                      'status': node.materia.status ?? 'pending',
                      'prerequisites': node.prerequisites
                          .map((p) => p.materia.codigoMateria)
                          .toList(),
                      'dependents': node.dependents
                          .map((d) => d.materia.codigoMateria)
                          .toList(),
                    })
                .toList(),
          )),
      'metadata': {
        'maxDepth': tree.maxDepth,
        'levelCount': levels.length,
      }
    };
  }

  /// Generate data for a flowchart visualization (like Mermaid diagrams)
  static String generateMermaidFlowchart(CursoModel curso, {int maxDepth = 3}) {
    var tree = curso.buildPrerequisiteTree();
    var buffer = StringBuffer();

    buffer.writeln('flowchart TD');

    // Add nodes with styling
    for (var node in tree.nodes.values) {
      if (node.depth <= maxDepth) {
        var nodeId =
            node.materia.codigoMateria.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        var label =
            '${node.materia.codigoMateria}\\n${node.materia.nomeMateria}';
        var shape = _getMermaidNodeShape(node);
        buffer.writeln('    $nodeId$shape');
      }
    }

    // Add connections
    for (var node in tree.nodes.values) {
      if (node.depth <= maxDepth) {
        var nodeId =
            node.materia.codigoMateria.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        for (var prereq in node.prerequisites) {
          if (prereq.depth <= maxDepth) {
            var prereqId = prereq.materia.codigoMateria
                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
            buffer.writeln('    $prereqId --> $nodeId');
          }
        }
      }
    }

    // Add styling
    buffer.writeln(
        '    classDef completed fill:#22c55e,stroke:#16a34a,stroke-width:2px,color:#fff');
    buffer.writeln(
        '    classDef current fill:#8b5cf6,stroke:#7c3aed,stroke-width:2px,color:#fff');
    buffer.writeln(
        '    classDef available fill:#3b82f6,stroke:#1d4ed8,stroke-width:2px,color:#fff');
    buffer.writeln(
        '    classDef pending fill:#6b7280,stroke:#4b5563,stroke-width:2px,color:#fff');

    // Apply classes to nodes
    var completedSubjects = curso.materias
        .where((m) => m.status == 'completed')
        .map((m) => m.codigoMateria)
        .toSet();

    for (var node in tree.nodes.values) {
      if (node.depth <= maxDepth) {
        var nodeId =
            node.materia.codigoMateria.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        var cssClass = _getMermaidNodeClass(node, completedSubjects);
        buffer.writeln('    class $nodeId $cssClass');
      }
    }

    return buffer.toString();
  }

  /// Generate prerequisite statistics
  static Map<String, dynamic> generateStatistics(CursoModel curso) {
    var tree = curso.buildPrerequisiteTree();
    var completedSubjects = curso.materias
        .where((m) => m.status == 'completed')
        .map((m) => m.codigoMateria)
        .toSet();

    var availableSubjects = tree.getAvailableSubjects(completedSubjects);
    var levels = tree.getNodesByLevel();

    // Calculate complexity metrics
    var totalConnections = 0;
    var maxPrerequisites = 0;
    var maxDependents = 0;

    for (var node in tree.nodes.values) {
      totalConnections += node.prerequisites.length;
      if (node.prerequisites.length > maxPrerequisites) {
        maxPrerequisites = node.prerequisites.length;
      }
      if (node.dependents.length > maxDependents) {
        maxDependents = node.dependents.length;
      }
    }

    return {
      'totalSubjects': tree.nodes.length,
      'completedSubjects': completedSubjects.length,
      'availableSubjects': availableSubjects.length,
      'maxDepth': tree.maxDepth,
      'rootSubjects': tree.rootNodes.length,
      'leafSubjects': tree.leafNodes.length,
      'totalConnections': totalConnections,
      'averagePrerequisites':
          tree.nodes.isEmpty ? 0 : totalConnections / tree.nodes.length,
      'maxPrerequisites': maxPrerequisites,
      'maxDependents': maxDependents,
      'subjectsByLevel':
          levels.map((level, nodes) => MapEntry(level, nodes.length)),
      'progressPercentage': tree.nodes.isEmpty
          ? 0
          : (completedSubjects.length / tree.nodes.length * 100),
      'cycles': tree.findCycles(),
    };
  }

  /// Get critical path (longest prerequisite chain)
  static List<List<String>> getCriticalPaths(CursoModel curso) {
    var tree = curso.buildPrerequisiteTree();
    List<List<String>> criticalPaths = [];

    // Find all leaf nodes and trace back to roots
    for (var leafNode in tree.leafNodes) {
      var path = _tracePath(leafNode, []);
      if (path.length == tree.maxDepth + 1) {
        criticalPaths.add(path.reversed.toList());
      }
    }

    return criticalPaths;
  }

  static List<String> _tracePath(
      PrerequisiteTreeNode node, List<String> currentPath) {
    currentPath.add(node.materia.codigoMateria);

    if (node.prerequisites.isEmpty) {
      return currentPath;
    }

    // Find the longest prerequisite path
    List<String> longestPath = [];
    for (var prereq in node.prerequisites) {
      var path = _tracePath(prereq, List.from(currentPath));
      if (path.length > longestPath.length) {
        longestPath = path;
      }
    }

    return longestPath;
  }

  static String _getNodeGroup(PrerequisiteTreeNode node) {
    if (node.isRoot) return 'root';
    if (node.isLeaf) return 'leaf';
    return 'intermediate';
  }

  static String _getNodeColor(
      PrerequisiteTreeNode node, Set<String> completedSubjects) {
    var status = node.materia.status;
    if (status == 'completed') return '#22c55e';
    if (status == 'current') return '#8b5cf6';
    if (node.canBeTaken(completedSubjects)) return '#3b82f6';
    return '#6b7280';
  }

  static String _getMermaidNodeShape(PrerequisiteTreeNode node) {
    var label = '${node.materia.codigoMateria}<br/>${node.materia.nomeMateria}';
    if (node.isRoot) return '[\"$label\"]';
    if (node.isLeaf) return '(\"$label\")';
    return '(\"$label\")';
  }

  static String _getMermaidNodeClass(
      PrerequisiteTreeNode node, Set<String> completedSubjects) {
    var status = node.materia.status;
    if (status == 'completed') return 'completed';
    if (status == 'current') return 'current';
    if (node.canBeTaken(completedSubjects)) return 'available';
    return 'pending';
  }
}
