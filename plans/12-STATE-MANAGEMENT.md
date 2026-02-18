# Plan 12: State Management Migration

## Overview

This document covers migrating state management from Flutter patterns to SvelteKit, converting SharedPreferences, StatefulWidget state, and static class properties to Svelte stores and runes.

### Flutter State Patterns Being Replaced

| Flutter Pattern | SvelteKit Equivalent |
|-----------------|---------------------|
| `SharedPreferences` | `localStorage` + Svelte stores |
| `StatefulWidget` + `setState()` | Component state (`let` / `$state`) |
| Static class properties | Module-level stores |
| `go_router` state | SvelteKit `$page` store |
| `ValueNotifier` | `writable` store |

---

## 1. Svelte Stores Overview

Svelte provides reactive stores as a first-class primitive for shared state.

### Store Types

```typescript
// src/lib/stores/example.ts
import { writable, readable, derived } from 'svelte/store';

// WRITABLE - Read/write store
export const count = writable(0);
// Usage: $count, count.set(5), count.update(n => n + 1)

// READABLE - Read-only store with external source
export const time = readable(new Date(), (set) => {
  const interval = setInterval(() => set(new Date()), 1000);
  return () => clearInterval(interval);
});

// DERIVED - Computed from other stores
export const doubled = derived(count, ($count) => $count * 2);

// DERIVED from multiple stores
export const combined = derived(
  [storeA, storeB],
  ([$a, $b]) => $a + $b
);
```

### Store Contract

Any object implementing this interface is a valid store:

```typescript
interface Readable<T> {
  subscribe(run: (value: T) => void): () => void;
}

interface Writable<T> extends Readable<T> {
  set(value: T): void;
  update(updater: (value: T) => T): void;
}
```

---

## 2. Auth Store

Replaces `SharedPreferencesHelper.currentUser` and `SharedPreferencesHelper.isAnonimo`.

### Flutter Original

```dart
// shared_preferences_helper.dart
class SharedPreferencesHelper {
  static UserModel? get currentUser {
    final userJson = _prefs?.getString(keyUser);
    if (userJson == null) return null;
    return UserModel.fromJson(jsonDecode(userJson));
  }
  
  static set currentUser(UserModel? user) {
    if (user != null) {
      _prefs?.setString(keyUser, jsonEncode(user.toJson()));
    } else {
      _prefs?.remove(keyUser);
    }
  }
  
  static bool get isAnonimo => _prefs?.getBool(keyAnonimo) ?? false;
}
```

### SvelteKit Implementation

```typescript
// src/lib/stores/auth.ts
import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';
import type { UserModel } from '$lib/types/user';

// ============================================================
// Types
// ============================================================

export interface AuthState {
  user: UserModel | null;
  isAuthenticated: boolean;
  isAnonymous: boolean;
  isLoading: boolean;
  error: string | null;
}

const STORAGE_KEY = 'nofluxo_user';
const ANON_KEY = 'nofluxo_anonimo';

// ============================================================
// Initial State
// ============================================================

function getInitialState(): AuthState {
  return {
    user: null,
    isAuthenticated: false,
    isAnonymous: false,
    isLoading: true,
    error: null
  };
}

// ============================================================
// Store Creation
// ============================================================

function createAuthStore() {
  const { subscribe, set, update } = writable<AuthState>(getInitialState());

  // Hydrate from localStorage on client
  function hydrate(): void {
    if (!browser) return;
    
    try {
      const storedUser = localStorage.getItem(STORAGE_KEY);
      const isAnon = localStorage.getItem(ANON_KEY) === 'true';
      
      if (storedUser && storedUser !== 'null') {
        const user = JSON.parse(storedUser) as UserModel;
        set({
          user,
          isAuthenticated: true,
          isAnonymous: isAnon,
          isLoading: false,
          error: null
        });
      } else {
        set({
          user: null,
          isAuthenticated: false,
          isAnonymous: isAnon,
          isLoading: false,
          error: null
        });
      }
    } catch (error) {
      console.error('Failed to hydrate auth state:', error);
      set({
        ...getInitialState(),
        isLoading: false,
        error: 'Failed to restore session'
      });
    }
  }

  return {
    subscribe,
    
    // Initialize on app start
    init: hydrate,
    
    // Set authenticated user
    setUser(user: UserModel): void {
      if (browser) {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(user));
        localStorage.setItem(ANON_KEY, 'false');
      }
      
      set({
        user,
        isAuthenticated: true,
        isAnonymous: false,
        isLoading: false,
        error: null
      });
    },
    
    // Set anonymous user
    setAnonymous(): void {
      if (browser) {
        localStorage.removeItem(STORAGE_KEY);
        localStorage.setItem(ANON_KEY, 'true');
      }
      
      set({
        user: null,
        isAuthenticated: false,
        isAnonymous: true,
        isLoading: false,
        error: null
      });
    },
    
    // Update user data (e.g., after profile changes)
    updateUser(updates: Partial<UserModel>): void {
      update(state => {
        if (!state.user) return state;
        
        const updatedUser = { ...state.user, ...updates };
        
        if (browser) {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(updatedUser));
        }
        
        return { ...state, user: updatedUser };
      });
    },
    
    // Update fluxograma data on user
    setFluxogramaData(dadosFluxograma: UserModel['dadosFluxograma']): void {
      update(state => {
        if (!state.user) return state;
        
        const updatedUser = { ...state.user, dadosFluxograma };
        
        if (browser) {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(updatedUser));
        }
        
        return { ...state, user: updatedUser };
      });
    },
    
    // Clear authentication
    logout(): void {
      if (browser) {
        localStorage.removeItem(STORAGE_KEY);
        localStorage.removeItem(ANON_KEY);
      }
      
      set({
        user: null,
        isAuthenticated: false,
        isAnonymous: false,
        isLoading: false,
        error: null
      });
    },
    
    // Set loading state
    setLoading(isLoading: boolean): void {
      update(state => ({ ...state, isLoading }));
    },
    
    // Set error
    setError(error: string | null): void {
      update(state => ({ ...state, error, isLoading: false }));
    },
    
    // Get current state synchronously
    getState(): AuthState {
      return get({ subscribe });
    }
  };
}

// ============================================================
// Export Store
// ============================================================

export const authStore = createAuthStore();

// ============================================================
// Derived Stores
// ============================================================

// Current user only
export const currentUser = derived(
  authStore,
  $auth => $auth.user
);

// Check if user has fluxograma data
export const hasFluxogramaData = derived(
  authStore,
  $auth => !!$auth.user?.dadosFluxograma
);

// Get user's course name
export const userCourseName = derived(
  authStore,
  $auth => $auth.user?.dadosFluxograma?.nomeCurso ?? null
);

// Check authentication status
export const isAuthenticated = derived(
  authStore,
  $auth => $auth.isAuthenticated
);

// Check if user can access protected routes
export const canAccessProtected = derived(
  authStore,
  $auth => $auth.isAuthenticated || $auth.isAnonymous
);
```

### Usage in Components

```svelte
<!-- src/routes/+layout.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore, currentUser, isAuthenticated } from '$lib/stores/auth';
  
  onMount(() => {
    authStore.init();
  });
</script>

{#if $isAuthenticated}
  <p>Welcome, {$currentUser?.nome}</p>
  <button on:click={() => authStore.logout()}>Logout</button>
{:else}
  <a href="/login">Login</a>
{/if}
```

---

## 3. User Store

Detailed user model with persistence.

### Types Definition

