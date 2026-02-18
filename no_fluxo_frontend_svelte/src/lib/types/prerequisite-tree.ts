/**
 * Prerequisite tree type definitions and traversal utilities
 */

import type { MateriaModel } from './materia';
import type { CursoModel } from './curso';

export interface PrerequisiteTreeNode {
	materia: MateriaModel;
	prerequisites: PrerequisiteTreeNode[];
	dependents: PrerequisiteTreeNode[];
	coRequisites: PrerequisiteTreeNode[];
	depth: number;
	isRoot: boolean;
	isLeaf: boolean;
}

export interface PrerequisiteTree {
	nodes: Map<string, PrerequisiteTreeNode>;
	rootNodes: PrerequisiteTreeNode[];
	leafNodes: PrerequisiteTreeNode[];
	maxDepth: number;
}

export interface NodeVisualizationData {
	code: string;
	name: string;
	credits: number;
	status: string | null;
	semester: number;
	canBeTaken: boolean;
	isRoot: boolean;
	isLeaf: boolean;
	depth: number;
	prerequisites: string[];
	dependents: string[];
}

export interface TreeVisualizationData {
	nodesByLevel: Map<number, NodeVisualizationData[]>;
	availableSubjects: string[];
	optimalOrganization: Map<number, string[]>;
	maxDepth: number;
	rootNodes: string[];
	leafNodes: string[];
	cycles: string[][];
}

export function getAllPrerequisitesCodes(node: PrerequisiteTreeNode): Set<string> {
	const allPrereqs = new Set<string>();

	for (const prereq of node.prerequisites) {
		allPrereqs.add(prereq.materia.codigoMateria);
		getAllPrerequisitesCodes(prereq).forEach((code) => allPrereqs.add(code));
	}

	return allPrereqs;
}

export function getAllDependentsCodes(node: PrerequisiteTreeNode): Set<string> {
	const allDependents = new Set<string>();

	for (const dependent of node.dependents) {
		allDependents.add(dependent.materia.codigoMateria);
		getAllDependentsCodes(dependent).forEach((code) => allDependents.add(code));
	}

	return allDependents;
}

export function getAllCoRequisitesCodes(node: PrerequisiteTreeNode): Set<string> {
	return new Set(node.coRequisites.map((cr) => cr.materia.codigoMateria));
}

export function nodeCanBeTaken(
	node: PrerequisiteTreeNode,
	completedSubjects: Set<string>
): boolean {
	return node.prerequisites.every((prereq) =>
		completedSubjects.has(prereq.materia.codigoMateria)
	);
}

export function getPrerequisiteChain(node: PrerequisiteTreeNode): string[][] {
	const levelMap = new Map<number, Set<string>>();
	buildLevelMap(node, levelMap, 0);

	const chain: string[][] = [];
	const maxDepth = levelMap.size > 0 ? Math.max(...levelMap.keys()) : 0;

	for (let i = 0; i <= maxDepth; i++) {
		if (levelMap.has(i)) {
			chain.push([...levelMap.get(i)!]);
		}
	}

	return chain;
}

function buildLevelMap(
	node: PrerequisiteTreeNode,
	levelMap: Map<number, Set<string>>,
	currentDepth: number
): void {
	if (!levelMap.has(currentDepth)) {
		levelMap.set(currentDepth, new Set());
	}
	levelMap.get(currentDepth)!.add(node.materia.codigoMateria);

	for (const prereq of node.prerequisites) {
		buildLevelMap(prereq, levelMap, currentDepth + 1);
	}
}

function getMateriaCodeById(materias: MateriaModel[], id: number): string | null {
	const materia = materias.find((m) => m.idMateria === id);
	return materia?.codigoMateria ?? null;
}

function calculateDepths(nodes: Map<string, PrerequisiteTreeNode>): Map<string, number> {
	const depths = new Map<string, number>();

	for (const code of nodes.keys()) {
		depths.set(code, 0);
	}

	let changed = true;
	while (changed) {
		changed = false;

		for (const [code, node] of nodes) {
			let maxPrereqDepth = 0;

			for (const prereq of node.prerequisites) {
				const prereqDepth = depths.get(prereq.materia.codigoMateria) ?? 0;
				if (prereqDepth >= maxPrereqDepth) {
					maxPrereqDepth = prereqDepth + 1;
				}
			}

			if (depths.get(code)! < maxPrereqDepth) {
				depths.set(code, maxPrereqDepth);
				changed = true;
			}
		}
	}

	return depths;
}

export function buildPrerequisiteTree(curso: CursoModel): PrerequisiteTree {
	const nodes = new Map<string, PrerequisiteTreeNode>();

	for (const materia of curso.materias) {
		nodes.set(materia.codigoMateria, {
			materia,
			prerequisites: [],
			dependents: [],
			coRequisites: [],
			depth: 0,
			isRoot: true,
			isLeaf: true
		});
	}

	for (const prereq of curso.preRequisitos) {
		const materiaCode = getMateriaCodeById(curso.materias, prereq.idMateria);
		const prereqCode = prereq.codigoMateriaRequisito;

		if (materiaCode && nodes.has(materiaCode) && nodes.has(prereqCode)) {
			const materiaNode = nodes.get(materiaCode)!;
			const prereqNode = nodes.get(prereqCode)!;

			materiaNode.prerequisites.push(prereqNode);
			materiaNode.isRoot = false;

			prereqNode.dependents.push(materiaNode);
			prereqNode.isLeaf = false;
		}
	}

	for (const coreq of curso.coRequisitos) {
		const materiaCode = getMateriaCodeById(curso.materias, coreq.idMateria);
		const coreqCode = coreq.codigoMateriaCoRequisito;

		if (materiaCode && nodes.has(materiaCode) && nodes.has(coreqCode)) {
			const materiaNode = nodes.get(materiaCode)!;
			const coreqNode = nodes.get(coreqCode)!;

			materiaNode.coRequisites.push(coreqNode);
			coreqNode.coRequisites.push(materiaNode);
		}
	}

	const depths = calculateDepths(nodes);

	let maxDepth = 0;
	for (const [code, node] of nodes) {
		node.depth = depths.get(code) ?? 0;
		if (node.depth > maxDepth) maxDepth = node.depth;
	}

	const rootNodes = [...nodes.values()].filter((n) => n.isRoot);
	const leafNodes = [...nodes.values()].filter((n) => n.isLeaf);

	return { nodes, rootNodes, leafNodes, maxDepth };
}

