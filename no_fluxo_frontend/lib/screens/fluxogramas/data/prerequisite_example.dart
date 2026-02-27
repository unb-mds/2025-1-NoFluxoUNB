import 'curso_model.dart';
import 'prerequisite_tree_model.dart';
import 'prerequisite_visualization_helper.dart';

/// Example class showing how to use the prerequisite tree structure
class PrerequisiteExample {
  /// Example: Basic usage of prerequisite tree
  static void basicExample(CursoModel curso) {
    // Build the prerequisite tree
    var tree = curso.buildPrerequisiteTree();

    print('=== Prerequisite Tree Basic Info ===');
    print('Total subjects: ${tree.nodes.length}');
    print('Max depth: ${tree.maxDepth}');
    print('Root subjects (no prerequisites): ${tree.rootNodes.length}');
    print(
        'Leaf subjects (not prerequisites for others): ${tree.leafNodes.length}');

    // Example: Check if a subject can be taken
    var subjectCode = 'MAT0025'; // Example subject code
    var node = tree.nodes[subjectCode];
    if (node != null) {
      var completedSubjects = {
        'MAT0024',
        'MAT0026'
      }; // Example completed subjects
      var canTake = node.canBeTaken(completedSubjects);
      print('\nCan take $subjectCode? $canTake');
      print(
          'Prerequisites: ${node.prerequisites.map((p) => p.materia.codigoMateria).join(', ')}');
      print(
          'Dependents: ${node.dependents.map((d) => d.materia.codigoMateria).join(', ')}');
    }
  }

  /// Example: Generate visualization data
  static void visualizationExample(CursoModel curso) {
    print('\n=== Visualization Examples ===');

    // 1. Network graph data (for libraries like vis.js, cytoscape.js, etc.)
    var networkData =
        PrerequisiteVisualizationHelper.generateNetworkGraphData(curso);
    print('Network graph data:');
    print('- Nodes: ${networkData['nodes'].length}');
    print('- Edges: ${networkData['edges'].length}');
    print('- Sample node: ${networkData['nodes'].first}');

    // 2. Hierarchical tree data (for tree layouts)
    var treeData =
        PrerequisiteVisualizationHelper.generateHierarchicalTreeData(curso);
    print('\nHierarchical tree data:');
    print('- Levels: ${treeData['levels'].keys.length}');
    print('- Max depth: ${treeData['metadata']['maxDepth']}');

    // 3. Mermaid flowchart (for documentation)
    var mermaidChart = PrerequisiteVisualizationHelper.generateMermaidFlowchart(
        curso,
        maxDepth: 2);
    print('\nMermaid flowchart (first few lines):');
    print(mermaidChart.split('\n').take(10).join('\n'));

    // 4. Statistics
    var stats = PrerequisiteVisualizationHelper.generateStatistics(curso);
    print('\nStatistics:');
    print('- Total subjects: ${stats['totalSubjects']}');
    print('- Completed: ${stats['completedSubjects']}');
    print('- Available: ${stats['availableSubjects']}');
    print(
        '- Average prerequisites per subject: ${stats['averagePrerequisites'].toStringAsFixed(2)}');
    print('- Progress: ${stats['progressPercentage'].toStringAsFixed(1)}%');
  }

  /// Example: Find prerequisite chains and critical paths
  static void analysisExample(CursoModel curso) {
    print('\n=== Analysis Examples ===');

    var tree = curso.buildPrerequisiteTree();

    // 1. Get available subjects (can be taken now)
    var completedSubjects = curso.materias
        .where((m) => m.status == 'completed')
        .map((m) => m.codigoMateria)
        .toSet();

    var availableSubjects = tree.getAvailableSubjects(completedSubjects);
    print('Subjects you can take now: ${availableSubjects.join(', ')}');

    // 2. Get optimal semester organization
    var organization = tree.getOptimalSemesterOrganization();
    print('\nOptimal semester organization:');
    organization.forEach((semester, subjects) {
      print('Semester $semester: ${subjects.join(', ')}');
    });

    // 3. Find critical paths (longest prerequisite chains)
    var criticalPaths = PrerequisiteVisualizationHelper.getCriticalPaths(curso);
    print('\nCritical paths (longest prerequisite chains):');
    for (var i = 0; i < criticalPaths.length && i < 3; i++) {
      print('Path ${i + 1}: ${criticalPaths[i].join(' → ')}');
    }

    // 4. Check for cycles (shouldn't exist in a valid curriculum)
    var cycles = tree.findCycles();
    if (cycles.isEmpty) {
      print('\nNo cycles found (good!)');
    } else {
      print('\nWarning: Found ${cycles.length} cycles in prerequisites!');
      for (var cycle in cycles) {
        print('Cycle: ${cycle.join(' → ')}');
      }
    }
  }