```typescript
// src/lib/types/user.ts

export interface DadosMateria {
  codigoMateria: string;
  mencao: string;
  professor: string;
  status: string;
  anoPeriodo?: string;
  frequencia?: string;
  tipoDado?: string;
  turma?: string;
}

export interface DadosFluxogramaUser {
  nomeCurso: string;
  ira: number;
  matricula: string;
  horasIntegralizadas: number;
  suspensoes: string[];
  anoAtual: string;
  matrizCurricular: string;
  semestreAtual: number;
  dadosFluxograma: DadosMateria[][];
}

export interface UserModel {
  id: number;
  nome: string;
  email: string;
  token?: string;
  dadosFluxograma?: DadosFluxogramaUser;
  createdAt?: string;
  updatedAt?: string;
}

// Helper functions matching Flutter model
export function isMateriaAprovada(materia: DadosMateria): boolean {
  return (
    materia.mencao === 'SS' ||
    materia.mencao === 'MM' ||
    materia.mencao === 'MS' ||
    ((materia.status === 'APR' || materia.status === 'CUMP') && materia.mencao !== '-')
  );
}

export function isMateriaCurrent(materia: DadosMateria): boolean {
  return materia.status === 'MATR';
}

export function isMateriaCursada(materia: DadosMateria): boolean {
  return materia.status === 'APR' || materia.status === 'CUMP';
}
```

### User Store with Computed Properties

```typescript
// src/lib/stores/user.ts
import { derived } from 'svelte/store';
import { authStore } from './auth';
import type { DadosMateria } from '$lib/types/user';
import { isMateriaAprovada, isMateriaCurrent } from '$lib/types/user';

// ============================================================
// Derived User Data Stores
// ============================================================

// All materias flattened
export const allMaterias = derived(
  authStore,
  $auth => {
    if (!$auth.user?.dadosFluxograma?.dadosFluxograma) return [];
    return $auth.user.dadosFluxograma.dadosFluxograma.flat();
  }
);

// Approved materias
export const approvedMaterias = derived(
  allMaterias,
  $materias => $materias.filter(isMateriaAprovada)
);

// Current (enrolled) materias
export const currentMaterias = derived(
  allMaterias,
  $materias => $materias.filter(isMateriaCurrent)
);

// Credits completed count
export const completedCreditsCount = derived(
  approvedMaterias,
  $approved => $approved.length
);

// User IRA
export const userIRA = derived(
  authStore,
  $auth => $auth.user?.dadosFluxograma?.ira ?? 0
);

// Current semester
export const currentSemester = derived(
  authStore,
  $auth => $auth.user?.dadosFluxograma?.semestreAtual ?? 1
);

// Materias by semester
export const materiasBySemester = derived(
  authStore,
  $auth => {
    if (!$auth.user?.dadosFluxograma?.dadosFluxograma) return [];
    return $auth.user.dadosFluxograma.dadosFluxograma;
  }
);

// Materias map by code
export const materiasByCode = derived(
  allMaterias,
  $materias => {
    const map = new Map<string, DadosMateria>();
    for (const materia of $materias) {
      map.set(materia.codigoMateria, materia);
    }
    return map;
  }
);
```

---

## 4. Fluxograma Store

Manages course data, selected subjects, and UI state for the fluxograma screen.

### Flutter Original State

```dart
// meu_fluxograma_screen.dart
class _MeuFluxogramaScreenState extends State<MeuFluxogramaScreen> {
  double zoomLevel = 1.0;
  bool showPrereqChains = false;
  bool showConnections = false;
  CursoModel? currentCourseData;
  List<CursoModel> matrizesCurriculares = [];
  PrerequisiteTree? prerequisiteTree;
  bool isAnonymous = false;
  bool loading = false;
  String? errorMessage;
  List<OptativaAdicionada> optativasAdicionadas = [];
}
```

### SvelteKit Implementation

```typescript
// src/lib/stores/fluxograma.ts
import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';
import type { CursoModel, MateriaModel, PrerequisiteTree } from '$lib/types/curso';

// ============================================================
// Types
// ============================================================

export interface OptativaAdicionada {
  materia: MateriaModel;
  semestre: number;
}

export interface FluxogramaState {
  // Data
  currentCourseData: CursoModel | null;
  matrizesCurriculares: CursoModel[];
  prerequisiteTree: PrerequisiteTree | null;
  
  // UI State
  zoomLevel: number;
  showPrereqChains: boolean;
  showConnections: boolean;
  showOptativasModal: boolean;
  
  // Optativas
  optativasAdicionadas: OptativaAdicionada[];
  
  // Loading/Error
  loading: boolean;
  errorMessage: string | null;
  
  // Selection
  selectedMateria: MateriaModel | null;
  hoveredMateria: MateriaModel | null;
}

const ZOOM_STORAGE_KEY = 'nofluxo_zoom_level';
const MIN_ZOOM = 0.5;
const MAX_ZOOM = 2.0;
const ZOOM_STEP = 0.1;

// ============================================================
// Initial State
// ============================================================

function getInitialState(): FluxogramaState {
  return {
    currentCourseData: null,
    matrizesCurriculares: [],
    prerequisiteTree: null,
    zoomLevel: browser ? parseFloat(localStorage.getItem(ZOOM_STORAGE_KEY) ?? '1.0') : 1.0,
    showPrereqChains: false,
    showConnections: false,
    showOptativasModal: false,
    optativasAdicionadas: [],
    loading: false,
    errorMessage: null,
    selectedMateria: null,
    hoveredMateria: null
  };
}

// ============================================================
// Store Creation
// ============================================================

function createFluxogramaStore() {
  const { subscribe, set, update } = writable<FluxogramaState>(getInitialState());

  return {
    subscribe,
    
    // ======== Data Loading ========
    
    setLoading(loading: boolean): void {
      update(state => ({ ...state, loading, errorMessage: null }));
    },
    
    setError(errorMessage: string): void {
      update(state => ({ ...state, errorMessage, loading: false }));
    },
    
    setCourseData(courseData: CursoModel, matrices: CursoModel[]): void {
      update(state => ({
        ...state,
        currentCourseData: courseData,
        matrizesCurriculares: matrices,
        loading: false,
        errorMessage: null
      }));
    },
    
    setPrerequisiteTree(tree: PrerequisiteTree): void {
      update(state => ({ ...state, prerequisiteTree: tree }));
    },
    
    selectMatrix(matrizCurricular: string): void {
      update(state => {
        const newCourse = state.matrizesCurriculares.find(
          c => c.matrizCurricular === matrizCurricular
        );
        return newCourse 
          ? { ...state, currentCourseData: newCourse }
          : state;
      });
    },
    
    // ======== Zoom Controls ========
    
    setZoom(level: number): void {
      const clampedLevel = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, level));
      
      if (browser) {
        localStorage.setItem(ZOOM_STORAGE_KEY, clampedLevel.toString());
      }
      
      update(state => ({ ...state, zoomLevel: clampedLevel }));
    },
    
    zoomIn(): void {
      update(state => {
        const newLevel = Math.min(MAX_ZOOM, state.zoomLevel + ZOOM_STEP);
        
        if (browser) {
          localStorage.setItem(ZOOM_STORAGE_KEY, newLevel.toString());
        }
        
        return { ...state, zoomLevel: newLevel };
      });
    },
    
    zoomOut(): void {
      update(state => {
        const newLevel = Math.max(MIN_ZOOM, state.zoomLevel - ZOOM_STEP);
        
        if (browser) {
          localStorage.setItem(ZOOM_STORAGE_KEY, newLevel.toString());
        }
        
        return { ...state, zoomLevel: newLevel };
      });
    },
    
    resetZoom(): void {
      if (browser) {
        localStorage.setItem(ZOOM_STORAGE_KEY, '1.0');
      }
      update(state => ({ ...state, zoomLevel: 1.0 }));
    },
    
    // ======== Toggle Controls ========
    
    togglePrereqChains(): void {
      update(state => ({ ...state, showPrereqChains: !state.showPrereqChains }));
    },
    
    toggleConnections(): void {
      update(state => ({ ...state, showConnections: !state.showConnections }));
    },
    
    toggleOptativasModal(): void {
      update(state => ({ ...state, showOptativasModal: !state.showOptativasModal }));
    },
    
    setShowOptativasModal(show: boolean): void {
      update(state => ({ ...state, showOptativasModal: show }));
    },
    
    // ======== Optativas ========
    
    addOptativa(materia: MateriaModel, semestre: number): void {
      update(state => ({
        ...state,
        optativasAdicionadas: [
          ...state.optativasAdicionadas,
          { materia, semestre }
        ]
      }));
    },
    
    removeOptativa(codigoMateria: string): void {
      update(state => ({
        ...state,
        optativasAdicionadas: state.optativasAdicionadas.filter(
          opt => opt.materia.codigoMateria !== codigoMateria
        )
      }));
    },
    
    clearOptativas(): void {
      update(state => ({ ...state, optativasAdicionadas: [] }));
    },
    
    // ======== Selection ========
    
    selectMateria(materia: MateriaModel | null): void {
      update(state => ({ ...state, selectedMateria: materia }));
    },
    
    hoverMateria(materia: MateriaModel | null): void {
      update(state => ({ ...state, hoveredMateria: materia }));
    },
    
    // ======== Reset ========
    
    reset(): void {
      const zoomLevel = get({ subscribe }).zoomLevel; // Preserve zoom
      set({ ...getInitialState(), zoomLevel });
    },
    
    // ======== Getters ========
    
    getState(): FluxogramaState {
      return get({ subscribe });
    }
  };
}

// ============================================================
// Export Store
// ============================================================

export const fluxogramaStore = createFluxogramaStore();

// ============================================================
// Derived Stores
// ============================================================

// Current course materias
export const courseMaterias = derived(
  fluxogramaStore,
  $store => $store.currentCourseData?.materias ?? []
);

// Materias organized by semester
export const materiasBySemester = derived(
  fluxogramaStore,
  $store => {
    if (!$store.currentCourseData) return new Map<number, MateriaModel[]>();
    
    const map = new Map<number, MateriaModel[]>();
    for (const materia of $store.currentCourseData.materias) {
      const semester = materia.semestre;
      if (!map.has(semester)) {
        map.set(semester, []);
      }
      map.get(semester)!.push(materia);
    }
    return map;
  }
);

// Completed materias in current course
export const completedMaterias = derived(
  courseMaterias,
  $materias => $materias.filter(m => m.status === 'completed')
);

// Current (enrolled) materias in current course
export const enrolledMaterias = derived(
  courseMaterias,
  $materias => $materias.filter(m => m.status === 'current')
);

// Progress percentage
export const progressPercentage = derived(
  [courseMaterias, completedMaterias],
  ([$all, $completed]) => {
    if ($all.length === 0) return 0;
    return Math.round(($completed.length / $all.length) * 100);
  }
);

// Zoom as percentage (for display)
export const zoomPercentage = derived(
  fluxogramaStore,
  $store => Math.round($store.zoomLevel * 100)
);

// Is loading or has error
export const fluxogramaStatus = derived(
  fluxogramaStore,
  $store => ({
    loading: $store.loading,
    error: $store.errorMessage,
    hasData: $store.currentCourseData !== null
  })
);
```

