# Data Models and Types Migration Guide

This document covers the migration of Flutter/Dart data models to TypeScript interfaces and types for the SvelteKit frontend.

## Table of Contents

1. [Dart to TypeScript Conversion Guide](#1-dart-to-typescript-conversion-guide)
2. [User Types](#2-user-types)
3. [Course Types](#3-course-types)
4. [Subject Types](#4-subject-types)
5. [Equivalence Types](#5-equivalence-types)
6. [Prerequisite Types](#6-prerequisite-types)
7. [API Response Types](#7-api-response-types)
8. [Zod Schemas](#8-zod-schemas)
9. [Type Guards](#9-type-guards)
10. [Factory Functions](#10-factory-functions)

---

## 1. Dart to TypeScript Conversion Guide

### General Patterns

| Dart | TypeScript |
|------|------------|
| `class MyClass` | `interface MyClass` or `type MyClass` |
| `String` | `string` |
| `int`, `double` | `number` |
| `bool` | `boolean` |
| `List<T>` | `T[]` or `Array<T>` |
| `Map<K, V>` | `Record<K, V>` or `Map<K, V>` |
| `Set<T>` | `Set<T>` |
| `dynamic` | `unknown` or `any` |
| `T?` (nullable) | `T \| null` or `T \| undefined` |
| `required this.field` | Non-optional property |
| `this.field` (optional) | Optional property with `?` |
| `factory` constructor | Factory function or static method |

### Class to Interface Conversion

**Dart Class:**
```dart
class User {
  final int id;
  final String name;
  String? email;

  User({required this.id, required this.name, this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email};
  }
}
```

**TypeScript Equivalent:**
```typescript
interface User {
  id: number;
  name: string;
  email?: string | null;
}

function createUserFromJson(json: Record<string, unknown>): User {
  return {
    id: json.id as number,
    name: json.name as string,
    email: (json.email as string) ?? null,
  };
}

function userToJson(user: User): Record<string, unknown> {
  return { id: user.id, name: user.name, email: user.email };
}
```

### Method Conversion Patterns

- Instance methods → Standalone functions that take the object as first parameter
- Factory constructors → Factory functions
- Getters → Functions or computed properties in stores

---

## 2. User Types

### File: `src/lib/types/user.ts`

```typescript
// ============================================================================
// DadosMateria - Subject completion data from user's academic record
// ============================================================================

/**
 * Subject status values
 * - APR: Approved
 * - CUMP: Completed (cumprido)
 * - MATR: Currently enrolled (matriculado)
 * - REP: Failed (reprovado)
 * - TRC: Transferred
 */
export type SubjectStatus = 'APR' | 'CUMP' | 'MATR' | 'REP' | 'TRC' | '-';

/**
 * Grade mention values (Brazilian grading system)
 * - SS: Superior (90-100)
 * - MS: Medium Superior (70-89)
 * - MM: Medium (50-69)
 * - MI: Medium Inferior (30-49)
 * - II: Inferior Inferior (0-29)
 * - SR: No grade (sem rendimento)
 */
export type GradeMention = 'SS' | 'MS' | 'MM' | 'MI' | 'II' | 'SR' | '-';

export interface DadosMateria {
  codigoMateria: string;
  mencao: GradeMention | string;
  professor: string;
  status: SubjectStatus | string;
  anoPeriodo?: string | null;
  frequencia?: string | null;
  tipoDado?: string | null;
  turma?: string | null;
}

// ============================================================================
// DadosFluxogramaUser - User's flowchart (curriculum) data
// ============================================================================

export interface DadosFluxogramaUser {
  nomeCurso: string;
  ira: number;
  matricula: string;
  horasIntegralizadas: number;
  suspensoes: string[];
  anoAtual: string;
  matrizCurricular: string;
  semestreAtual: number;
  /** 2D array: outer array = semesters, inner array = subjects */
  dadosFluxograma: DadosMateria[][];
}

// ============================================================================
// UserModel - Main user model
// ============================================================================

export interface UserModel {
  idUser: number;
  email: string;
  nomeCompleto: string;
  dadosFluxograma?: DadosFluxogramaUser | null;
  token?: string | null;
}

// ============================================================================
// Helper Functions for DadosMateria
// ============================================================================

/**
 * Check if the subject has been completed (approved or fulfilled)
 */
export function isMateriaCursada(dadosMateria: DadosMateria): boolean {
  return dadosMateria.status === 'APR' || dadosMateria.status === 'CUMP';
}

/**
 * Check if the subject has been approved with a passing grade
 */
export function isMateriaAprovada(dadosMateria: DadosMateria): boolean {
  const { mencao, status } = dadosMateria;
  return (
    mencao === 'SS' ||
    mencao === 'MM' ||
    mencao === 'MS' ||
    ((status === 'APR' && mencao !== '-') || status === 'CUMP')
  );
}

/**
 * Check if the subject is currently being taken
 */
export function isMateriaCurrent(dadosMateria: DadosMateria): boolean {
  return dadosMateria.status === 'MATR';
}

/**
 * Check if a subject has been completed or is currently enrolled
 */
export function isMateriaCompletedOrCurrent(dadosMateria: DadosMateria): boolean {
  return isMateriaAprovada(dadosMateria) || isMateriaCurrent(dadosMateria);
}

// ============================================================================
// Helper Functions for DadosFluxogramaUser
// ============================================================================

/**
 * Get all subject codes that have been completed (approved)
 */
export function getCompletedSubjectCodes(dados: DadosFluxogramaUser): Set<string> {
  const completed = new Set<string>();
  for (const semester of dados.dadosFluxograma) {
    for (const materia of semester) {
      if (isMateriaAprovada(materia)) {
        completed.add(materia.codigoMateria);
      }
    }
  }
  return completed;
}

/**
 * Get all subject codes that are currently enrolled
 */
export function getCurrentSubjectCodes(dados: DadosFluxogramaUser): Set<string> {
  const current = new Set<string>();
  for (const semester of dados.dadosFluxograma) {
    for (const materia of semester) {
      if (isMateriaCurrent(materia)) {
        current.add(materia.codigoMateria);
      }
    }
  }
  return current;
}

/**
 * Get all subject codes that are completed or current
 */
export function getCompletedOrCurrentSubjectCodes(dados: DadosFluxogramaUser): Set<string> {
  const codes = new Set<string>();
  for (const semester of dados.dadosFluxograma) {
    for (const materia of semester) {
      if (isMateriaCompletedOrCurrent(materia)) {
        codes.add(materia.codigoMateria);
      }
    }
  }
  return codes;
}

/**
 * Find a specific subject in the user's flowchart data
 */
export function findSubjectInFluxograma(
  dados: DadosFluxogramaUser,
  codigoMateria: string
): DadosMateria | null {
  for (const semester of dados.dadosFluxograma) {
    for (const materia of semester) {
      if (materia.codigoMateria === codigoMateria) {
        return materia;
      }
    }
  }
  return null;
}

/**
 * Calculate total credits completed
 */
export function getTotalCreditsCompleted(
  dados: DadosFluxogramaUser,
  creditsMap: Map<string, number>
): number {
  let total = 0;
  for (const semester of dados.dadosFluxograma) {
    for (const materia of semester) {
      if (isMateriaAprovada(materia) && creditsMap.has(materia.codigoMateria)) {
        total += creditsMap.get(materia.codigoMateria)!;
      }
    }
  }
  return total;
}
```

---

## 3. Course Types

### File: `src/lib/types/curso.ts`

```typescript
import type { MateriaModel } from './materia';
import type { EquivalenciaModel } from './equivalencia';

// ============================================================================
// PreRequisitoModel - Prerequisite relationship
// ============================================================================

export interface PreRequisitoModel {
  idPreRequisito: number;
  idMateria: number;
  idMateriaRequisito: number;
  codigoMateriaRequisito: string;
  nomeMateriaRequisito: string;
}

// ============================================================================
// CoRequisitoModel - Corequisite relationship
// ============================================================================

export interface CoRequisitoModel {
  idCoRequisito: number;
  idMateria: number;
  idMateriaCoRequisito: number;
  codigoMateriaCoRequisito: string;
  nomeMateriaCoRequisito: string;
}

// ============================================================================
// Course Type Classification
// ============================================================================

export type CourseType = 'graduacao' | 'pos-graduacao' | 'tecnico' | 'outro';
export type CourseClassification = 'obrigatoria' | 'optativa' | 'modulo_livre' | 'outro';

// ============================================================================
// CursoModel - Full course model with all relationships
// ============================================================================

export interface CursoModel {
  nomeCurso: string;
  matrizCurricular: string;
  idCurso: number;
  totalCreditos: number | null;
  classificacao: CourseClassification | string;
  tipoCurso: CourseType | string;
  materias: MateriaModel[];
  semestres: number;
  equivalencias: EquivalenciaModel[];
  preRequisitos: PreRequisitoModel[];
  coRequisitos: CoRequisitoModel[];
}

// ============================================================================
// MinimalCursoModel - Lightweight course representation for lists
// ============================================================================

export interface MinimalCursoModel {
  nomeCurso: string;
  matrizCurricular: string;
  idCurso: number;
  creditos: number | null;
  tipoCurso: CourseType | string;
  classificacao: CourseClassification | string;
}

// ============================================================================
// Course Utility Functions
// ============================================================================

/**
 * Get all subject codes in a course
 */
export function getCourseSubjectCodes(curso: CursoModel): Set<string> {
  return new Set(curso.materias.map((m) => m.codigoMateria));
}

/**
 * Get subjects by semester level
 */
export function getSubjectsBySemester(curso: CursoModel): Map<number, MateriaModel[]> {
  const semesterMap = new Map<number, MateriaModel[]>();
  
  for (const materia of curso.materias) {
    if (!semesterMap.has(materia.nivel)) {
      semesterMap.set(materia.nivel, []);
    }
    semesterMap.get(materia.nivel)!.push(materia);
  }
  
  return semesterMap;
}

/**
 * Get direct prerequisites for a specific subject in the course
 */
export function getDirectPrerequisites(
  curso: CursoModel,
  codigoMateria: string
): MateriaModel[] {
  const materiaMap = new Map(curso.materias.map((m) => [m.codigoMateria, m]));
  const directPrereqs: MateriaModel[] = [];
  
  const materia = curso.materias.find((m) => m.codigoMateria === codigoMateria);
  if (!materia) return [];
  
  for (const preReq of curso.preRequisitos) {
    if (preReq.idMateria === materia.idMateria) {
      const prerequisiteMateria = materiaMap.get(preReq.codigoMateriaRequisito);
      if (prerequisiteMateria) {
        directPrereqs.push(prerequisiteMateria);
      }
    }
  }
  
  return directPrereqs;
}

/**
 * Get corequisites for a specific subject
 */
export function getCorequisites(
  curso: CursoModel,
  codigoMateria: string
): MateriaModel[] {
  const materiaMap = new Map(curso.materias.map((m) => [m.codigoMateria, m]));
  const coreqs: MateriaModel[] = [];
  
  const materia = curso.materias.find((m) => m.codigoMateria === codigoMateria);
  if (!materia) return [];
  
  for (const coReq of curso.coRequisitos) {
    if (coReq.idMateria === materia.idMateria) {
      const coreqMateria = materiaMap.get(coReq.codigoMateriaCoRequisito);
      if (coreqMateria) {
        coreqs.push(coreqMateria);
      }
    }
  }
  
  return coreqs;
}

/**
 * Filter prerequisites to only include those within the course
 */
export function filterPrerequisitesInCourse(
  preRequisitos: PreRequisitoModel[],
  courseSubjectCodes: Set<string>
): PreRequisitoModel[] {
  return preRequisitos.filter((pr) => courseSubjectCodes.has(pr.codigoMateriaRequisito));
}

/**
 * Calculate max semester from materias
 */
export function calculateMaxSemester(materias: MateriaModel[]): number {
  return materias.reduce((max, m) => Math.max(max, m.nivel), 0);
}
```

---

## 4. Subject Types

### File: `src/lib/types/materia.ts`

```typescript
// ============================================================================
// MateriaModel - Subject/Course unit model
// ============================================================================

export interface MateriaModel {
  ementa: string;
  idMateria: number;
  nomeMateria: string;
  codigoMateria: string;
  nivel: number; // Semester level (1-10 typically)
  creditos: number;
  status?: string | null;
  mencao?: string | null;
  professor?: string | null;
  /** Populated by course model - direct prerequisites as MateriaModel references */
  preRequisitos?: MateriaModel[];
}

// ============================================================================
// Subject Status Enum (for UI display and filtering)
// ============================================================================

export const SubjectStatusEnum = {
  NOT_STARTED: 'not_started',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  FAILED: 'failed',
  AVAILABLE: 'available',
  LOCKED: 'locked',
} as const;

export type SubjectStatusValue = typeof SubjectStatusEnum[keyof typeof SubjectStatusEnum];

// ============================================================================
// MateriaModel Helper Functions
// ============================================================================

/**
 * Get prerequisite codes as a list of strings
 */
export function getPrerequisiteCodes(materia: MateriaModel): string[] {
  return materia.preRequisitos?.map((m) => m.codigoMateria) ?? [];
}

/**
 * Get prerequisite names as a list of strings
 */
export function getPrerequisiteNames(materia: MateriaModel): string[] {
  return materia.preRequisitos?.map((m) => m.nomeMateria) ?? [];
}

/**
 * Check if this materia has any prerequisites
 */
export function hasPrerequisites(materia: MateriaModel): boolean {
  return (materia.preRequisitos?.length ?? 0) > 0;
}

/**
 * Check if this materia has any uncompleted prerequisites
 * @param materia The subject to check
 * @param completedCodes Set of completed subject codes
 * @param currentCodes Set of currently enrolled subject codes
 */
export function hasAnyPrerequisitesNotCompletedOrCurrent(
  materia: MateriaModel,
  completedCodes: Set<string>,
  currentCodes: Set<string>
): boolean {
  if (!hasPrerequisites(materia)) {
    return false;
  }

  const allCompletedOrCurrent = new Set([...completedCodes, ...currentCodes]);
  
  for (const prereq of materia.preRequisitos!) {
    if (!allCompletedOrCurrent.has(prereq.codigoMateria)) {
      return true; // Found a prerequisite that is not completed or current
    }
  }
  
  return false;
}

/**
 * Check if a specific materia is a prerequisite for this one
 */
export function hasPrerequisite(materia: MateriaModel, codigoMateria: string): boolean {
  return materia.preRequisitos?.some((m) => m.codigoMateria === codigoMateria) ?? false;
}

/**
 * Get the total number of prerequisite credits
 */
export function getTotalPrerequisiteCredits(materia: MateriaModel): number {
  return materia.preRequisitos?.reduce((sum, m) => sum + m.creditos, 0) ?? 0;
}

/**
 * Check if this materia can be taken based on completed prerequisite codes
 */
export function canBeTaken(
  materia: MateriaModel, 
  completedMateriasCodes: Set<string>
): boolean {
  if (!hasPrerequisites(materia)) return true;
  
  return materia.preRequisitos!.every(
    (prereq) => completedMateriasCodes.has(prereq.codigoMateria)
  );
}

/**
 * Determine the visual status of a subject based on user data
 */
export function determineSubjectStatus(
  materia: MateriaModel,
  completedCodes: Set<string>,
  currentCodes: Set<string>,
  failedCodes: Set<string>
): SubjectStatusValue {
  const code = materia.codigoMateria;
  
  if (completedCodes.has(code)) {
    return SubjectStatusEnum.COMPLETED;
  }
  
  if (currentCodes.has(code)) {
    return SubjectStatusEnum.IN_PROGRESS;
  }
  
  if (failedCodes.has(code)) {
    return SubjectStatusEnum.FAILED;
  }
  
  if (canBeTaken(materia, completedCodes)) {
    return SubjectStatusEnum.AVAILABLE;
  }
  
  return SubjectStatusEnum.LOCKED;
}

// ============================================================================
// Subject Display Utilities
// ============================================================================

/**
 * Get CSS class for subject status
 */
export function getStatusColorClass(status: SubjectStatusValue): string {
  const colorMap: Record<SubjectStatusValue, string> = {
    [SubjectStatusEnum.COMPLETED]: 'bg-green-500',
    [SubjectStatusEnum.IN_PROGRESS]: 'bg-blue-500',
    [SubjectStatusEnum.FAILED]: 'bg-red-500',
    [SubjectStatusEnum.AVAILABLE]: 'bg-yellow-500',
    [SubjectStatusEnum.LOCKED]: 'bg-gray-400',
    [SubjectStatusEnum.NOT_STARTED]: 'bg-gray-300',
  };
  return colorMap[status];
}

/**
 * Get human-readable status label
 */
export function getStatusLabel(status: SubjectStatusValue): string {
  const labelMap: Record<SubjectStatusValue, string> = {
    [SubjectStatusEnum.COMPLETED]: 'Aprovado',
    [SubjectStatusEnum.IN_PROGRESS]: 'Matriculado',
    [SubjectStatusEnum.FAILED]: 'Reprovado',
    [SubjectStatusEnum.AVAILABLE]: 'Disponível',
    [SubjectStatusEnum.LOCKED]: 'Bloqueado',
    [SubjectStatusEnum.NOT_STARTED]: 'Não iniciado',
  };
  return labelMap[status];
}
```

---

## 5. Equivalence Types

### File: `src/lib/types/equivalencia.ts`

```typescript
import type { MateriaModel } from './materia';

// ============================================================================
// EquivalenciaModel - Subject equivalence rules
// ============================================================================

export interface EquivalenciaModel {
  idEquivalencia: number;
  codigoMateriaOrigem: string;
  nomeMateriaOrigem: string;
  codigoMateriaEquivalente: string;
  nomeMateriaEquivalente: string;
  /** 
   * Expression defining equivalence logic
   * Uses "E" for AND, "OU" for OR
   * Example: "MAT101 E MAT102" or "FIS101 OU FIS102"
   */
  expressao: string;
  idCurso?: number | null;
  nomeCurso?: string | null;
  matrizCurricular?: string | null;
  curriculo?: string | null;
  dataVigencia?: string | null;
  fimVigencia?: string | null;
}

// ============================================================================
// Expression Evaluation Types
// ============================================================================

export interface ExpressionResult {
  isTrue: boolean;
  matchingMaterias: Set<string>;
}

export interface EquivalenciaResult {
  isEquivalente: boolean;
  equivalentes: MateriaModel[];
}

// ============================================================================
// Equivalence Expression Parser and Evaluator
// ============================================================================

/**
 * Remove outer parentheses if they encompass the entire expression
 */
function removeOuterParentheses(expression: string): string {
  let trimmed = expression.trim();
  
  if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
    let count = 0;
    for (let i = 0; i < trimmed.length; i++) {
      if (trimmed[i] === '(') count++;
      if (trimmed[i] === ')') count--;
      if (count === 0 && i < trimmed.length - 1) {
        // Parentheses close before the end
        return trimmed;
      }
    }
    // They do encompass everything, remove them
    return trimmed.substring(1, trimmed.length - 1).trim();
  }
  
  return trimmed;
}

/**
 * Find the main operator at the top level (outside parentheses)
 * @param expression The expression to search
 * @param operator Either 'OU' (OR) or 'E' (AND)
 */
function findMainOperator(expression: string, operator: string): number | null {
  let parenthesesCount = 0;
  const operatorLength = operator.length;
  
  // Search from right to left
  for (let i = expression.length - operatorLength; i >= 0; i--) {
    if (expression[i] === ')') parenthesesCount++;
    if (expression[i] === '(') parenthesesCount--;
    
    // Check if we found the operator at the top level
    if (
      parenthesesCount === 0 &&
      i + operatorLength <= expression.length &&
      expression.substring(i, i + operatorLength) === operator
    ) {
      // Make sure it's a whole word (surrounded by spaces or parentheses)
      const validBefore =
        i === 0 || expression[i - 1] === ' ' || expression[i - 1] === ')';
      const validAfter =
        i + operatorLength === expression.length ||
        expression[i + operatorLength] === ' ' ||
        expression[i + operatorLength] === '(';
      
      if (validBefore && validAfter) {
        return i;
      }
    }
  }
  
  return null;
}

/**
 * Evaluate an equivalence expression with tracking of matching materias
 * @param expression The boolean expression to evaluate
 * @param materias Set of completed subject codes
 */
export function evaluateExpressionWithTracking(
  expression: string,
  materias: Set<string>
): ExpressionResult {
  if (!expression || expression.trim() === '') {
    return { isTrue: false, matchingMaterias: new Set() };
  }
  
  // Remove outer parentheses
  expression = removeOuterParentheses(expression);
  
  // Find OR operator (lower precedence)
  const orIndex = findMainOperator(expression, 'OU');
  if (orIndex !== null) {
    const left = expression.substring(0, orIndex).trim();
    const right = expression.substring(orIndex + 2).trim();
    
    const leftResult = evaluateExpressionWithTracking(left, materias);
    const rightResult = evaluateExpressionWithTracking(right, materias);
    
    // For OR: if either side is true, include materias from true side(s)
    const matchingMaterias = new Set<string>();
    if (leftResult.isTrue) {
      leftResult.matchingMaterias.forEach((m) => matchingMaterias.add(m));
    }
    if (rightResult.isTrue) {
      rightResult.matchingMaterias.forEach((m) => matchingMaterias.add(m));
    }
    
    return {
      isTrue: leftResult.isTrue || rightResult.isTrue,
      matchingMaterias,
    };
  }
  
  // Find AND operator
  const andIndex = findMainOperator(expression, 'E');
  if (andIndex !== null) {
    const left = expression.substring(0, andIndex).trim();
    const right = expression.substring(andIndex + 1).trim();
    
    const leftResult = evaluateExpressionWithTracking(left, materias);
    const rightResult = evaluateExpressionWithTracking(right, materias);
    
    // For AND: only if both sides are true
    if (leftResult.isTrue && rightResult.isTrue) {
      const matchingMaterias = new Set<string>();
      leftResult.matchingMaterias.forEach((m) => matchingMaterias.add(m));
      rightResult.matchingMaterias.forEach((m) => matchingMaterias.add(m));
      return { isTrue: true, matchingMaterias };
    } else {
      return { isTrue: false, matchingMaterias: new Set() };
    }
  }
  
  // If no operators found, it's a subject code
  const subjectCode = expression.trim();
  const contains = materias.has(subjectCode);
  
  return {
    isTrue: contains,
    matchingMaterias: contains ? new Set([subjectCode]) : new Set(),
  };
}

/**
 * Evaluate if an expression is true (simplified version without tracking)
 */
export function evaluateExpression(expression: string, materias: Set<string>): boolean {
  return evaluateExpressionWithTracking(expression, materias).isTrue;
}

/**
 * Check if a subject is equivalent based on completed materias
 * @param equivalencia The equivalence rule to check
 * @param materiasCursadas List of completed subjects
 */
export function isMateriaEquivalente(
  equivalencia: EquivalenciaModel,
  materiasCursadas: MateriaModel[]
): EquivalenciaResult {
  const materias = new Set(materiasCursadas.map((m) => m.codigoMateria));
  
  const result = evaluateExpressionWithTracking(equivalencia.expressao.trim(), materias);
  
  // Filter materiasCursadas to only include those that contributed
  const equivalenteMaterias = materiasCursadas.filter((materia) =>
    result.matchingMaterias.has(materia.codigoMateria)
  );
  
  return {
    isEquivalente: result.isTrue,
    equivalentes: equivalenteMaterias,
  };
}

/**
 * Find all valid equivalences for a subject
 */
export function findValidEquivalences(
  subjectCode: string,
  equivalencias: EquivalenciaModel[],
  materiasCursadas: MateriaModel[]
): EquivalenciaResult[] {
  const results: EquivalenciaResult[] = [];
  
  for (const equiv of equivalencias) {
    if (equiv.codigoMateriaOrigem === subjectCode) {
      const result = isMateriaEquivalente(equiv, materiasCursadas);
      if (result.isEquivalente) {
        results.push(result);
      }
    }
  }
  
  return results;
}

/**
 * Check if a subject has any valid equivalence
 */
export function hasValidEquivalence(
  subjectCode: string,
  equivalencias: EquivalenciaModel[],
  completedCodes: Set<string>
): boolean {
  const relevantEquivalencias = equivalencias.filter(
    (e) => e.codigoMateriaOrigem === subjectCode
  );
  
  for (const equiv of relevantEquivalencias) {
    if (evaluateExpression(equiv.expressao, completedCodes)) {
      return true;
    }
  }
  
  return false;
}

/**
 * Parse expression to extract all subject codes mentioned
 */
export function extractSubjectCodesFromExpression(expression: string): string[] {
  // Remove operators and parentheses, split by whitespace
  const cleaned = expression
    .replace(/\bOU\b/g, ' ')
    .replace(/\bE\b/g, ' ')
    .replace(/[()]/g, ' ')
    .trim();
  
  return cleaned.split(/\s+/).filter((code) => code.length > 0);
}
```

---

## 6. Prerequisite Types

### File: `src/lib/types/prerequisite-tree.ts`

```typescript
import type { MateriaModel } from './materia';
import type { CursoModel, PreRequisitoModel, CoRequisitoModel } from './curso';

// ============================================================================
// PrerequisiteTreeNode - A node in the prerequisite tree
// ============================================================================

export interface PrerequisiteTreeNode {
  materia: MateriaModel;
  /** Direct prerequisites */
  prerequisites: PrerequisiteTreeNode[];
  /** Subjects that depend on this one */
  dependents: PrerequisiteTreeNode[];
  /** Direct co-requisites */
  coRequisites: PrerequisiteTreeNode[];
  /** Distance from root (subjects with no prerequisites) */
  depth: number;
  /** Has no prerequisites */
  isRoot: boolean;
  /** No subjects depend on this one */
  isLeaf: boolean;
}

// ============================================================================
// PrerequisiteTree - Complete tree structure for a course
// ============================================================================

export interface PrerequisiteTree {
  nodes: Map<string, PrerequisiteTreeNode>;
  /** Subjects with no prerequisites */
  rootNodes: PrerequisiteTreeNode[];
  /** Subjects that are not prerequisites for others */
  leafNodes: PrerequisiteTreeNode[];
  maxDepth: number;
}

// ============================================================================
// Tree Node Helper Functions
// ============================================================================

/**
 * Get all prerequisite subject codes recursively
 */
export function getAllPrerequisitesCodes(node: PrerequisiteTreeNode): Set<string> {
  const allPrereqs = new Set<string>();
  
  for (const prereq of node.prerequisites) {
    allPrereqs.add(prereq.materia.codigoMateria);
    getAllPrerequisitesCodes(prereq).forEach((code) => allPrereqs.add(code));
  }
  
  return allPrereqs;
}

/**
 * Get all dependent subject codes recursively
 */
export function getAllDependentsCodes(node: PrerequisiteTreeNode): Set<string> {
  const allDependents = new Set<string>();
  
  for (const dependent of node.dependents) {
    allDependents.add(dependent.materia.codigoMateria);
    getAllDependentsCodes(dependent).forEach((code) => allDependents.add(code));
  }
  
  return allDependents;
}

/**
 * Get all co-requisite subject codes
 */
export function getAllCoRequisitesCodes(node: PrerequisiteTreeNode): Set<string> {
  return new Set(node.coRequisites.map((cr) => cr.materia.codigoMateria));
}

/**
 * Check if this subject can be taken given completed subjects
 */
export function nodeCanBeTaken(
  node: PrerequisiteTreeNode,
  completedSubjects: Set<string>
): boolean {
  return node.prerequisites.every((prereq) =>
    completedSubjects.has(prereq.materia.codigoMateria)
  );
}

/**
 * Get the prerequisite chain as a list of levels
 */
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

// ============================================================================
// Tree Building Functions
// ============================================================================

/**
 * Build prerequisite tree from course data
 */
export function buildPrerequisiteTree(curso: CursoModel): PrerequisiteTree {
  const nodes = new Map<string, PrerequisiteTreeNode>();
  const materiaMap = new Map<string, MateriaModel>();
  
  // Create map of all materias by code
  for (const materia of curso.materias) {
    materiaMap.set(materia.codigoMateria, materia);
  }
  
  // Initialize all nodes
  for (const materia of curso.materias) {
    nodes.set(materia.codigoMateria, {
      materia,
      prerequisites: [],
      dependents: [],
      coRequisites: [],
      depth: 0,
      isRoot: true,
      isLeaf: true,
    });
  }
  
  // Build prerequisite relationships
  for (const prereq of curso.preRequisitos) {
    const materiaCode = getMateriaCodeById(curso.materias, prereq.idMateria);
    const prereqCode = prereq.codigoMateriaRequisito;
    
    if (materiaCode && nodes.has(materiaCode) && nodes.has(prereqCode)) {
      const materiaNode = nodes.get(materiaCode)!;
      const prereqNode = nodes.get(prereqCode)!;
      
      // Add prerequisite relationship
      materiaNode.prerequisites.push(prereqNode);
      materiaNode.isRoot = false;
      
      // Add dependent relationship
      prereqNode.dependents.push(materiaNode);
      prereqNode.isLeaf = false;
    }
  }
  
  // Build co-requisite relationships
  for (const coreq of curso.coRequisitos) {
    const materiaCode = getMateriaCodeById(curso.materias, coreq.idMateria);
    const coreqCode = coreq.codigoMateriaCoRequisito;
    
    if (materiaCode && nodes.has(materiaCode) && nodes.has(coreqCode)) {
      const materiaNode = nodes.get(materiaCode)!;
      const coreqNode = nodes.get(coreqCode)!;
      
      // Add co-requisite relationship (bidirectional)
      materiaNode.coRequisites.push(coreqNode);
      coreqNode.coRequisites.push(materiaNode);
    }
  }
  
  // Calculate depths
  const depths = calculateDepths(nodes);
  
  // Update nodes with calculated depths and get max
  let maxDepth = 0;
  for (const [code, node] of nodes) {
    node.depth = depths.get(code) ?? 0;
    if (node.depth > maxDepth) maxDepth = node.depth;
  }
  
  // Get root and leaf nodes
  const rootNodes = [...nodes.values()].filter((n) => n.isRoot);
  const leafNodes = [...nodes.values()].filter((n) => n.isLeaf);
  
  return { nodes, rootNodes, leafNodes, maxDepth };
}

function getMateriaCodeById(materias: MateriaModel[], id: number): string | null {
  const materia = materias.find((m) => m.idMateria === id);
  return materia?.codigoMateria ?? null;
}

function calculateDepths(nodes: Map<string, PrerequisiteTreeNode>): Map<string, number> {
  const depths = new Map<string, number>();
  
  // Initialize all depths to 0
  for (const code of nodes.keys()) {
    depths.set(code, 0);
  }
  
  // Calculate depths using topological sort approach
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

// ============================================================================
// Tree Query Functions
// ============================================================================

/**
 * Get nodes organized by depth level
 */
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

/**
 * Get prerequisite chain for a specific subject
 */
export function getPrerequisiteChainByCode(
  tree: PrerequisiteTree,
  subjectCode: string
): string[][] {
  const node = tree.nodes.get(subjectCode);
  return node ? getPrerequisiteChain(node) : [];
}

/**
 * Get all subjects that can be taken given completed subjects
 */
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

/**
 * Get subjects organized by semester considering prerequisites
 */
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

/**
 * Find cycles in the prerequisite graph (which shouldn't exist)
 */
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
        // Found a cycle
        const cycleStart = path.indexOf(prereqCode);
        cycles.push([...path.slice(cycleStart), prereqCode]);
      }
    }
  }
  
  path.pop();
  recursionStack.delete(nodeCode);
}

// ============================================================================
// Visualization Data
// ============================================================================

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

/**
 * Get visualization data for the entire prerequisite tree
 */
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
      dependents: node.dependents.map((d) => d.materia.codigoMateria),
    });
  }
  
  return {
    nodesByLevel,
    availableSubjects: getAvailableSubjects(tree, completedSubjects),
    optimalOrganization: getOptimalSemesterOrganization(tree),
    maxDepth: tree.maxDepth,
    rootNodes: tree.rootNodes.map((n) => n.materia.codigoMateria),
    leafNodes: tree.leafNodes.map((n) => n.materia.codigoMateria),
    cycles: findCycles(tree),
  };
}
```

---

## 7. API Response Types

### File: `src/lib/types/api.ts`

```typescript
// ============================================================================
// Generic API Response Types
// ============================================================================

/**
 * Base API response wrapper
 */
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: ApiError;
  message?: string;
}

/**
 * API error structure
 */
export interface ApiError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
  statusCode?: number;
}

/**
 * Paginated response wrapper
 */
export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    pageSize: number;
    totalItems: number;
    totalPages: number;
    hasNext: boolean;
    hasPrev: boolean;
  };
}

// ============================================================================
// Specific API Response Types
// ============================================================================

export interface LoginResponse {
  user: {
    id_user: number;
    email: string;
    nome_completo: string;
    dados_users?: Array<{
      fluxograma_atual?: string | null;
    }>;
  };
  token: string;
}

export interface CursosListResponse {
  cursos: Array<{
    id_curso: number;
    nome_curso: string;
    matriz_curricular: string;
    creditos: number | null;
    tipo_curso: string;
    classificacao: string;
  }>;
}

export interface CursoDetailResponse {
  id_curso: number;
  nome_curso: string;
  matriz_curricular: string;
  creditos: number | null;
  tipo_curso: string;
  classificacao: string;
  materias_por_curso: Array<{
    nivel: number;
    materias?: {
      id_materia: number;
      nome_materia: string;
      codigo_materia: string;
      ementa: string;
      carga_horaria: number;
    };
    id_materia?: number;
    nome_materia?: string;
    codigo_materia?: string;
    ementa?: string;
    carga_horaria?: number;
  }>;
  pre_requisitos?: Array<{
    id_pre_requisito: number;
    id_materia: number;
    id_materia_requisito: number;
    codigo_materia_requisito: string;
    nome_materia_requisito: string;
  }>;
  co_requisitos?: Array<{
    id_co_requisito: number;
    id_materia: number;
    id_materia_corequisito: number;
    codigo_materia_corequisito: string;
    nome_materia_corequisito: string;
  }>;
  equivalencias?: Array<{
    id_equivalencia: number;
    codigo_materia_origem: string;
    nome_materia_origem: string;
    codigo_materia_equivalente: string;
    nome_materia_equivalente: string;
    expressao: string;
    id_curso?: number;
    nome_curso?: string;
    matriz_curricular?: string;
    curriculo?: string;
    data_vigencia?: string;
    fim_vigencia?: string;
  }>;
}

export interface SaveFluxogramaRequest {
  id_user: number;
  fluxograma_atual: {
    nome_curso: string;
    ira: number;
    matricula: string;
    matriz_curricular: string;
    semestre_atual: number;
    ano_atual: string;
    horas_integralizadas: number;
    suspensoes: string[];
    dados_fluxograma: Array<
      Array<{
        codigo: string;
        mencao: string;
        professor: string;
        status: string;
        ano_periodo?: string;
        frequencia?: string;
        tipo_dado?: string;
        turma?: string;
      }>
    >;
  };
}

// ============================================================================
// API Helper Functions
// ============================================================================

/**
 * Create a successful API response
 */
export function createSuccessResponse<T>(data: T, message?: string): ApiResponse<T> {
  return {
    success: true,
    data,
    message,
  };
}

/**
 * Create an error API response
 */
export function createErrorResponse(
  code: string,
  message: string,
  statusCode?: number,
  details?: Record<string, unknown>
): ApiResponse<never> {
  return {
    success: false,
    error: { code, message, statusCode, details },
  };
}

/**
 * Type guard to check if response is successful
 */
export function isSuccessResponse<T>(
  response: ApiResponse<T>
): response is ApiResponse<T> & { data: T } {
  return response.success && response.data !== undefined;
}

/**
 * Type guard to check if response is an error
 */
export function isErrorResponse<T>(
  response: ApiResponse<T>
): response is ApiResponse<T> & { error: ApiError } {
  return !response.success && response.error !== undefined;
}
```

---

## 8. Zod Schemas

### File: `src/lib/schemas/index.ts`

```typescript
import { z } from 'zod';

// ============================================================================
// DadosMateria Schema
// ============================================================================

export const DadosMateriaSchema = z.object({
  codigoMateria: z.string(),
  mencao: z.string(),
  professor: z.string(),
  status: z.string(),
  anoPeriodo: z.string().nullable().optional(),
  frequencia: z.string().nullable().optional(),
  tipoDado: z.string().nullable().optional(),
  turma: z.string().nullable().optional(),
});

export type DadosMateriaFromSchema = z.infer<typeof DadosMateriaSchema>;

// ============================================================================
// DadosFluxogramaUser Schema
// ============================================================================

export const DadosFluxogramaUserSchema = z.object({
  nomeCurso: z.string(),
  ira: z.number(),
  matricula: z.string(),
  horasIntegralizadas: z.number().default(0),
  suspensoes: z.array(z.string()).default([]),
  anoAtual: z.string().default(''),
  matrizCurricular: z.string(),
  semestreAtual: z.number().default(0),
  dadosFluxograma: z.array(z.array(DadosMateriaSchema)),
});

export type DadosFluxogramaUserFromSchema = z.infer<typeof DadosFluxogramaUserSchema>;

// ============================================================================
// UserModel Schema
// ============================================================================

export const UserModelSchema = z.object({
  idUser: z.number(),
  email: z.string().email(),
  nomeCompleto: z.string(),
  dadosFluxograma: DadosFluxogramaUserSchema.nullable().optional(),
  token: z.string().nullable().optional(),
});

export type UserModelFromSchema = z.infer<typeof UserModelSchema>;

// ============================================================================
// MateriaModel Schema
// ============================================================================

export const MateriaModelSchema = z.object({
  ementa: z.string(),
  idMateria: z.number(),
  nomeMateria: z.string(),
  codigoMateria: z.string(),
  nivel: z.number(),
  creditos: z.number(),
  status: z.string().nullable().optional(),
  mencao: z.string().nullable().optional(),
  professor: z.string().nullable().optional(),
});

export type MateriaModelFromSchema = z.infer<typeof MateriaModelSchema>;

// ============================================================================
// PreRequisitoModel Schema
// ============================================================================

export const PreRequisitoModelSchema = z.object({
  idPreRequisito: z.number(),
  idMateria: z.number(),
  idMateriaRequisito: z.number(),
  codigoMateriaRequisito: z.string(),
  nomeMateriaRequisito: z.string(),
});

export type PreRequisitoModelFromSchema = z.infer<typeof PreRequisitoModelSchema>;

// ============================================================================
// CoRequisitoModel Schema
// ============================================================================

export const CoRequisitoModelSchema = z.object({
  idCoRequisito: z.number(),
  idMateria: z.number(),
  idMateriaCoRequisito: z.number(),
  codigoMateriaCoRequisito: z.string(),
  nomeMateriaCoRequisito: z.string(),
});

export type CoRequisitoModelFromSchema = z.infer<typeof CoRequisitoModelSchema>;

// ============================================================================
// EquivalenciaModel Schema
// ============================================================================

export const EquivalenciaModelSchema = z.object({
  idEquivalencia: z.number(),
  codigoMateriaOrigem: z.string(),
  nomeMateriaOrigem: z.string(),
  codigoMateriaEquivalente: z.string(),
  nomeMateriaEquivalente: z.string(),
  expressao: z.string(),
  idCurso: z.number().nullable().optional(),
  nomeCurso: z.string().nullable().optional(),
  matrizCurricular: z.string().nullable().optional(),
  curriculo: z.string().nullable().optional(),
  dataVigencia: z.string().nullable().optional(),
  fimVigencia: z.string().nullable().optional(),
});

export type EquivalenciaModelFromSchema = z.infer<typeof EquivalenciaModelSchema>;

// ============================================================================
// CursoModel Schema
// ============================================================================

export const CursoModelSchema = z.object({
  nomeCurso: z.string(),
  matrizCurricular: z.string(),
  idCurso: z.number(),
  totalCreditos: z.number().nullable(),
  classificacao: z.string(),
  tipoCurso: z.string(),
  materias: z.array(MateriaModelSchema),
  semestres: z.number(),
  equivalencias: z.array(EquivalenciaModelSchema).default([]),
  preRequisitos: z.array(PreRequisitoModelSchema).default([]),
  coRequisitos: z.array(CoRequisitoModelSchema).default([]),
});

export type CursoModelFromSchema = z.infer<typeof CursoModelSchema>;

// ============================================================================
// MinimalCursoModel Schema
// ============================================================================

export const MinimalCursoModelSchema = z.object({
  nomeCurso: z.string(),
  matrizCurricular: z.string(),
  idCurso: z.number(),
  creditos: z.number().nullable(),
  tipoCurso: z.string(),
  classificacao: z.string(),
});

export type MinimalCursoModelFromSchema = z.infer<typeof MinimalCursoModelSchema>;

// ============================================================================
// API Response Schemas
// ============================================================================

export const ApiErrorSchema = z.object({
  code: z.string(),
  message: z.string(),
  details: z.record(z.unknown()).optional(),
  statusCode: z.number().optional(),
});

export function createApiResponseSchema<T extends z.ZodType>(dataSchema: T) {
  return z.object({
    success: z.boolean(),
    data: dataSchema.optional(),
    error: ApiErrorSchema.optional(),
    message: z.string().optional(),
  });
}

// ============================================================================
// Validation Helper Functions
// ============================================================================

/**
 * Safely parse data with a Zod schema
 */
export function safeParse<T extends z.ZodType>(
  schema: T,
  data: unknown
): { success: true; data: z.infer<T> } | { success: false; error: z.ZodError } {
  const result = schema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, error: result.error };
}

/**
 * Parse data with a Zod schema, throwing on error
 */
export function parse<T extends z.ZodType>(schema: T, data: unknown): z.infer<T> {
  return schema.parse(data);
}

/**
 * Validate and transform API response data
 */
export function validateApiResponse<T extends z.ZodType>(
  schema: T,
  response: unknown
): z.infer<T> | null {
  const result = schema.safeParse(response);
  if (result.success) {
    return result.data;
  }
  console.error('Validation error:', result.error.errors);
  return null;
}
```

---

## 9. Type Guards

### File: `src/lib/types/guards.ts`

```typescript
import type { UserModel, DadosMateria, DadosFluxogramaUser } from './user';
import type { CursoModel, MinimalCursoModel, PreRequisitoModel, CoRequisitoModel } from './curso';
import type { MateriaModel } from './materia';
import type { EquivalenciaModel } from './equivalencia';
import type { ApiResponse, ApiError } from './api';

// ============================================================================
// Primitive Type Guards
// ============================================================================

export function isString(value: unknown): value is string {
  return typeof value === 'string';
}

export function isNumber(value: unknown): value is number {
  return typeof value === 'number' && !isNaN(value);
}

export function isBoolean(value: unknown): value is boolean {
  return typeof value === 'boolean';
}

export function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function isArray(value: unknown): value is unknown[] {
  return Array.isArray(value);
}

export function isNonEmptyString(value: unknown): value is string {
  return isString(value) && value.trim().length > 0;
}

// ============================================================================
// User Type Guards
// ============================================================================

export function isDadosMateria(value: unknown): value is DadosMateria {
  if (!isObject(value)) return false;
  
  return (
    isString(value.codigoMateria) &&
    isString(value.mencao) &&
    isString(value.professor) &&
    isString(value.status)
  );
}

export function isDadosFluxogramaUser(value: unknown): value is DadosFluxogramaUser {
  if (!isObject(value)) return false;
  
  return (
    isString(value.nomeCurso) &&
    isNumber(value.ira) &&
    isString(value.matricula) &&
    isNumber(value.horasIntegralizadas) &&
    isArray(value.suspensoes) &&
    isString(value.anoAtual) &&
    isString(value.matrizCurricular) &&
    isNumber(value.semestreAtual) &&
    isArray(value.dadosFluxograma)
  );
}

export function isUserModel(value: unknown): value is UserModel {
  if (!isObject(value)) return false;
  
  return (
    isNumber(value.idUser) &&
    isString(value.email) &&
    isString(value.nomeCompleto)
  );
}

export function hasFluxogramaData(user: UserModel): user is UserModel & { dadosFluxograma: DadosFluxogramaUser } {
  return user.dadosFluxograma !== null && user.dadosFluxograma !== undefined;
}

export function hasToken(user: UserModel): user is UserModel & { token: string } {
  return isNonEmptyString(user.token);
}

// ============================================================================
// Course Type Guards
// ============================================================================

export function isMateriaModel(value: unknown): value is MateriaModel {
  if (!isObject(value)) return false;
  
  return (
    isString(value.ementa) &&
    isNumber(value.idMateria) &&
    isString(value.nomeMateria) &&
    isString(value.codigoMateria) &&
    isNumber(value.nivel) &&
    isNumber(value.creditos)
  );
}

export function isPreRequisitoModel(value: unknown): value is PreRequisitoModel {
  if (!isObject(value)) return false;
  
  return (
    isNumber(value.idPreRequisito) &&
    isNumber(value.idMateria) &&
    isNumber(value.idMateriaRequisito) &&
    isString(value.codigoMateriaRequisito) &&
    isString(value.nomeMateriaRequisito)
  );
}

export function isCoRequisitoModel(value: unknown): value is CoRequisitoModel {
  if (!isObject(value)) return false;
  
  return (
    isNumber(value.idCoRequisito) &&
    isNumber(value.idMateria) &&
    isNumber(value.idMateriaCoRequisito) &&
    isString(value.codigoMateriaCoRequisito) &&
    isString(value.nomeMateriaCoRequisito)
  );
}

export function isCursoModel(value: unknown): value is CursoModel {
  if (!isObject(value)) return false;
  
  return (
    isString(value.nomeCurso) &&
    isString(value.matrizCurricular) &&
    isNumber(value.idCurso) &&
    isString(value.classificacao) &&
    isString(value.tipoCurso) &&
    isArray(value.materias) &&
    isNumber(value.semestres)
  );
}

export function isMinimalCursoModel(value: unknown): value is MinimalCursoModel {
  if (!isObject(value)) return false;
  
  return (
    isString(value.nomeCurso) &&
    isString(value.matrizCurricular) &&
    isNumber(value.idCurso) &&
    isString(value.tipoCurso) &&
    isString(value.classificacao)
  );
}

// ============================================================================
// Equivalence Type Guards
// ============================================================================

export function isEquivalenciaModel(value: unknown): value is EquivalenciaModel {
  if (!isObject(value)) return false;
  
  return (
    isNumber(value.idEquivalencia) &&
    isString(value.codigoMateriaOrigem) &&
    isString(value.nomeMateriaOrigem) &&
    isString(value.codigoMateriaEquivalente) &&
    isString(value.nomeMateriaEquivalente) &&
    isString(value.expressao)
  );
}

// ============================================================================
// API Response Type Guards
// ============================================================================

export function isApiError(value: unknown): value is ApiError {
  if (!isObject(value)) return false;
  
  return isString(value.code) && isString(value.message);
}

export function isApiResponse<T>(value: unknown): value is ApiResponse<T> {
  if (!isObject(value)) return false;
  
  return isBoolean(value.success);
}

export function isSuccessfulApiResponse<T>(
  value: ApiResponse<T>
): value is ApiResponse<T> & { data: T } {
  return value.success === true && value.data !== undefined;
}

export function isFailedApiResponse<T>(
  value: ApiResponse<T>
): value is ApiResponse<T> & { error: ApiError } {
  return value.success === false && value.error !== undefined;
}

// ============================================================================
// Assertion Functions
// ============================================================================

export function assertIsString(value: unknown, name = 'value'): asserts value is string {
  if (!isString(value)) {
    throw new TypeError(`Expected ${name} to be a string, got ${typeof value}`);
  }
}

export function assertIsNumber(value: unknown, name = 'value'): asserts value is number {
  if (!isNumber(value)) {
    throw new TypeError(`Expected ${name} to be a number, got ${typeof value}`);
  }
}

export function assertIsUserModel(value: unknown): asserts value is UserModel {
  if (!isUserModel(value)) {
    throw new TypeError('Expected value to be a UserModel');
  }
}

export function assertIsCursoModel(value: unknown): asserts value is CursoModel {
  if (!isCursoModel(value)) {
    throw new TypeError('Expected value to be a CursoModel');
  }
}
```

---

## 10. Factory Functions

### File: `src/lib/factories/index.ts`

```typescript
import type { UserModel, DadosMateria, DadosFluxogramaUser } from '../types/user';
import type { CursoModel, MinimalCursoModel, PreRequisitoModel, CoRequisitoModel } from '../types/curso';
import type { MateriaModel } from '../types/materia';
import type { EquivalenciaModel } from '../types/equivalencia';

// ============================================================================
// DadosMateria Factory
// ============================================================================

export function createDadosMateriaFromJson(json: Record<string, unknown>): DadosMateria {
  return {
    codigoMateria: String(json.codigo ?? ''),
    mencao: String(json.mencao ?? '-'),
    professor: String(json.professor ?? ''),
    status: String(json.status ?? '-'),
    anoPeriodo: json.ano_periodo != null ? String(json.ano_periodo) : null,
    frequencia: json.frequencia != null ? String(json.frequencia) : null,
    tipoDado: json.tipo_dado != null ? String(json.tipo_dado) : null,
    turma: json.turma != null ? String(json.turma) : null,
  };
}

export function dadosMateriaToJson(dados: DadosMateria): Record<string, unknown> {
  return {
    codigo: dados.codigoMateria,
    mencao: dados.mencao,
    professor: dados.professor,
    status: dados.status,
    ano_periodo: dados.anoPeriodo,
    frequencia: dados.frequencia,
    tipo_dado: dados.tipoDado,
    turma: dados.turma,
  };
}

// ============================================================================
// DadosFluxogramaUser Factory
// ============================================================================

export function createDadosFluxogramaUserFromJson(
  json: Record<string, unknown>
): DadosFluxogramaUser {
  const dadosFluxograma = json.dados_fluxograma as unknown[][];
  
  return {
    nomeCurso: String(json.nome_curso ?? ''),
    ira: Number(json.ira ?? 0),
    matricula: String(json.matricula ?? ''),
    semestreAtual: Number(json.semestre_atual ?? 0),
    anoAtual: String(json.ano_atual ?? ''),
    matrizCurricular: String(json.matriz_curricular ?? ''),
    horasIntegralizadas: Number(json.horas_integralizadas ?? 0),
    suspensoes: Array.isArray(json.suspensoes)
      ? (json.suspensoes as unknown[]).map(String)
      : [],
    dadosFluxograma: dadosFluxograma.map((semester) =>
      semester.map((materia) => createDadosMateriaFromJson(materia as Record<string, unknown>))
    ),
  };
}

export function dadosFluxogramaUserToJson(dados: DadosFluxogramaUser): Record<string, unknown> {
  return {
    nome_curso: dados.nomeCurso,
    ira: dados.ira,
    matricula: dados.matricula,
    matriz_curricular: dados.matrizCurricular,
    semestre_atual: dados.semestreAtual,
    ano_atual: dados.anoAtual,
    horas_integralizadas: dados.horasIntegralizadas,
    suspensoes: dados.suspensoes,
    dados_fluxograma: dados.dadosFluxograma.map((semester) =>
      semester.map(dadosMateriaToJson)
    ),
  };
}

// ============================================================================
// UserModel Factory
// ============================================================================

export function createUserModelFromJson(json: Record<string, unknown>): UserModel {
  let dadosFluxograma: DadosFluxogramaUser | null = null;
  
  const dadosUsers = json.dados_users as Array<Record<string, unknown>> | undefined;
  if (
    dadosUsers &&
    dadosUsers.length > 0 &&
    dadosUsers[0] != null &&
    dadosUsers[0].fluxograma_atual != null
  ) {
    const fluxogramaData =
      typeof dadosUsers[0].fluxograma_atual === 'string'
        ? JSON.parse(dadosUsers[0].fluxograma_atual)
        : dadosUsers[0].fluxograma_atual;
    
    dadosFluxograma = createDadosFluxogramaUserFromJson(fluxogramaData);
  }
  
  return {
    idUser: Number(json.id_user),
    email: String(json.email ?? ''),
    nomeCompleto: String(json.nome_completo ?? ''),
    dadosFluxograma,
    token: json.token != null ? String(json.token) : null,
  };
}

export function userModelToJson(
  user: UserModel,
  options: { includeToken?: boolean; includeDadosFluxograma?: boolean } = {}
): Record<string, unknown> {
  const result: Record<string, unknown> = {
    id_user: user.idUser,
    email: user.email,
    nome_completo: user.nomeCompleto,
  };
  
  if (options.includeToken && user.token) {
    result.token = user.token;
  }
  
  if (options.includeDadosFluxograma && user.dadosFluxograma) {
    result.dados_users = [
      {
        fluxograma_atual: JSON.stringify(dadosFluxogramaUserToJson(user.dadosFluxograma)),
      },
    ];
  }
  
  return result;
}

export function userModelToJsonDadosFluxograma(user: UserModel): Record<string, unknown> {
  return {
    id_user: user.idUser,
    fluxograma_atual: user.dadosFluxograma
      ? dadosFluxogramaUserToJson(user.dadosFluxograma)
      : null,
  };
}

// ============================================================================
// MateriaModel Factory
// ============================================================================

export function createMateriaModelFromJson(json: Record<string, unknown>): MateriaModel {
  // Handle nested structure from API
  const materiaData = (json.materias as Record<string, unknown>) ?? json;
  
  return {
    ementa: String(materiaData.ementa ?? ''),
    idMateria: Number(materiaData.id_materia ?? 0),
    nomeMateria: String(materiaData.nome_materia ?? ''),
    codigoMateria: String(materiaData.codigo_materia ?? ''),
    creditos: Number(materiaData.carga_horaria ?? 0) / 15,
    nivel: Number(json.nivel ?? 0),
    status: materiaData.status != null ? String(materiaData.status) : null,
    mencao: materiaData.mencao != null ? String(materiaData.mencao) : null,
    professor: materiaData.professor != null ? String(materiaData.professor) : null,
    preRequisitos: [],
  };
}

// ============================================================================
// PreRequisitoModel Factory
// ============================================================================

export function createPreRequisitoModelFromJson(
  json: Record<string, unknown>
): PreRequisitoModel {
  return {
    idPreRequisito: Number(json.id_pre_requisito ?? 0),
    idMateria: Number(json.id_materia ?? 0),
    idMateriaRequisito: Number(json.id_materia_requisito ?? 0),
    codigoMateriaRequisito: String(json.codigo_materia_requisito ?? ''),
    nomeMateriaRequisito: String(json.nome_materia_requisito ?? ''),
  };
}

// ============================================================================
// CoRequisitoModel Factory
// ============================================================================

export function createCoRequisitoModelFromJson(
  json: Record<string, unknown>
): CoRequisitoModel {
  return {
    idCoRequisito: Number(json.id_co_requisito ?? 0),
    idMateria: Number(json.id_materia ?? 0),
    idMateriaCoRequisito: Number(json.id_materia_corequisito ?? 0),
    codigoMateriaCoRequisito: String(json.codigo_materia_corequisito ?? ''),
    nomeMateriaCoRequisito: String(json.nome_materia_corequisito ?? ''),
  };
}

// ============================================================================
// EquivalenciaModel Factory
// ============================================================================

export function createEquivalenciaModelFromJson(
  json: Record<string, unknown>
): EquivalenciaModel {
  return {
    idEquivalencia: Number(json.id_equivalencia ?? 0),
    codigoMateriaOrigem: String(json.codigo_materia_origem ?? ''),
    nomeMateriaOrigem: String(json.nome_materia_origem ?? ''),
    codigoMateriaEquivalente: String(json.codigo_materia_equivalente ?? ''),
    nomeMateriaEquivalente: String(json.nome_materia_equivalente ?? ''),
    expressao: String(json.expressao ?? ''),
    idCurso: json.id_curso != null ? Number(json.id_curso) : null,
    nomeCurso: json.nome_curso != null ? String(json.nome_curso) : null,
    matrizCurricular: json.matriz_curricular != null ? String(json.matriz_curricular) : null,
    curriculo: json.curriculo != null ? String(json.curriculo) : null,
    dataVigencia: json.data_vigencia != null ? String(json.data_vigencia) : null,
    fimVigencia: json.fim_vigencia != null ? String(json.fim_vigencia) : null,
  };
}

// ============================================================================
// CursoModel Factory
// ============================================================================

export function createCursoModelFromMinimalJson(json: Record<string, unknown>): CursoModel {
  return {
    nomeCurso: String(json.nome_curso ?? ''),
    matrizCurricular: String(json.matriz_curricular ?? ''),
    idCurso: Number(json.id_curso ?? 0),
    totalCreditos: json.creditos != null ? Number(json.creditos) : null,
    tipoCurso: String(json.tipo_curso ?? 'outro'),
    classificacao: String(json.classificacao ?? 'outro'),
    materias: [],
    semestres: 0,
    equivalencias: [],
    preRequisitos: [],
    coRequisitos: [],
  };
}

export function createCursoModelFromJson(json: Record<string, unknown>): CursoModel {
  const materiasPorCurso = json.materias_por_curso as Array<Record<string, unknown>> ?? [];
  const equivalenciasJson = json.equivalencias as Array<Record<string, unknown>> ?? [];
  const preRequisitosJson = json.pre_requisitos as Array<Record<string, unknown>> ?? [];
  const coRequisitosJson = json.co_requisitos as Array<Record<string, unknown>> ?? [];
  
  const materias = materiasPorCurso.map(createMateriaModelFromJson);
  
  // Calculate max semester
  let maxSemestre = 0;
  for (const materia of materias) {
    if (materia.nivel > maxSemestre) {
      maxSemestre = materia.nivel;
    }
  }
  
  const allPreRequisitos = preRequisitosJson.map(createPreRequisitoModelFromJson);
  const allCoRequisitos = coRequisitosJson.map(createCoRequisitoModelFromJson);
  
  // Filter prerequisites to only those within the course
  const materiasInCursoFromCodigo = new Set(
    materias.filter((m) => m.nivel !== 0).map((m) => m.codigoMateria)
  );
  
  const preRequisitosInCurso = allPreRequisitos.filter((pr) =>
    materiasInCursoFromCodigo.has(pr.codigoMateriaRequisito)
  );
  
  // Filter corequisites to only those within the course
  const materiasInCursoFromCodigoCoReq = new Set(materias.map((m) => m.codigoMateria));
  
  const coRequisitosInCurso = allCoRequisitos.filter((cr) =>
    materiasInCursoFromCodigoCoReq.has(cr.codigoMateriaCoRequisito)
  );
  
  const curso: CursoModel = {
    nomeCurso: String(json.nome_curso ?? ''),
    matrizCurricular: String(json.matriz_curricular ?? ''),
    idCurso: Number(json.id_curso ?? 0),
    totalCreditos: json.creditos != null ? Number(json.creditos) : null,
    tipoCurso: String(json.tipo_curso ?? ''),
    classificacao: String(json.classificacao ?? ''),
    materias,
    semestres: maxSemestre,
    equivalencias: equivalenciasJson.map(createEquivalenciaModelFromJson),
    preRequisitos: preRequisitosInCurso,
    coRequisitos: coRequisitosInCurso,
  };
  
  // Populate prerequisites for all materias
  populatePrerequisites(curso);
  
  return curso;
}

/**
 * Populate prerequisites for all materias in a course
 */
function populatePrerequisites(curso: CursoModel): void {
  // Clear existing prerequisites
  for (const materia of curso.materias) {
    materia.preRequisitos = [];
  }
  
  // Build prerequisite map
  const materiaMap = new Map<string, MateriaModel>();
  for (const materia of curso.materias) {
    materiaMap.set(materia.codigoMateria, materia);
  }
  
  const prerequisiteMap = new Map<string, string[]>();
  
  // Build prerequisite map from preRequisitos data
  for (const preReq of curso.preRequisitos) {
    const targetMateria = curso.materias.find((m) => m.idMateria === preReq.idMateria);
    if (!targetMateria) continue;
    
    const materiaCode = targetMateria.codigoMateria;
    const prereqCode = preReq.codigoMateriaRequisito;
    
    if (!prerequisiteMap.has(materiaCode)) {
      prerequisiteMap.set(materiaCode, []);
    }
    prerequisiteMap.get(materiaCode)!.push(prereqCode);
  }
  
  // Populate prerequisites for each materia
  for (const materia of curso.materias) {
    const directPrerequisites = prerequisiteMap.get(materia.codigoMateria) ?? [];
    
    // Add direct prerequisites
    for (const prereqCode of directPrerequisites) {
      const prereqMateria = materiaMap.get(prereqCode);
      if (prereqMateria) {
        materia.preRequisitos!.push(prereqMateria);
      }
    }
    
    // Collect all prerequisites (including transitive)
    const allPrerequisites = new Set<string>();
    collectAllPrerequisites(materia.codigoMateria, prerequisiteMap, allPrerequisites);
    
    // Add all prerequisites (avoiding duplicates)
    const existingCodes = new Set(materia.preRequisitos!.map((m) => m.codigoMateria));
    for (const prereqCode of allPrerequisites) {
      const prereqMateria = materiaMap.get(prereqCode);
      if (prereqMateria && !existingCodes.has(prereqCode)) {
        materia.preRequisitos!.push(prereqMateria);
      }
    }
  }
}

function collectAllPrerequisites(
  materiaCode: string,
  prerequisiteMap: Map<string, string[]>,
  collected: Set<string>
): void {
  const directPrereqs = prerequisiteMap.get(materiaCode) ?? [];
  
  for (const prereqCode of directPrereqs) {
    if (!collected.has(prereqCode)) {
      collected.add(prereqCode);
      collectAllPrerequisites(prereqCode, prerequisiteMap, collected);
    }
  }
}

// ============================================================================
// MinimalCursoModel Factory
// ============================================================================

export function createMinimalCursoModelFromJson(
  json: Record<string, unknown>
): MinimalCursoModel {
  return {
    nomeCurso: String(json.nome_curso ?? ''),
    matrizCurricular: String(json.matriz_curricular ?? ''),
    idCurso: Number(json.id_curso ?? 0),
    creditos: json.creditos != null ? Number(json.creditos) : null,
    tipoCurso: String(json.tipo_curso ?? 'outro'),
    classificacao: String(json.classificacao ?? 'outro'),
  };
}
```

---

## Directory Structure

After implementing all types, your directory structure should look like:

```
src/lib/
├── types/
│   ├── index.ts          # Re-exports all types
│   ├── user.ts           # User, DadosMateria, DadosFluxogramaUser
│   ├── curso.ts          # CursoModel, MinimalCursoModel, PreRequisitoModel, CoRequisitoModel
│   ├── materia.ts        # MateriaModel, SubjectStatus
│   ├── equivalencia.ts   # EquivalenciaModel, expression evaluation
│   ├── prerequisite-tree.ts  # PrerequisiteTree, traversal utilities
│   ├── api.ts            # ApiResponse, ApiError
│   └── guards.ts         # Type guards and assertion functions
├── schemas/
│   └── index.ts          # Zod schemas for runtime validation
└── factories/
    └── index.ts          # Factory functions for creating objects from JSON
```

### Main Index Export (`src/lib/types/index.ts`)

```typescript
// Re-export all types
export * from './user';
export * from './curso';
export * from './materia';
export * from './equivalencia';
export * from './prerequisite-tree';
export * from './api';
export * from './guards';
```

---

## Migration Checklist

- [x] Create `src/lib/types/` directory structure
- [x] Implement `user.ts` with UserModel, DadosMateria, DadosFluxogramaUser
- [x] Implement `curso.ts` with CursoModel, MinimalCursoModel, PreRequisitoModel, CoRequisitoModel
- [x] Implement `materia.ts` with MateriaModel and helper functions
- [x] Implement `equivalencia.ts` with EquivalenciaModel and expression evaluation
- [x] Implement `prerequisite-tree.ts` with tree building and traversal
- [x] Implement `api.ts` with API response types
- [x] Implement `guards.ts` with type guards
- [x] Install Zod: `npm install zod`
- [x] Implement `src/lib/schemas/index.ts` with Zod schemas
- [x] Implement `src/lib/factories/index.ts` with factory functions
- [x] Create `src/lib/types/index.ts` to re-export all types
- [x] Test type compilation with `npm run check`
- [x] Integrate with API services

---

## Key Differences from Flutter

1. **No Classes**: TypeScript uses interfaces instead of classes for data models
2. **Factory Functions**: Instead of factory constructors, use standalone factory functions
3. **No SharedPreferences Access**: Move SharedPreferences logic to stores/services
4. **Null Handling**: Use `null` and `undefined` explicitly with union types
5. **Method Placement**: Instance methods become standalone functions
6. **Immutability**: TypeScript interfaces are immutable by default; use `Readonly<T>` for explicit immutability