  /// Example: Get detailed information about a specific subject
  static void subjectAnalysisExample(CursoModel curso, String subjectCode) {
    print('\n=== Subject Analysis: $subjectCode ===');

    var visualizationData = curso.getPrerequisiteVisualizationData(subjectCode);

    if (visualizationData['subject'] == null) {
      print('Subject not found!');
      return;
    }

    print('Subject: ${visualizationData['subject']}');
    print('Can be taken: ${visualizationData['canBeTaken']}');
    print('Depth level: ${visualizationData['depth']}');
    print('Is root (no prerequisites): ${visualizationData['isRoot']}');
    print('Is leaf (not a prerequisite): ${visualizationData['isLeaf']}');

    var chain = visualizationData['chain'] as List<List<String>>;
    if (chain.isNotEmpty) {
      print('\nPrerequisite chain:');
      for (var i = 0; i < chain.length; i++) {
        print('Level ${i + 1}: ${chain[i].join(', ')}');
      }
    }

    var dependents = visualizationData['dependents'] as List<String>;
    if (dependents.isNotEmpty) {
      print('\nSubjects that depend on this one:');
      print(dependents.join(', '));
    }

    var allPrereqs = visualizationData['allPrerequisites'] as List<String>;
    if (allPrereqs.isNotEmpty) {
      print('\nAll prerequisites (recursive):');
      print(allPrereqs.join(', '));
    }
  }

  /// Example: Generate data for different visualization libraries
  static Map<String, dynamic> generateForVisualizationLibrary(
      CursoModel curso, String libraryType) {
    switch (libraryType.toLowerCase()) {
      case 'vis.js':
      case 'cytoscape':
      case 'd3':
        // Network graph format
        return PrerequisiteVisualizationHelper.generateNetworkGraphData(curso);

      case 'mermaid':
        // Mermaid diagram format
        return {
          'diagram':
              PrerequisiteVisualizationHelper.generateMermaidFlowchart(curso),
          'type': 'flowchart'
        };

      case 'tree':
      case 'hierarchy':
        // Hierarchical tree format
        return PrerequisiteVisualizationHelper.generateHierarchicalTreeData(
            curso);

      case 'statistics':
        // Statistical analysis
        return PrerequisiteVisualizationHelper.generateStatistics(curso);

      default:
        // Return all formats
        return {
          'network':
              PrerequisiteVisualizationHelper.generateNetworkGraphData(curso),
          'tree': PrerequisiteVisualizationHelper.generateHierarchicalTreeData(
              curso),
          'mermaid':
              PrerequisiteVisualizationHelper.generateMermaidFlowchart(curso),
          'statistics':
              PrerequisiteVisualizationHelper.generateStatistics(curso),
          'allData': curso.getAllPrerequisiteVisualizationData(),
        };
    }
  }
}

/// Example usage in your application
void main() {
  // Example of how you would use this in your app

  // Assuming you have a CursoModel instance
  // CursoModel curso = ... // your course data

  // Basic usage
  // PrerequisiteExample.basicExample(curso);

  // Visualization examples
  // PrerequisiteExample.visualizationExample(curso);

  // Analysis examples
  // PrerequisiteExample.analysisExample(curso);

  // Subject-specific analysis
  // PrerequisiteExample.subjectAnalysisExample(curso, 'MAT0025');

  // Generate data for specific visualization library
  // var data = PrerequisiteExample.generateForVisualizationLibrary(curso, 'vis.js');

  print('See the PrerequisiteExample class for usage examples!');
}