### Usage in Fluxograma Page

```svelte
<!-- src/routes/meu-fluxograma/+page.svelte -->
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { 
    fluxogramaStore, 
    courseMaterias, 
    progressPercentage,
    zoomPercentage 
  } from '$lib/stores/fluxograma';
  import { authStore } from '$lib/stores/auth';
  import { goto } from '$app/navigation';
  import { fluxogramaService } from '$lib/services/fluxograma';
  
  export let data; // From +page.ts load function
  
  onMount(async () => {
    const courseName = data.courseName ?? $authStore.user?.dadosFluxograma?.nomeCurso;
    
    if (!courseName) {
      goto('/upload-historico');
      return;
    }
    
    fluxogramaStore.setLoading(true);
    
    try {
      const result = await fluxogramaService.getCourseData(courseName);
      
      if (result.error) {
        fluxogramaStore.setError(result.error);
      } else {
        fluxogramaStore.setCourseData(result.course!, result.matrices!);
      }
    } catch (error) {
      fluxogramaStore.setError('Failed to load course data');
    }
  });
  
  onDestroy(() => {
    // Optionally reset store state
    // fluxogramaStore.reset();
  });
</script>

<div class="fluxograma-container">
  <!-- Zoom Controls -->
  <div class="controls">
    <button on:click={() => fluxogramaStore.zoomOut()}>-</button>
    <span>{$zoomPercentage}%</span>
    <button on:click={() => fluxogramaStore.zoomIn()}>+</button>
    <button on:click={() => fluxogramaStore.resetZoom()}>Reset</button>
  </div>
  
  <!-- Toggle Controls -->
  <div class="toggles">
    <label>
      <input 
        type="checkbox" 
        checked={$fluxogramaStore.showPrereqChains}
        on:change={() => fluxogramaStore.togglePrereqChains()}
      />
      Show Prerequisites
    </label>
    
    <label>
      <input 
        type="checkbox" 
        checked={$fluxogramaStore.showConnections}
        on:change={() => fluxogramaStore.toggleConnections()}
      />
      Show Connections
    </label>
  </div>
  
  <!-- Progress -->
  <div class="progress">
    <span>Progress: {$progressPercentage}%</span>
  </div>
  
  <!-- Fluxogram Grid -->
  <div 
    class="fluxogram"
    style="transform: scale({$fluxogramaStore.zoomLevel})"
  >
    {#each $courseMaterias as materia (materia.codigoMateria)}
      <MateriaCard 
        {materia}
        selected={$fluxogramaStore.selectedMateria?.codigoMateria === materia.codigoMateria}
        on:click={() => fluxogramaStore.selectMateria(materia)}
        on:mouseenter={() => fluxogramaStore.hoverMateria(materia)}
        on:mouseleave={() => fluxogramaStore.hoverMateria(null)}
      />
    {/each}
  </div>
</div>
```

---

## 5. Chat Store

Manages assistant chat state and message history.