export function getNodesByLevel(tree: PrerequisiteTree): Map<number, PrerequisiteTreeNode[]> {
	const levelMap = new Map<number, PrerequisiteTreeNode[]>();

	for (const node of tree.nodes.values()) {
		if (!levelMap.has(node.depth)) {
			levelMap.set(node.depth, []);
		}
		levelMap.get(node.depth)!.push(node);
	}

	return levelMap;
}

export function getPrerequisiteChainByCode(
	tree: PrerequisiteTree,
	subjectCode: string
): string[][] {
	const node = tree.nodes.get(subjectCode);
	return node ? getPrerequisiteChain(node) : [];
}

export function getAvailableSubjects(
	tree: PrerequisiteTree,
	completedSubjects: Set<string>
): string[] {
	return [...tree.nodes.values()]
		.filter(
			(node) =>
				!completedSubjects.has(node.materia.codigoMateria) &&
				nodeCanBeTaken(node, completedSubjects)
		)
		.map((node) => node.materia.codigoMateria);
}

export function getOptimalSemesterOrganization(
	tree: PrerequisiteTree
): Map<number, string[]> {
	const semesterMap = new Map<number, string[]>();
	const scheduled = new Set<string>();

	for (let semester = 1; semester <= tree.maxDepth + 1; semester++) {
		const semesterSubjects: string[] = [];

		for (const node of tree.nodes.values()) {
			if (
				!scheduled.has(node.materia.codigoMateria) &&
				nodeCanBeTaken(node, scheduled)
			) {
				semesterSubjects.push(node.materia.codigoMateria);
				scheduled.add(node.materia.codigoMateria);
			}
		}

		if (semesterSubjects.length > 0) {
			semesterMap.set(semester, semesterSubjects);
		}

		if (scheduled.size === tree.nodes.size) break;
	}

	return semesterMap;
}

export function findCycles(tree: PrerequisiteTree): string[][] {
	const cycles: string[][] = [];
	const visited = new Set<string>();
	const recursionStack = new Set<string>();

	for (const nodeCode of tree.nodes.keys()) {
		if (!visited.has(nodeCode)) {
			dfsForCycles(tree, nodeCode, visited, recursionStack, [], cycles);
		}
	}

	return cycles;
}

function dfsForCycles(
	tree: PrerequisiteTree,
	nodeCode: string,
	visited: Set<string>,
	recursionStack: Set<string>,
	path: string[],
	cycles: string[][]
): void {
	visited.add(nodeCode);
	recursionStack.add(nodeCode);
	path.push(nodeCode);

	const node = tree.nodes.get(nodeCode);
	if (node) {
		for (const prereq of node.prerequisites) {
			const prereqCode = prereq.materia.codigoMateria;

			if (!visited.has(prereqCode)) {
				dfsForCycles(tree, prereqCode, visited, recursionStack, path, cycles);
			} else if (recursionStack.has(prereqCode)) {
				const cycleStart = path.indexOf(prereqCode);
				cycles.push([...path.slice(cycleStart), prereqCode]);
			}
		}
	}

	path.pop();
	recursionStack.delete(nodeCode);
}

export function getTreeVisualizationData(
	tree: PrerequisiteTree,
	completedSubjects: Set<string>
): TreeVisualizationData {
	const nodesByLevel = new Map<number, NodeVisualizationData[]>();

	for (const node of tree.nodes.values()) {
		const level = node.depth;
		if (!nodesByLevel.has(level)) {
			nodesByLevel.set(level, []);
		}

		nodesByLevel.get(level)!.push({
			code: node.materia.codigoMateria,
			name: node.materia.nomeMateria,
			credits: node.materia.creditos,
			status: node.materia.status ?? null,
			semester: node.materia.nivel,
			canBeTaken: nodeCanBeTaken(node, completedSubjects),
			isRoot: node.isRoot,
			isLeaf: node.isLeaf,
			depth: node.depth,
			prerequisites: node.prerequisites.map((p) => p.materia.codigoMateria),
			dependents: node.dependents.map((d) => d.materia.codigoMateria)
		});
	}

	return {
		nodesByLevel,
		availableSubjects: getAvailableSubjects(tree, completedSubjects),
		optimalOrganization: getOptimalSemesterOrganization(tree),
		maxDepth: tree.maxDepth,
		rootNodes: tree.rootNodes.map((n) => n.materia.codigoMateria),
		leafNodes: tree.leafNodes.map((n) => n.materia.codigoMateria),
		cycles: findCycles(tree)
	};
}