```typescript
// src/lib/stores/chat.ts
import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';

// ============================================================
// Types
// ============================================================

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
  isStreaming?: boolean;
}

export interface ChatState {
  messages: ChatMessage[];
  isLoading: boolean;
  isStreaming: boolean;
  error: string | null;
  sessionId: string | null;
}

const STORAGE_KEY = 'nofluxo_chat_history';
const MAX_STORED_MESSAGES = 50;

// ============================================================
// Helpers
// ============================================================

function generateId(): string {
  return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

function getInitialState(): ChatState {
  return {
    messages: [],
    isLoading: false,
    isStreaming: false,
    error: null,
    sessionId: null
  };
}

// ============================================================
// Store Creation
// ============================================================

function createChatStore() {
  const { subscribe, set, update } = writable<ChatState>(getInitialState());

  // Persist messages to localStorage
  function persistMessages(messages: ChatMessage[]): void {
    if (!browser) return;
    
    const toStore = messages.slice(-MAX_STORED_MESSAGES).map(m => ({
      ...m,
      timestamp: m.timestamp.toISOString()
    }));
    
    localStorage.setItem(STORAGE_KEY, JSON.stringify(toStore));
  }

  // Hydrate from localStorage
  function hydrate(): void {
    if (!browser) return;
    
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        const messages = parsed.map((m: any) => ({
          ...m,
          timestamp: new Date(m.timestamp),
          isStreaming: false
        }));
        
        update(state => ({ ...state, messages }));
      }
    } catch (error) {
      console.error('Failed to hydrate chat history:', error);
    }
  }

  return {
    subscribe,
    
    // Initialize
    init: hydrate,
    
    // Start new session
    startSession(sessionId: string): void {
      update(state => ({ ...state, sessionId }));
    },
    
    // Add user message
    addUserMessage(content: string): string {
      const message: ChatMessage = {
        id: generateId(),
        role: 'user',
        content,
        timestamp: new Date()
      };
      
      update(state => {
        const messages = [...state.messages, message];
        persistMessages(messages);
        return { ...state, messages };
      });
      
      return message.id;
    },
    
    // Add assistant message (for streaming)
    addAssistantMessage(content: string = ''): string {
      const message: ChatMessage = {
        id: generateId(),
        role: 'assistant',
        content,
        timestamp: new Date(),
        isStreaming: true
      };
      
      update(state => ({
        ...state,
        messages: [...state.messages, message],
        isStreaming: true
      }));
      
      return message.id;
    },
    
    // Update streaming message
    updateStreamingMessage(messageId: string, content: string): void {
      update(state => ({
        ...state,
        messages: state.messages.map(m =>
          m.id === messageId ? { ...m, content } : m
        )
      }));
    },
    
    // Append to streaming message
    appendToStreamingMessage(messageId: string, chunk: string): void {
      update(state => ({
        ...state,
        messages: state.messages.map(m =>
          m.id === messageId ? { ...m, content: m.content + chunk } : m
        )
      }));
    },
    
    // Complete streaming
    completeStreaming(messageId: string): void {
      update(state => {
        const messages = state.messages.map(m =>
          m.id === messageId ? { ...m, isStreaming: false } : m
        );
        persistMessages(messages);
        return { ...state, messages, isStreaming: false };
      });
    },
    
    // Add complete assistant message
    addCompleteAssistantMessage(content: string): void {
      const message: ChatMessage = {
        id: generateId(),
        role: 'assistant',
        content,
        timestamp: new Date(),
        isStreaming: false
      };
      
      update(state => {
        const messages = [...state.messages, message];
        persistMessages(messages);
        return { ...state, messages };
      });
    },
    
    // Set loading state
    setLoading(isLoading: boolean): void {
      update(state => ({ ...state, isLoading }));
    },
    
    // Set error
    setError(error: string | null): void {
      update(state => ({ ...state, error, isLoading: false, isStreaming: false }));
    },
    
    // Clear error
    clearError(): void {
      update(state => ({ ...state, error: null }));
    },
    
    // Clear all messages
    clearHistory(): void {
      if (browser) {
        localStorage.removeItem(STORAGE_KEY);
      }
      set(getInitialState());
    },
    
    // Remove specific message
    removeMessage(messageId: string): void {
      update(state => {
        const messages = state.messages.filter(m => m.id !== messageId);
        persistMessages(messages);
        return { ...state, messages };
      });
    },
    
    // Get state
    getState(): ChatState {
      return get({ subscribe });
    }
  };
}

// ============================================================
// Export Store
// ============================================================

export const chatStore = createChatStore();

// ============================================================
// Derived Stores
// ============================================================

// Messages only
export const chatMessages = derived(
  chatStore,
  $chat => $chat.messages
);

// Latest message
export const latestMessage = derived(
  chatStore,
  $chat => $chat.messages[$chat.messages.length - 1] ?? null
);

// Is chat busy
export const isChatBusy = derived(
  chatStore,
  $chat => $chat.isLoading || $chat.isStreaming
);

// Message count
export const messageCount = derived(
  chatStore,
  $chat => $chat.messages.length
);

// Has messages
export const hasMessages = derived(
  chatStore,
  $chat => $chat.messages.length > 0
);
```

### Usage in Chat Component

```svelte
<!-- src/routes/assistente/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { chatStore, chatMessages, isChatBusy } from '$lib/stores/chat';
  import { assistantService } from '$lib/services/assistant';
  
  let inputMessage = '';
  let messagesContainer: HTMLDivElement;
  
  onMount(() => {
    chatStore.init();
  });
  
  async function sendMessage() {
    if (!inputMessage.trim() || $isChatBusy) return;
    
    const userMsg = inputMessage.trim();
    inputMessage = '';
    
    // Add user message
    chatStore.addUserMessage(userMsg);
    chatStore.setLoading(true);
    
    try {
      // Create placeholder for assistant response
      const assistantMsgId = chatStore.addAssistantMessage();
      
      // Stream response
      await assistantService.streamMessage(userMsg, (chunk) => {
        chatStore.appendToStreamingMessage(assistantMsgId, chunk);
        scrollToBottom();
      });
      
      chatStore.completeStreaming(assistantMsgId);
    } catch (error) {
      chatStore.setError('Failed to get response');
    } finally {
      chatStore.setLoading(false);
    }
  }
  
  function scrollToBottom() {
    messagesContainer?.scrollTo({
      top: messagesContainer.scrollHeight,
      behavior: 'smooth'
    });
  }
  
  $: if ($chatMessages.length) {
    setTimeout(scrollToBottom, 100);
  }
</script>

<div class="chat-container">
  <div class="messages" bind:this={messagesContainer}>
    {#each $chatMessages as message (message.id)}
      <div class="message {message.role}">
        <p>{message.content}</p>
        {#if message.isStreaming}
          <span class="typing-indicator">●●●</span>
        {/if}
      </div>
    {/each}
    
    {#if $isChatBusy && $chatMessages[$chatMessages.length - 1]?.role !== 'assistant'}
      <div class="loading">Processing...</div>
    {/if}
  </div>
  
  <form on:submit|preventDefault={sendMessage} class="input-area">
    <input
      type="text"
      bind:value={inputMessage}
      placeholder="Type your message..."
      disabled={$isChatBusy}
    />
    <button type="submit" disabled={$isChatBusy || !inputMessage.trim()}>
      Send
    </button>
  </form>
  
  <button on:click={() => chatStore.clearHistory()}>
    Clear History
  </button>
</div>
```

---

## 6. Upload Store

Manages PDF upload progress and extracted data.

```typescript
// src/lib/stores/upload.ts
import { writable, derived, get } from 'svelte/store';

// ============================================================
// Types
// ============================================================

export type UploadStatus = 'idle' | 'selecting' | 'uploading' | 'processing' | 'success' | 'error';

export interface ExtractedData {
  nomeCurso: string;
  matrizCurricular: string;
  ira: number;
  matricula: string;
  semestreAtual: number;
  anoAtual: string;
  horasIntegralizadas: number;
  dadosFluxograma: any[][];
  suspensoes: string[];
}

export interface UploadState {
  status: UploadStatus;
  progress: number; // 0-100
  fileName: string | null;
  fileSize: number | null;
  extractedData: ExtractedData | null;
  error: string | null;
  validationErrors: string[];
}

// ============================================================
// Store
// ============================================================

function getInitialState(): UploadState {
  return {
    status: 'idle',
    progress: 0,
    fileName: null,
    fileSize: null,
    extractedData: null,
    error: null,
    validationErrors: []
  };
}

function createUploadStore() {
  const { subscribe, set, update } = writable<UploadState>(getInitialState());

  return {
    subscribe,
    
    // Start file selection
    startSelection(): void {
      update(state => ({
        ...state,
        status: 'selecting',
        error: null,
        validationErrors: []
      }));
    },
    
    // Set selected file
    setFile(file: File): void {
      update(state => ({
        ...state,
        fileName: file.name,
        fileSize: file.size,
        status: 'selecting'
      }));
    },
    
    // Start upload
    startUpload(): void {
      update(state => ({
        ...state,
        status: 'uploading',
        progress: 0,
        error: null
      }));
    },
    
    // Update progress
    setProgress(progress: number): void {
      update(state => ({
        ...state,
        progress: Math.min(100, Math.max(0, progress)),
        status: progress >= 100 ? 'processing' : 'uploading'
      }));
    },
    
    // Start processing
    startProcessing(): void {
      update(state => ({
        ...state,
        status: 'processing',
        progress: 100
      }));
    },
    
    // Set extracted data
    setExtractedData(data: ExtractedData): void {
      update(state => ({
        ...state,
        extractedData: data,
        status: 'success',
        error: null
      }));
    },
    
    // Set validation errors (warnings that don't block)
    setValidationErrors(errors: string[]): void {
      update(state => ({
        ...state,
        validationErrors: errors
      }));
    },
    
    // Set error
    setError(error: string): void {
      update(state => ({
        ...state,
        status: 'error',
        error,
        progress: 0
      }));
    },
    
    // Reset store
    reset(): void {
      set(getInitialState());
    },
    
    // Clear file and keep extracted data
    clearFile(): void {
      update(state => ({
        ...state,
        fileName: null,
        fileSize: null,
        status: state.extractedData ? 'success' : 'idle',
        progress: 0
      }));
    },
    
    // Get current state
    getState(): UploadState {
      return get({ subscribe });
    }
  };
}

// ============================================================
// Export
// ============================================================

export const uploadStore = createUploadStore();

// ============================================================
// Derived Stores
// ============================================================

// Is busy (uploading or processing)
export const isUploading = derived(
  uploadStore,
  $store => $store.status === 'uploading' || $store.status === 'processing'
);

// Has extracted data
export const hasExtractedData = derived(
  uploadStore,
  $store => $store.extractedData !== null
);

// Upload complete
export const uploadComplete = derived(
  uploadStore,
  $store => $store.status === 'success'
);

// File info
export const fileInfo = derived(
  uploadStore,
  $store => ({
    name: $store.fileName,
    size: $store.fileSize,
    sizeFormatted: $store.fileSize 
      ? `${($store.fileSize / 1024).toFixed(1)} KB`
      : null
  })
);

// Progress as percentage string
export const progressText = derived(
  uploadStore,
  $store => {
    switch ($store.status) {
      case 'uploading':
        return `Uploading: ${$store.progress}%`;
      case 'processing':
        return 'Processing PDF...';
      case 'success':
        return 'Complete!';
      case 'error':
        return 'Error';
      default:
        return 'Ready';
    }
  }
);
```

### Usage in Upload Component

```svelte
<!-- src/routes/upload-historico/+page.svelte -->
<script lang="ts">
  import { 
    uploadStore, 
    isUploading, 
    hasExtractedData,
    fileInfo,
    progressText 
  } from '$lib/stores/upload';
  import { authStore } from '$lib/stores/auth';
  import { uploadService } from '$lib/services/upload';
  import { goto } from '$app/navigation';
  
  let fileInput: HTMLInputElement;
  
  function selectFile() {
    fileInput?.click();
  }
  
  async function handleFileSelect(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    
    if (!file) return;
    
    // Validate file type
    if (file.type !== 'application/pdf') {
      uploadStore.setError('Please select a PDF file');
      return;
    }
    
    uploadStore.setFile(file);
    
    // Auto-start upload
    await uploadFile(file);
  }
  
  async function uploadFile(file: File) {
    uploadStore.startUpload();
    
    try {
      const result = await uploadService.uploadHistorico(
        file,
        (progress) => uploadStore.setProgress(progress)
      );
      
      if (result.error) {
        uploadStore.setError(result.error);
        return;
      }
      
      uploadStore.setExtractedData(result.data!);
      
      // Update user with extracted data
      authStore.setFluxogramaData(result.data!);
      
    } catch (error) {
      uploadStore.setError('Upload failed. Please try again.');
    }
  }
  
  function proceedToFluxograma() {
    goto('/meu-fluxograma');
  }
  
  function uploadAnother() {
    uploadStore.reset();
  }
</script>

<div class="upload-container">
  <input
    type="file"
    accept=".pdf"
    bind:this={fileInput}
    on:change={handleFileSelect}
    hidden
  />
  
  {#if $uploadStore.status === 'idle' || $uploadStore.status === 'selecting'}
    <div class="dropzone" on:click={selectFile}>
      <p>Click or drop PDF here</p>
      {#if $fileInfo.name}
        <p class="file-name">{$fileInfo.name} ({$fileInfo.sizeFormatted})</p>
      {/if}
    </div>
  {/if}
  
  {#if $isUploading}
    <div class="progress">
      <div class="progress-bar" style="width: {$uploadStore.progress}%"></div>
      <p>{$progressText}</p>
    </div>
  {/if}
  
  {#if $uploadStore.status === 'error'}
    <div class="error">
      <p>{$uploadStore.error}</p>
      <button on:click={uploadAnother}>Try Again</button>
    </div>
  {/if}
  
  {#if $hasExtractedData}
    <div class="success">
      <h3>Data Extracted Successfully!</h3>
      <p>Course: {$uploadStore.extractedData?.nomeCurso}</p>
      <p>IRA: {$uploadStore.extractedData?.ira}</p>
      <p>Semester: {$uploadStore.extractedData?.semestreAtual}</p>
      
      <div class="actions">
        <button on:click={proceedToFluxograma}>View Fluxograma</button>
        <button on:click={uploadAnother}>Upload Different File</button>
      </div>
    </div>
  {/if}
</div>
```

---

## 7. UI Store

Manages global UI state like modals, toasts, and loading.

```typescript
// src/lib/stores/ui.ts
import { writable, derived, get } from 'svelte/store';

// ============================================================
// Types
// ============================================================

export type ToastType = 'success' | 'error' | 'warning' | 'info';

export interface Toast {
  id: string;
  type: ToastType;
  message: string;
  duration: number;
  dismissible: boolean;
}

export interface ModalConfig {
  id: string;
  component: any;
  props?: Record<string, any>;
  closable?: boolean;
  onClose?: () => void;
}

export interface UIState {
  // Global loading
  isLoading: boolean;
  loadingMessage: string | null;
  
  // Toasts
  toasts: Toast[];
  
  // Modals
  modals: ModalConfig[];
  
  // Sidebar
  sidebarOpen: boolean;
  sidebarCollapsed: boolean;
  
  // Theme
  theme: 'light' | 'dark' | 'system';
  
  // Mobile menu
  mobileMenuOpen: boolean;
}

// ============================================================
// Initial State
// ============================================================

function getInitialState(): UIState {
  return {
    isLoading: false,
    loadingMessage: null,
    toasts: [],
    modals: [],
    sidebarOpen: true,
    sidebarCollapsed: false,
    theme: 'system',
    mobileMenuOpen: false
  };
}

// ============================================================
// Store Creation
// ============================================================

function createUIStore() {
  const { subscribe, set, update } = writable<UIState>(getInitialState());
  
  let toastCounter = 0;
  const toastTimeouts = new Map<string, ReturnType<typeof setTimeout>>();

  return {
    subscribe,
    
    // ======== Loading ========
    
    setLoading(isLoading: boolean, message?: string): void {
      update(state => ({
        ...state,
        isLoading,
        loadingMessage: message ?? null
      }));
    },
    
    showLoading(message?: string): void {
      update(state => ({
        ...state,
        isLoading: true,
        loadingMessage: message ?? null
      }));
    },
    
    hideLoading(): void {
      update(state => ({
        ...state,
        isLoading: false,
        loadingMessage: null
      }));
    },
    
    // ======== Toasts ========
    
    showToast(
      message: string,
      type: ToastType = 'info',
      options?: { duration?: number; dismissible?: boolean }
    ): string {
      const id = `toast_${++toastCounter}`;
      const duration = options?.duration ?? 5000;
      const dismissible = options?.dismissible ?? true;
      
      const toast: Toast = { id, type, message, duration, dismissible };
      
      update(state => ({
        ...state,
        toasts: [...state.toasts, toast]
      }));
      
      // Auto-dismiss
      if (duration > 0) {
        const timeout = setTimeout(() => {
          this.dismissToast(id);
        }, duration);
        toastTimeouts.set(id, timeout);
      }
      
      return id;
    },
    
    success(message: string, options?: { duration?: number }): string {
      return this.showToast(message, 'success', options);
    },
    
    error(message: string, options?: { duration?: number }): string {
      return this.showToast(message, 'error', { duration: 8000, ...options });
    },
    
    warning(message: string, options?: { duration?: number }): string {
      return this.showToast(message, 'warning', options);
    },
    
    info(message: string, options?: { duration?: number }): string {
      return this.showToast(message, 'info', options);
    },
    
    dismissToast(id: string): void {
      const timeout = toastTimeouts.get(id);
      if (timeout) {
        clearTimeout(timeout);
        toastTimeouts.delete(id);
      }
      
      update(state => ({
        ...state,
        toasts: state.toasts.filter(t => t.id !== id)
      }));
    },
    
    clearAllToasts(): void {
      toastTimeouts.forEach(timeout => clearTimeout(timeout));
      toastTimeouts.clear();
      
      update(state => ({ ...state, toasts: [] }));
    },
    
    // ======== Modals ========
    
    openModal(config: Omit<ModalConfig, 'id'> & { id?: string }): string {
      const id = config.id ?? `modal_${Date.now()}`;
      const modal: ModalConfig = {
        ...config,
        id,
        closable: config.closable ?? true
      };
      
      update(state => ({
        ...state,
        modals: [...state.modals, modal]
      }));
      
      return id;
    },
    
    closeModal(id?: string): void {
      update(state => {
        const modalToClose = id 
          ? state.modals.find(m => m.id === id)
          : state.modals[state.modals.length - 1];
        
        modalToClose?.onClose?.();
        
        return {
          ...state,
          modals: id 
            ? state.modals.filter(m => m.id !== id)
            : state.modals.slice(0, -1)
        };
      });
    },
    
    closeAllModals(): void {
      update(state => {
        state.modals.forEach(m => m.onClose?.());
        return { ...state, modals: [] };
      });
    },
    
    // ======== Sidebar ========
    
    toggleSidebar(): void {
      update(state => ({ ...state, sidebarOpen: !state.sidebarOpen }));
    },
    
    setSidebarOpen(open: boolean): void {
      update(state => ({ ...state, sidebarOpen: open }));
    },
    
    toggleSidebarCollapse(): void {
      update(state => ({ ...state, sidebarCollapsed: !state.sidebarCollapsed }));
    },
    
    // ======== Mobile Menu ========
    
    toggleMobileMenu(): void {
      update(state => ({ ...state, mobileMenuOpen: !state.mobileMenuOpen }));
    },
    
    closeMobileMenu(): void {
      update(state => ({ ...state, mobileMenuOpen: false }));
    },
    
    // ======== Theme ========
    
    setTheme(theme: 'light' | 'dark' | 'system'): void {
      update(state => ({ ...state, theme }));
      
      // Persist to localStorage
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem('nofluxo_theme', theme);
      }
    },
    
    // ======== Reset ========
    
    reset(): void {
      toastTimeouts.forEach(timeout => clearTimeout(timeout));
      toastTimeouts.clear();
      set(getInitialState());
    }
  };
}

// ============================================================
// Export
// ============================================================

export const uiStore = createUIStore();

// ============================================================
// Derived Stores
// ============================================================

// Active toasts
export const activeToasts = derived(
  uiStore,
  $ui => $ui.toasts
);

// Has any modal open
export const hasOpenModal = derived(
  uiStore,
  $ui => $ui.modals.length > 0
);

// Top modal
export const topModal = derived(
  uiStore,
  $ui => $ui.modals[$ui.modals.length - 1] ?? null
);

// Is loading
export const isGlobalLoading = derived(
  uiStore,
  $ui => $ui.isLoading
);

// Current theme
export const currentTheme = derived(
  uiStore,
  $ui => $ui.theme
);
```

### Toast Component

```svelte
<!-- src/lib/components/Toast.svelte -->
<script lang="ts">
  import { activeToasts, uiStore } from '$lib/stores/ui';
  import { fly } from 'svelte/transition';
  
  const iconMap = {
    success: '✓',
    error: '✕',
    warning: '⚠',
    info: 'ℹ'
  };
</script>

<div class="toast-container" aria-live="polite">
  {#each $activeToasts as toast (toast.id)}
    <div 
      class="toast toast-{toast.type}"
      transition:fly={{ y: -20, duration: 200 }}
      role="alert"
    >
      <span class="toast-icon">{iconMap[toast.type]}</span>
      <span class="toast-message">{toast.message}</span>
      {#if toast.dismissible}
        <button 
          class="toast-close"
          on:click={() => uiStore.dismissToast(toast.id)}
          aria-label="Dismiss"
        >
          ✕
        </button>
      {/if}
    </div>
  {/each}
</div>

<style>
  .toast-container {
    position: fixed;
    top: 1rem;
    right: 1rem;
    z-index: 9999;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  
  .toast {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 1rem 1.25rem;
    border-radius: 0.5rem;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    min-width: 300px;
    max-width: 500px;
  }
  
  .toast-success { background: #10b981; color: white; }
  .toast-error { background: #ef4444; color: white; }
  .toast-warning { background: #f59e0b; color: white; }
  .toast-info { background: #3b82f6; color: white; }
  
  .toast-close {
    margin-left: auto;
    background: transparent;
    border: none;
    color: inherit;
    cursor: pointer;
    opacity: 0.7;
  }
  
  .toast-close:hover {
    opacity: 1;
  }
</style>
```

---

## 8. Persistence Patterns

### Creating a Persisted Store

```typescript
// src/lib/stores/persisted.ts
import { writable, type Writable } from 'svelte/store';
import { browser } from '$app/environment';

interface PersistedStoreOptions<T> {
  key: string;
  initialValue: T;
  serialize?: (value: T) => string;
  deserialize?: (value: string) => T;
}

export function createPersistedStore<T>({
  key,
  initialValue,
  serialize = JSON.stringify,
  deserialize = JSON.parse
}: PersistedStoreOptions<T>): Writable<T> {
  // Get initial value from localStorage or use default
  const storedValue = browser ? localStorage.getItem(key) : null;
  
  let initial: T;
  if (storedValue !== null) {
    try {
      initial = deserialize(storedValue);
    } catch {
      initial = initialValue;
    }
  } else {
    initial = initialValue;
  }
  
  const store = writable<T>(initial);
  
  // Subscribe to changes and persist
  if (browser) {
    store.subscribe(value => {
      if (value === null || value === undefined) {
        localStorage.removeItem(key);
      } else {
        localStorage.setItem(key, serialize(value));
      }
    });
  }
  
  return store;
}

// ============================================================
// Usage Examples
// ============================================================

// Simple persisted value
export const persistedZoom = createPersistedStore({
  key: 'nofluxo_zoom',
  initialValue: 1.0
});

// Persisted object
export const persistedSettings = createPersistedStore({
  key: 'nofluxo_settings',
  initialValue: {
    showNotifications: true,
    language: 'pt-BR',
    darkMode: false
  }
});

// Persisted array
export const persistedFavorites = createPersistedStore<string[]>({
  key: 'nofluxo_favorites',
  initialValue: []
});
```

### Safe localStorage Wrapper

```typescript
// src/lib/utils/storage.ts
import { browser } from '$app/environment';

export const storage = {
  get<T>(key: string, defaultValue: T): T {
    if (!browser) return defaultValue;
    
    try {
      const item = localStorage.getItem(key);
      return item ? JSON.parse(item) : defaultValue;
    } catch {
      return defaultValue;
    }
  },
  
  set<T>(key: string, value: T): void {
    if (!browser) return;
    
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (error) {
      console.error(`Failed to save to localStorage: ${key}`, error);
    }
  },
  
  remove(key: string): void {
    if (!browser) return;
    localStorage.removeItem(key);
  },
  
  clear(): void {
    if (!browser) return;
    localStorage.clear();
  }
};
```

---

## 9. Derived Stores

### Complex Derivations

```typescript
// src/lib/stores/derived-examples.ts
import { derived, type Readable } from 'svelte/store';
import { authStore } from './auth';
import { fluxogramaStore } from './fluxograma';

// ============================================================
// Multi-store Derivation
// ============================================================

// Combine auth and fluxograma state
export const dashboardData = derived(
  [authStore, fluxogramaStore],
  ([$auth, $fluxograma]) => ({
    userName: $auth.user?.nome ?? 'Guest',
    courseName: $auth.user?.dadosFluxograma?.nomeCurso ?? 'No course',
    ira: $auth.user?.dadosFluxograma?.ira ?? 0,
    progress: $fluxograma.currentCourseData 
      ? calculateProgress($fluxograma)
      : 0,
    isReady: $auth.isAuthenticated && !$fluxograma.loading
  })
);

function calculateProgress(state: any): number {
  const total = state.currentCourseData?.materias.length ?? 0;
  const completed = state.currentCourseData?.materias.filter(
    (m: any) => m.status === 'completed'
  ).length ?? 0;
  
  return total > 0 ? Math.round((completed / total) * 100) : 0;
}

// ============================================================
// Async Derived Store
// ============================================================

// For async operations, use a writable backing store
import { writable } from 'svelte/store';

export function createAsyncDerived<S, T>(
  source: Readable<S>,
  asyncFn: (value: S) => Promise<T>,
  initialValue: T
): Readable<{ value: T; loading: boolean; error: Error | null }> {
  const { subscribe, set } = writable({
    value: initialValue,
    loading: false,
    error: null as Error | null
  });
  
  source.subscribe(async (sourceValue) => {
    set({ value: initialValue, loading: true, error: null });
    
    try {
      const result = await asyncFn(sourceValue);
      set({ value: result, loading: false, error: null });
    } catch (error) {
      set({ 
        value: initialValue, 
        loading: false, 
        error: error as Error 
      });
    }
  });
  
  return { subscribe };
}

// Usage
export const courseDetails = createAsyncDerived(
  authStore,
  async ($auth) => {
    if (!$auth.user?.dadosFluxograma?.nomeCurso) return null;
    
    const response = await fetch(`/api/courses/${$auth.user.dadosFluxograma.nomeCurso}`);
    return response.json();
  },
  null
);

// ============================================================
// Filtered Store
// ============================================================

export function createFilteredStore<T>(
  source: Readable<T[]>,
  filterFn: Readable<(item: T) => boolean>
): Readable<T[]> {
  return derived(
    [source, filterFn],
    ([$items, $filter]) => $items.filter($filter)
  );
}

// Usage
const searchTerm = writable('');
const filterFn = derived(
  searchTerm,
  $term => (materia: any) => 
    materia.nome.toLowerCase().includes($term.toLowerCase())
);

export const filteredMaterias = createFilteredStore(
  courseMaterias,
  filterFn
);
```

---

## 10. Store Subscriptions

### Manual Subscriptions

```svelte
<script lang="ts">
  import { onDestroy } from 'svelte';
  import { authStore } from '$lib/stores/auth';
  
  // Auto-subscribe with $ prefix (recommended)
  // $authStore automatically subscribes and unsubscribes
  
  // Manual subscription (when needed)
  let userName = '';
  
  const unsubscribe = authStore.subscribe(state => {
    userName = state.user?.nome ?? 'Guest';
    // Do something on every change
    console.log('Auth state changed:', state);
  });
  
  // Clean up on component destroy
  onDestroy(unsubscribe);
</script>

<p>Welcome, {userName}</p>
<p>Or use auto-subscribe: {$authStore.user?.nome}</p>
```

### Subscription Outside Components

```typescript
// src/lib/services/analytics.ts
import { get } from 'svelte/store';
import { authStore } from '$lib/stores/auth';

// Get current value once (no subscription)
export function trackEvent(event: string) {
  const state = get(authStore);
  
  analytics.track(event, {
    userId: state.user?.id,
    isAuthenticated: state.isAuthenticated
  });
}

// Subscribe to changes
let unsubscribe: () => void;

export function initAnalytics() {
  unsubscribe = authStore.subscribe(state => {
    if (state.isAuthenticated) {
      analytics.identify(state.user!.id);
    }
  });
}

export function destroyAnalytics() {
  unsubscribe?.();
}
```

### Using Stores in Load Functions

```typescript
// src/routes/meu-fluxograma/+page.ts
import { get } from 'svelte/store';
import { authStore } from '$lib/stores/auth';
import { redirect } from '@sveltejs/kit';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params }) => {
  // Note: stores may not be hydrated during SSR
  // Use server-side session checking instead
  
  return {
    courseName: params.courseName ?? null
  };
};
```

---

## 11. SSR Considerations

### Avoiding localStorage on Server

```typescript
// src/lib/stores/safe-auth.ts
import { writable } from 'svelte/store';
import { browser } from '$app/environment';

function createAuthStore() {
  const { subscribe, set, update } = writable({
    user: null,
    isAuthenticated: false,
    isLoading: true
  });

  return {
    subscribe,
    
    init() {
      // Only run on client
      if (!browser) return;
      
      const stored = localStorage.getItem('user');
      if (stored) {
        const user = JSON.parse(stored);
        set({ user, isAuthenticated: true, isLoading: false });
      } else {
        set({ user: null, isAuthenticated: false, isLoading: false });
      }
    },
    
    setUser(user: any) {
      if (browser) {
        localStorage.setItem('user', JSON.stringify(user));
      }
      set({ user, isAuthenticated: true, isLoading: false });
    }
  };
}
```

### Server-Side Auth with Hooks

```typescript
// src/hooks.server.ts
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  // Get session from cookies (works on server)
  const session = event.cookies.get('session');
  
  if (session) {
    try {
      // Validate session token
      const user = await validateSession(session);
      event.locals.user = user;
    } catch {
      event.cookies.delete('session', { path: '/' });
    }
  }
  
  return resolve(event);
};
```

### Client-Side Hydration

```svelte
<!-- src/routes/+layout.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';
  import { authStore } from '$lib/stores/auth';
  import { page } from '$app/stores';
  
  // Server data from +layout.server.ts
  export let data;
  
  onMount(() => {
    // Hydrate client-side stores
    if (data.user) {
      authStore.setUser(data.user);
    } else {
      authStore.init(); // Try localStorage
    }
  });
</script>

{#if browser}
  <!-- Client-side only UI that depends on stores -->
  <ClientOnlyComponent />
{:else}
  <!-- SSR fallback -->
  <LoadingPlaceholder />
{/if}
```

---

## 12. Svelte 5 Runes

Svelte 5 introduces runes as an alternative to stores for reactive state.

### Runes Overview

```svelte
<script lang="ts">
  // $state - reactive state
  let count = $state(0);
  
  // $derived - computed values
  let doubled = $derived(count * 2);
  
  // $effect - side effects
  $effect(() => {
    console.log(`Count is now ${count}`);
  });
  
  // $props - component props
  let { name, age = 18 } = $props<{ name: string; age?: number }>();
</script>

<button onclick={() => count++}>
  {count} (doubled: {doubled})
</button>
```

### Auth State with Runes

```typescript
// src/lib/state/auth.svelte.ts
import { browser } from '$app/environment';

interface User {
  id: number;
  nome: string;
  email: string;
  dadosFluxograma?: any;
}

class AuthState {
  user = $state<User | null>(null);
  isLoading = $state(true);
  error = $state<string | null>(null);
  
  // Derived state
  isAuthenticated = $derived(this.user !== null);
  userName = $derived(this.user?.nome ?? 'Guest');
  
  constructor() {
    if (browser) {
      this.hydrate();
    }
  }
  
  private hydrate() {
    try {
      const stored = localStorage.getItem('nofluxo_user');
      if (stored && stored !== 'null') {
        this.user = JSON.parse(stored);
      }
    } catch (e) {
      console.error('Failed to hydrate auth:', e);
    }
    this.isLoading = false;
  }
  
  login(user: User) {
    this.user = user;
    this.error = null;
    
    if (browser) {
      localStorage.setItem('nofluxo_user', JSON.stringify(user));
    }
  }
  
  logout() {
    this.user = null;
    
    if (browser) {
      localStorage.removeItem('nofluxo_user');
    }
  }
  
  updateUser(updates: Partial<User>) {
    if (this.user) {
      this.user = { ...this.user, ...updates };
      
      if (browser) {
        localStorage.setItem('nofluxo_user', JSON.stringify(this.user));
      }
    }
  }
  
  setError(error: string) {
    this.error = error;
    this.isLoading = false;
  }
}

// Singleton instance
export const authState = new AuthState();
```

### Fluxograma State with Runes

```typescript
// src/lib/state/fluxograma.svelte.ts
import { browser } from '$app/environment';
import type { CursoModel, MateriaModel } from '$lib/types/curso';

const MIN_ZOOM = 0.5;
const MAX_ZOOM = 2.0;
const ZOOM_STEP = 0.1;

class FluxogramaState {
  // Course data
  currentCourse = $state<CursoModel | null>(null);
  matrices = $state<CursoModel[]>([]);
  
  // UI state
  zoomLevel = $state(1.0);
  showPrereqChains = $state(false);
  showConnections = $state(false);
  showOptativasModal = $state(false);
  
  // Selection
  selectedMateria = $state<MateriaModel | null>(null);
  
  // Loading
  loading = $state(false);
  error = $state<string | null>(null);
  
  // Derived
  materias = $derived(this.currentCourse?.materias ?? []);
  completedMaterias = $derived(
    this.materias.filter(m => m.status === 'completed')
  );
  progressPercentage = $derived(
    this.materias.length > 0
      ? Math.round((this.completedMaterias.length / this.materias.length) * 100)
      : 0
  );
  zoomPercentage = $derived(Math.round(this.zoomLevel * 100));
  
  constructor() {
    if (browser) {
      const stored = localStorage.getItem('nofluxo_zoom');
      if (stored) {
        this.zoomLevel = parseFloat(stored);
      }
    }
  }
  
  // Zoom controls
  zoomIn() {
    this.zoomLevel = Math.min(MAX_ZOOM, this.zoomLevel + ZOOM_STEP);
    this.persistZoom();
  }
  
  zoomOut() {
    this.zoomLevel = Math.max(MIN_ZOOM, this.zoomLevel - ZOOM_STEP);
    this.persistZoom();
  }
  
  setZoom(level: number) {
    this.zoomLevel = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, level));
    this.persistZoom();
  }
  
  resetZoom() {
    this.zoomLevel = 1.0;
    this.persistZoom();
  }
  
  private persistZoom() {
    if (browser) {
      localStorage.setItem('nofluxo_zoom', this.zoomLevel.toString());
    }
  }
  
  // Toggle controls
  togglePrereqChains() {
    this.showPrereqChains = !this.showPrereqChains;
  }
  
  toggleConnections() {
    this.showConnections = !this.showConnections;
  }
  
  // Data loading
  setCourseData(course: CursoModel, allMatrices: CursoModel[]) {
    this.currentCourse = course;
    this.matrices = allMatrices;
    this.loading = false;
    this.error = null;
  }
  
  setLoading(loading: boolean) {
    this.loading = loading;
    if (loading) this.error = null;
  }
  
  setError(error: string) {
    this.error = error;
    this.loading = false;
  }
  
  // Selection
  selectMateria(materia: MateriaModel | null) {
    this.selectedMateria = materia;
  }
  
  // Reset
  reset() {
    this.currentCourse = null;
    this.matrices = [];
    this.selectedMateria = null;
    this.loading = false;
    this.error = null;
    this.showPrereqChains = false;
    this.showConnections = false;
  }
}

export const fluxogramaState = new FluxogramaState();
```

### Using Runes in Components

```svelte
<!-- src/routes/meu-fluxograma/+page.svelte (Svelte 5) -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { fluxogramaState } from '$lib/state/fluxograma.svelte';
  import { authState } from '$lib/state/auth.svelte';
  import { goto } from '$app/navigation';
  import { fluxogramaService } from '$lib/services/fluxograma';
  
  let { data } = $props();
  
  onMount(async () => {
    const courseName = data.courseName ?? authState.user?.dadosFluxograma?.nomeCurso;
    
    if (!courseName) {
      goto('/upload-historico');
      return;
    }
    
    fluxogramaState.setLoading(true);
    
    try {
      const result = await fluxogramaService.getCourseData(courseName);
      
      if (result.error) {
        fluxogramaState.setError(result.error);
      } else {
        fluxogramaState.setCourseData(result.course!, result.matrices!);
      }
    } catch (error) {
      fluxogramaState.setError('Failed to load course data');
    }
  });
</script>

<div class="fluxograma-container">
  <!-- Zoom Controls -->
  <div class="controls">
    <button onclick={() => fluxogramaState.zoomOut()}>-</button>
    <span>{fluxogramaState.zoomPercentage}%</span>
    <button onclick={() => fluxogramaState.zoomIn()}>+</button>
    <button onclick={() => fluxogramaState.resetZoom()}>Reset</button>
  </div>
  
  <!-- Toggle Controls -->
  <div class="toggles">
    <label>
      <input 
        type="checkbox" 
        checked={fluxogramaState.showPrereqChains}
        onchange={() => fluxogramaState.togglePrereqChains()}
      />
      Show Prerequisites
    </label>
  </div>
  
  <!-- Progress -->
  <div class="progress">
    <span>Progress: {fluxogramaState.progressPercentage}%</span>
  </div>
  
  <!-- Loading/Error States -->
  {#if fluxogramaState.loading}
    <div class="loading">Loading...</div>
  {:else if fluxogramaState.error}
    <div class="error">{fluxogramaState.error}</div>
  {:else}
    <!-- Fluxogram Grid -->
    <div 
      class="fluxogram"
      style="transform: scale({fluxogramaState.zoomLevel})"
    >
      {#each fluxogramaState.materias as materia (materia.codigoMateria)}
        <MateriaCard 
          {materia}
          selected={fluxogramaState.selectedMateria?.codigoMateria === materia.codigoMateria}
          onclick={() => fluxogramaState.selectMateria(materia)}
        />
      {/each}
    </div>
  {/if}
</div>
```

### Comparison: Stores vs Runes

| Feature | Svelte 4 Stores | Svelte 5 Runes |
|---------|-----------------|----------------|
| Syntax | `$storeName` | Direct property access |
| Type | `writable<T>()` | `$state<T>()` |
| Computed | `derived()` | `$derived()` |
| Side effects | `subscribe()` | `$effect()` |
| File extension | `.ts` | `.svelte.ts` |
| SSR | Works | Works |
| Complexity | Moderate | Simpler |
| Bundle size | Smaller | Larger (runes runtime) |

### Recommendation

- **Use Stores (Svelte 4)** for this migration as the SvelteKit scaffold is based on Svelte 4
- **Prepare for Runes** by keeping state logic modular and easy to migrate
- **Consider Runes** for new features once Svelte 5 is stable and the team is comfortable

---

## File Structure

```
src/lib/
├── stores/           # Svelte 4 stores
│   ├── auth.ts
│   ├── user.ts
│   ├── fluxograma.ts
│   ├── chat.ts
│   ├── upload.ts
│   ├── ui.ts
│   ├── persisted.ts
│   └── index.ts      # Re-exports
├── state/            # Svelte 5 runes (future)
│   ├── auth.svelte.ts
│   ├── fluxograma.svelte.ts
│   └── index.ts
├── types/
│   ├── user.ts
│   ├── curso.ts
│   └── index.ts
└── utils/
    └── storage.ts
```

### Store Index File

```typescript
// src/lib/stores/index.ts
// Auth
export { authStore, currentUser, isAuthenticated, hasFluxogramaData } from './auth';

// User
export { allMaterias, approvedMaterias, currentMaterias, userIRA } from './user';

// Fluxograma
export { 
  fluxogramaStore, 
  courseMaterias, 
  completedMaterias,
  progressPercentage,
  zoomPercentage 
} from './fluxograma';

// Chat
export { chatStore, chatMessages, isChatBusy, hasMessages } from './chat';

// Upload
export { uploadStore, isUploading, hasExtractedData, uploadComplete } from './upload';

// UI
export { uiStore, activeToasts, hasOpenModal, isGlobalLoading } from './ui';

// Utilities
export { createPersistedStore } from './persisted';
```

---

## Migration Checklist

- [ ] Create `src/lib/types/user.ts` with TypeScript interfaces
- [ ] Create `src/lib/types/curso.ts` with course/materia types
- [ ] Implement `src/lib/stores/auth.ts`
- [ ] Implement `src/lib/stores/user.ts`
- [ ] Implement `src/lib/stores/fluxograma.ts`
- [ ] Implement `src/lib/stores/chat.ts`
- [ ] Implement `src/lib/stores/upload.ts`
- [ ] Implement `src/lib/stores/ui.ts`
- [ ] Create `src/lib/stores/persisted.ts` utility
- [ ] Create `src/lib/utils/storage.ts` wrapper
- [ ] Create `src/lib/stores/index.ts` barrel export
- [ ] Add store initialization to root layout
- [ ] Test SSR compatibility
- [ ] Add Toast component to root layout
- [ ] Add Modal container to root layout

## Next Steps

After implementing stores:
1. **Plan 04**: Connect stores to API services
2. **Plan 07**: Use stores in home page
3. **Plan 11**: Integrate fluxogramaStore with visualization
