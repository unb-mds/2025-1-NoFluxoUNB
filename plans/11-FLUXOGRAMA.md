# 11. Fluxograma (Interactive Curriculum Flowchart)

## Overview

The Fluxograma is the most complex feature in NoFluxo - an interactive visualization of a student's curriculum showing subjects organized by semester, with prerequisite connections, status colors, and interactive features for academic planning.

**Complexity Level**: High  
**Dependencies**: Authentication, API services, User data  
**Recommended Libraries**: D3.js (or panzoom + SVG), html2canvas for screenshots

---

## 1. Page Structure

### 1.1 FluxogramasIndexScreen (Course Selection)

A listing page showing all available courses with search and filtering.

**Flutter Source**: `fluxogramas_index_screen.dart`

**Route**: `/fluxogramas`

```typescript
// src/routes/fluxogramas/+page.svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import type { CursoMinimal } from '$lib/types/curso';
  import { fluxogramaService } from '$lib/services/fluxograma.service';
  import CourseCard from '$lib/components/fluxograma/CourseCard.svelte';
  import GraffitiBackground from '$lib/components/ui/GraffitiBackground.svelte';
  import Navbar from '$lib/components/ui/Navbar.svelte';
  
  let cursos: CursoMinimal[] = [];
  let filteredCursos: CursoMinimal[] = [];
  let searchText = '';
  let selectedFilter = 'TODOS';
  let classificacoesUnicas: string[] = [];
  let loading = true;
  let error: string | null = null;
  
  // Pagination
  const itemsPerPage = 6;
  let currentPage = 1;
  
  $: {
    let filtered = cursos;
    
    // Filter by classification
    if (selectedFilter !== 'TODOS') {
      filtered = filtered.filter(c => 
        c.classificacao.toLowerCase() === selectedFilter.toLowerCase()
      );
    }
    
    // Filter by search text
    if (searchText) {
      filtered = filtered.filter(c =>
        c.nomeCurso.toLowerCase().includes(searchText.toLowerCase()) ||
        c.matrizCurricular.toLowerCase().includes(searchText.toLowerCase())
      );
    }
    
    filteredCursos = filtered;
  }
  
  $: totalPages = Math.max(1, Math.ceil(filteredCursos.length / itemsPerPage));
  
  $: paginatedCursos = filteredCursos.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );
  
  onMount(async () => {
    try {
      const result = await fluxogramaService.getAllCursos();
      
      // Remove duplicates by course name
      const uniqueNames = new Set<string>();
      cursos = result.filter(c => {
        if (uniqueNames.has(c.nomeCurso)) return false;
        uniqueNames.add(c.nomeCurso);
        return true;
      }).sort((a, b) => a.nomeCurso.localeCompare(b.nomeCurso));
      
      // Extract unique classifications
      classificacoesUnicas = [...new Set(
        cursos.map(c => c.classificacao).filter(Boolean)
      )];
      
    } catch (e) {
      error = e instanceof Error ? e.message : 'Failed to load courses';
    } finally {
      loading = false;
    }
  });
  
  function viewFluxograma(curso: CursoMinimal) {
    goto(`/fluxogramas/${encodeURIComponent(curso.nomeCurso)}`);
  }
</script>

<div class="min-h-screen relative">
  <GraffitiBackground />
  <div class="absolute inset-0 bg-black/30" />
  
  <div class="relative z-10">
    <Navbar isFluxogramasPage />
    
    <main class="max-w-7xl mx-auto px-6 py-12">
      <!-- Header -->
      <div class="text-center mb-12">
        <h1 class="text-4xl md:text-5xl font-['Permanent_Marker'] text-white">
          FLUXOGRAMAS <span class="text-pink-500">DISPONÍVEIS</span>
        </h1>
        <p class="mt-4 text-gray-300 max-w-2xl mx-auto">
          Escolha o curso para visualizar seu fluxograma completo.
        </p>
      </div>
      
      <!-- Search and Filters -->
      <div class="flex flex-wrap gap-4 mb-8">
        <input
          type="text"
          bind:value={searchText}
          placeholder="Buscar curso..."
          class="flex-1 min-w-64 px-4 py-3 bg-white/10 border border-white/20 
                 rounded-lg text-white placeholder-gray-400 focus:outline-none 
                 focus:ring-2 focus:ring-purple-500"
          on:input={() => currentPage = 1}
        />
        
        <select
          bind:value={selectedFilter}
          class="px-4 py-3 bg-white/10 border border-white/20 rounded-lg 
                 text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
          on:change={() => currentPage = 1}
        >
          <option value="TODOS">TODOS</option>
          {#each classificacoesUnicas as classificacao}
            <option value={classificacao}>{classificacao.toUpperCase()}</option>
          {/each}
        </select>
      </div>
      
      <!-- Course Grid -->
      {#if loading}
        <div class="flex justify-center py-12">
          <div class="animate-spin w-8 h-8 border-4 border-purple-500 
                      border-t-transparent rounded-full" />
        </div>
      {:else if error}
        <div class="text-center text-red-400 py-12">{error}</div>
      {:else}
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {#each paginatedCursos as curso}
            <CourseCard
              {curso}
              on:click={() => viewFluxograma(curso)}
            />
          {/each}
        </div>
        
        <!-- Pagination -->
        {#if totalPages > 1}
          <div class="flex justify-center gap-2 mt-8">
            <button
              class="px-4 py-2 bg-white/10 rounded-lg text-white 
                     disabled:opacity-50 hover:bg-white/20 transition"
              disabled={currentPage === 1}
              on:click={() => currentPage--}
            >
              Anterior
            </button>
            <span class="px-4 py-2 text-white">
              {currentPage} / {totalPages}
            </span>
            <button
              class="px-4 py-2 bg-white/10 rounded-lg text-white 
                     disabled:opacity-50 hover:bg-white/20 transition"
              disabled={currentPage === totalPages}
              on:click={() => currentPage++}
            >
              Próximo
            </button>
          </div>
        {/if}
      {/if}
    </main>
  </div>
</div>
```

### 1.2 MeuFluxogramaScreen (User's Flowchart)

The main interactive flowchart page showing semester columns with subjects.

**Flutter Source**: `meu_fluxograma_screen.dart`

**Routes**:
- `/meu-fluxograma` - User's personalized flowchart
- `/fluxogramas/[courseName]` - Anonymous/general view

```typescript
// src/routes/meu-fluxograma/+page.svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { authStore } from '$lib/stores/auth.store';
  import { fluxogramaStore } from '$lib/stores/fluxograma.store';
  import FluxogramaHeader from '$lib/components/fluxograma/FluxogramaHeader.svelte';
  import FluxogramaLegendControls from '$lib/components/fluxograma/FluxogramaLegendControls.svelte';
  import FluxogramContainer from '$lib/components/fluxograma/FluxogramContainer.svelte';
  import ProgressSummarySection from '$lib/components/fluxograma/ProgressSummarySection.svelte';
  import OptativasModal from '$lib/components/fluxograma/OptativasModal.svelte';
  import SubjectDetailsModal from '$lib/components/fluxograma/SubjectDetailsModal.svelte';
  import GraffitiBackground from '$lib/components/ui/GraffitiBackground.svelte';
  import Navbar from '$lib/components/ui/Navbar.svelte';
  
  export let data; // From +page.ts loader
  
  let showOptativasModal = false;
  let showSubjectModal = false;
  let selectedSubject: MateriaModel | null = null;
  
  // Subscribe to store
  $: courseData = $fluxogramaStore.courseData;
  $: zoomLevel = $fluxogramaStore.zoomLevel;
  $: showConnections = $fluxogramaStore.showConnections;
  $: loading = $fluxogramaStore.loading;
  $: error = $fluxogramaStore.error;
  $: isAnonymous = $fluxogramaStore.isAnonymous;
  
  onMount(async () => {
    const courseName = data.courseName || $authStore.user?.dadosFluxograma?.nomeCurso;
    
    if (!courseName) {
      goto('/upload-historico');
      return;
    }
    
    await fluxogramaStore.loadCourseData(courseName);
  });
  
  function handleSubjectClick(subject: MateriaModel) {
    selectedSubject = subject;
    showSubjectModal = true;
  }
  
  async function handleScreenshot() {
    await fluxogramaStore.saveScreenshot();
  }
</script>

<div class="min-h-screen relative">
  <GraffitiBackground />
  <div class="absolute inset-0 bg-black/30" />
  
  <div class="relative z-10">
    <Navbar isFluxogramasPage />
    
    {#if loading}
      <div class="flex justify-center items-center h-96">
        <div class="animate-spin w-12 h-12 border-4 border-purple-500 
                    border-t-transparent rounded-full" />
      </div>
    {:else if error}
      <div class="text-center text-red-400 py-12">{error}</div>
    {:else if courseData}
      <main class="max-w-7xl mx-auto px-4 md:px-6 py-8 md:py-12">
        <FluxogramaHeader
          {courseData}
          {isAnonymous}
          on:save={handleScreenshot}
          on:addOptativa={() => showOptativasModal = true}
        />
        
        <FluxogramaLegendControls
          {zoomLevel}
          {showConnections}
          {isAnonymous}
          on:zoomChange={(e) => fluxogramaStore.setZoom(e.detail)}
          on:connectionsChange={(e) => fluxogramaStore.setShowConnections(e.detail)}
        />
        
        <FluxogramContainer
          {courseData}
          {zoomLevel}
          {showConnections}
          {isAnonymous}
          on:subjectClick={(e) => handleSubjectClick(e.detail)}
        />
        
        {#if !isAnonymous}
          <ProgressSummarySection {courseData} />
        {/if}
      </main>
    {/if}
  </div>
  
  <!-- Modals -->
  {#if showOptativasModal}
    <OptativasModal
      optativas={courseData?.materias.filter(m => m.nivel === 0) || []}
      on:select={(e) => {
        fluxogramaStore.addOptativa(e.detail.materia, e.detail.semestre);
        showOptativasModal = false;
      }}
      on:close={() => showOptativasModal = false}
    />
  {/if}
  
  {#if showSubjectModal && selectedSubject}
    <SubjectDetailsModal
      subject={selectedSubject}
      curso={courseData}
      {isAnonymous}
      on:close={() => {
        showSubjectModal = false;
        selectedSubject = null;
      }}
    />
  {/if}
</div>
```

---

## 2. Fluxogram Container - Zoomable & Pannable

The main container with zoom/pan support using either panzoom library or manual implementation.

**Flutter Source**: `fluxogram_container.dart`

```typescript
// src/lib/components/fluxograma/FluxogramContainer.svelte
<script lang="ts">
  import { onMount, onDestroy, createEventDispatcher } from 'svelte';
  import type { CursoModel, MateriaModel } from '$lib/types/fluxograma';
  import SemesterColumn from './SemesterColumn.svelte';
  import PrerequisiteConnections from './PrerequisiteConnections.svelte';
  
  export let courseData: CursoModel;
  export let zoomLevel: number = 1;
  export let showConnections: boolean = false;
  export let isAnonymous: boolean = false;
  
  const dispatch = createEventDispatcher<{
    subjectClick: MateriaModel;
  }>();
  
  let containerEl: HTMLDivElement;
  let contentEl: HTMLDivElement;
  let isDragging = false;
  let startX = 0;
  let startY = 0;
  let scrollLeft = 0;
  let scrollTop = 0;
  
  // Hover state for showing connections
  let hoveredSubjectCode: string | null = null;
  let selectedSubjectCode: string | null = null;
  
  // Generate semester numbers
  $: semesters = Array.from({ length: courseData.semestres }, (_, i) => i + 1);
  
  // Get subjects for each semester
  function getSubjectsForSemester(semester: number): MateriaModel[] {
    return courseData.materias.filter(m => m.nivel === semester);
  }
  
  // Mouse drag handlers for panning
  function handleMouseDown(e: MouseEvent) {
    if (e.button !== 0) return; // Only left click
    isDragging = true;
    startX = e.pageX - containerEl.offsetLeft;
    startY = e.pageY - containerEl.offsetTop;
    scrollLeft = containerEl.scrollLeft;
    scrollTop = containerEl.scrollTop;
    containerEl.style.cursor = 'grabbing';
  }
  
  function handleMouseMove(e: MouseEvent) {
    if (!isDragging) return;
    e.preventDefault();
    const x = e.pageX - containerEl.offsetLeft;
    const y = e.pageY - containerEl.offsetTop;
    const walkX = (x - startX) * 1.5;
    const walkY = (y - startY) * 1.5;
    containerEl.scrollLeft = scrollLeft - walkX;
    containerEl.scrollTop = scrollTop - walkY;
  }
  
  function handleMouseUp() {
    isDragging = false;
    if (containerEl) {
      containerEl.style.cursor = 'grab';
    }
  }
  
  // Touch handlers for mobile
  function handleTouchStart(e: TouchEvent) {
    const touch = e.touches[0];
    startX = touch.pageX - containerEl.offsetLeft;
    startY = touch.pageY - containerEl.offsetTop;
    scrollLeft = containerEl.scrollLeft;
    scrollTop = containerEl.scrollTop;
    isDragging = true;
  }
  
  function handleTouchMove(e: TouchEvent) {
    if (!isDragging) return;
    const touch = e.touches[0];
    const x = touch.pageX - containerEl.offsetLeft;
    const y = touch.pageY - containerEl.offsetTop;
    containerEl.scrollLeft = scrollLeft - (x - startX);
    containerEl.scrollTop = scrollTop - (y - startY);
  }
  
  function handleTouchEnd() {
    isDragging = false;
  }
  
  // Wheel zoom
  function handleWheel(e: WheelEvent) {
    if (e.ctrlKey) {
      e.preventDefault();
      const delta = e.deltaY > 0 ? -0.1 : 0.1;
      const newZoom = Math.max(0.5, Math.min(2, zoomLevel + delta));
      dispatch('zoomChange', newZoom);
    }
  }
  
  onMount(() => {
    document.addEventListener('mouseup', handleMouseUp);
    document.addEventListener('mouseleave', handleMouseUp);
    
    return () => {
      document.removeEventListener('mouseup', handleMouseUp);
      document.removeEventListener('mouseleave', handleMouseUp);
    };
  });
</script>

<div
  bind:this={containerEl}
  class="relative overflow-auto rounded-3xl bg-black/40 cursor-grab
         scrollbar-thin scrollbar-thumb-white/20 scrollbar-track-transparent"
  style="max-height: 70vh;"
  on:mousedown={handleMouseDown}
  on:mousemove={handleMouseMove}
  on:touchstart={handleTouchStart}
  on:touchmove={handleTouchMove}
  on:touchend={handleTouchEnd}
  on:wheel={handleWheel}
  role="application"
  aria-label="Fluxograma interativo"
>
  <div
    bind:this={contentEl}
    class="inline-flex gap-8 p-8 min-w-max"
    style="transform: scale({zoomLevel}); transform-origin: top left;"
  >
    {#each semesters as semester}
      <SemesterColumn
        {semester}
        subjects={getSubjectsForSemester(semester)}
        {isAnonymous}
        {hoveredSubjectCode}
        {selectedSubjectCode}
        {showConnections}
        on:subjectClick={(e) => dispatch('subjectClick', e.detail)}
        on:subjectHover={(e) => hoveredSubjectCode = e.detail}
        on:subjectSelect={(e) => selectedSubjectCode = e.detail}
      />
    {/each}
  </div>
  
  <!-- Prerequisites SVG overlay -->
  {#if showConnections && (hoveredSubjectCode || selectedSubjectCode)}
    <PrerequisiteConnections
      {courseData}
      activeSubjectCode={hoveredSubjectCode || selectedSubjectCode}
      isHoverMode={!!hoveredSubjectCode}
      {zoomLevel}
    />
  {/if}
</div>

{#if courseData.materias.length === 0}
  <div class="text-center py-12 bg-black/30 rounded-xl">
    <svg class="w-16 h-16 mx-auto text-white/30 mb-4" fill="currentColor" viewBox="0 0 24 24">
      <path d="M12 3L1 9l4 2.18v6L12 21l7-3.82v-6l2-1.09V17h2V9L12 3z" />
    </svg>
    <h3 class="text-xl font-bold text-white mb-2">Nenhum fluxograma encontrado</h3>
    <p class="text-gray-400">
      {isAnonymous 
        ? 'Explore os fluxogramas disponíveis ou faça login para personalizar.'
        : 'Faça upload do seu histórico acadêmico para visualizar seu fluxograma personalizado.'}
    </p>
  </div>
{/if}
```

---

## 3. Semester Grid Layout

Column layout for each semester containing subject cards.

```typescript
// src/lib/components/fluxograma/SemesterColumn.svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { MateriaModel } from '$lib/types/fluxograma';
  import SubjectCard from './SubjectCard.svelte';
  
  export let semester: number;
  export let subjects: MateriaModel[];
  export let isAnonymous: boolean = false;
  export let hoveredSubjectCode: string | null = null;
  export let selectedSubjectCode: string | null = null;
  export let showConnections: boolean = false;
  
  const dispatch = createEventDispatcher<{
    subjectClick: MateriaModel;
    subjectHover: string | null;
    subjectSelect: string | null;
  }>();
</script>

<div class="flex flex-col gap-4 min-w-[200px]">
  <!-- Semester Header -->
  <div class="px-4 py-2 bg-white/10 rounded-lg text-center">
    <span class="text-white font-bold">{semester}º Semestre</span>
  </div>
  
  <!-- Subject Cards -->
  {#each subjects as subject (subject.codigoMateria)}
    <SubjectCard
      {subject}
      {isAnonymous}
      isHovered={hoveredSubjectCode === subject.codigoMateria}
      isSelected={selectedSubjectCode === subject.codigoMateria}
      {showConnections}
      on:click={() => dispatch('subjectClick', subject)}
      on:mouseenter={() => dispatch('subjectHover', subject.codigoMateria)}
      on:mouseleave={() => dispatch('subjectHover', null)}
      on:select={() => dispatch('subjectSelect', 
        selectedSubjectCode === subject.codigoMateria ? null : subject.codigoMateria
      )}
    />
  {/each}
</div>
```

---

## 4. Subject Cards - Status Colors & Interactions

Cards colored by status with hover effects.

**Flutter Source**: `course_card_widget.dart`

**Status Color Mapping**:
| Status | Start Color | End Color | Description |
|--------|-------------|-----------|-------------|
| completed | `#2DC063` | `#0B7D35` | Green - Approved subjects |
| current | `#A78BFA` | `#8B5CF6` | Purple - Currently enrolled |
| selected | `#FB7185` | `#E11D48` | Pink - Selected for next semester |
| optative | `#3B82F6` | `#1D4ED8` | Blue - Elective subjects |
| can_be_next | `#F59E0B` | `#D97706` | Orange - Prerequisites completed |
| future | `rgba(255,255,255,0.1)` | `rgba(255,255,255,0.1)` | Gray - Not yet available |

```typescript
// src/lib/components/fluxograma/SubjectCard.svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { MateriaModel } from '$lib/types/fluxograma';
  
  export let subject: MateriaModel;
  export let isAnonymous: boolean = false;
  export let isHovered: boolean = false;
  export let isSelected: boolean = false;
  export let showConnections: boolean = false;
  
  const dispatch = createEventDispatcher();
  
  // Determine display status (anonymous users don't see current status)
  $: displayStatus = getDisplayStatus(subject.status, isAnonymous);
  
  // Can subject be taken? (prerequisites completed)
  $: canBeTaken = !subject.hasAnyPrerequisitesNotCompleted && 
                  displayStatus === 'future' && 
                  !isAnonymous;
  
  function getDisplayStatus(status: string | undefined, anon: boolean): string {
    if (anon && status === 'current') return 'future';
    if (anon && status === 'selected') return 'future';
    return status || 'future';
  }
  
  // Get gradient colors based on status
  function getGradientColors(status: string, ready: boolean): [string, string] {
    if (ready && status === 'future') {
      return ['#F59E0B', '#D97706']; // Orange - ready to take
    }
    
    switch (status) {
      case 'completed':
        return ['#2DC063', '#0B7D35'];
      case 'current':
        return ['#A78BFA', '#8B5CF6'];
      case 'selected':
        return ['#FB7185', '#E11D48'];
      case 'optative':
        return ['#3B82F6', '#1D4ED8'];
      default:
        return ['rgba(255,255,255,0.1)', 'rgba(255,255,255,0.1)'];
    }
  }
  
  $: [startColor, endColor] = getGradientColors(displayStatus, canBeTaken);
  
  // Scale effect for selection/hover
  $: scale = isSelected ? 1.1 : isHovered ? 1.05 : 1;
  $: shadowColor = isSelected ? 'orange' : isHovered ? 'purple' : 'transparent';
</script>

<div
  class="w-48 rounded-lg cursor-pointer transition-all duration-300"
  style="
    background: linear-gradient(135deg, {startColor}, {endColor});
    transform: scale({scale});
    box-shadow: {isSelected || isHovered 
      ? `0 4px 12px rgba(${shadowColor === 'orange' ? '255,165,0' : '128,0,128'}, 0.4)` 
      : '0 4px 8px rgba(0,0,0,0.3)'};
    {displayStatus === 'completed' ? 'background-color: rgba(34,197,94,0.1);' : ''}
  "
  role="button"
  tabindex="0"
  on:click={() => dispatch('click')}
  on:mouseenter={() => dispatch('mouseenter')}
  on:mouseleave={() => dispatch('mouseleave')}
  on:keypress={(e) => e.key === 'Enter' && dispatch('click')}
>
  <div class="p-3">
    <!-- Subject Code -->
    <p class="text-white font-bold text-sm">{subject.codigoMateria}</p>
    
    <!-- Subject Name -->
    <p class="text-white text-xs mt-1 line-clamp-2">{subject.nomeMateria}</p>
    
    <!-- Credits & Grade -->
    <div class="flex items-center gap-2 mt-2">
      <span class="px-2 py-1 bg-black/20 rounded text-white text-[10px]">
        {subject.creditos} créditos
      </span>
      
      {#if subject.mencao && subject.mencao !== '-'}
        <span class="px-2 py-1 bg-black/20 rounded text-white text-[10px]">
          {subject.mencao}
        </span>
      {/if}
    </div>
  </div>
</div>
```

---

## 5. Prerequisite Lines - SVG Connection Drawing

This is the most complex visual element. Use SVG for drawing curved lines between subjects.

**Flutter Source**: `prerequisite_connections_widget.dart`

**Approach Options**:
1. **SVG-based** (Recommended): Draw paths using SVG overlay
2. **Canvas-based**: Use HTML Canvas for better performance with many lines
3. **D3.js**: For complex force-directed layouts

### SVG Implementation

```typescript
// src/lib/components/fluxograma/PrerequisiteConnections.svelte
<script lang="ts">
  import { onMount, tick } from 'svelte';
  import type { CursoModel } from '$lib/types/fluxograma';
  
  export let courseData: CursoModel;
  export let activeSubjectCode: string;
  export let isHoverMode: boolean = false;
  export let zoomLevel: number = 1;
  
  let svgElement: SVGSVGElement;
  let paths: PathData[] = [];
  
  interface PathData {
    d: string;
    color: string;
    strokeWidth: number;
    isGlow: boolean;
    isCoRequisite: boolean;
  }
  
  // Build prerequisite/dependent maps
  let subjectPrerequisites: Map<string, string[]> = new Map();
  let subjectDependents: Map<string, string[]> = new Map();
  let subjectCoRequisites: Map<string, string[]> = new Map();
  
  $: {
    buildMaps(courseData);
    updatePaths(activeSubjectCode, isHoverMode);
  }
  
  function buildMaps(curso: CursoModel) {
    subjectPrerequisites.clear();
    subjectDependents.clear();
    subjectCoRequisites.clear();
    
    // Build from preRequisitos
    for (const preReq of curso.preRequisitos) {
      const materiaCode = getMateriaCodeById(curso.materias, preReq.idMateria);
      if (!materiaCode) continue;
      
      if (!subjectPrerequisites.has(materiaCode)) {
        subjectPrerequisites.set(materiaCode, []);
      }
      subjectPrerequisites.get(materiaCode)!.push(preReq.codigoMateriaRequisito);
      
      if (!subjectDependents.has(preReq.codigoMateriaRequisito)) {
        subjectDependents.set(preReq.codigoMateriaRequisito, []);
      }
      subjectDependents.get(preReq.codigoMateriaRequisito)!.push(materiaCode);
    }
    
    // Build from coRequisitos
    for (const coReq of curso.coRequisitos) {
      const materiaCode = getMateriaCodeById(curso.materias, coReq.idMateria);
      if (!materiaCode) continue;
      
      if (!subjectCoRequisites.has(materiaCode)) {
        subjectCoRequisites.set(materiaCode, []);
      }
      subjectCoRequisites.get(materiaCode)!.push(coReq.codigoMateriaCoRequisito);
    }
  }
  
  function getMateriaCodeById(materias: any[], idMateria: number): string | null {
    const materia = materias.find(m => m.idMateria === idMateria);
    return materia?.codigoMateria || null;
  }
  
  async function updatePaths(subjectCode: string, hoverMode: boolean) {
    await tick(); // Wait for DOM update
    
    paths = [];
    
    const selectedEl = document.querySelector(`[data-subject="${subjectCode}"]`);
    if (!selectedEl) return;
    
    const selectedRect = selectedEl.getBoundingClientRect();
    const svgRect = svgElement?.getBoundingClientRect();
    if (!svgRect) return;
    
    const selectedCenter = {
      x: (selectedRect.left + selectedRect.width / 2 - svgRect.left) / zoomLevel,
      y: (selectedRect.top + selectedRect.height / 2 - svgRect.top) / zoomLevel,
    };
    
    // Get connected subjects
    const prerequisites = subjectPrerequisites.get(subjectCode) || [];
    const dependents = subjectDependents.get(subjectCode) || [];
    const coRequisites = subjectCoRequisites.get(subjectCode) || [];
    
    const connectedCodes = hoverMode 
      ? [...prerequisites, ...dependents]
      : dependents; // Selection mode only shows forward chain
    
    // Draw co-requisite connections (green)
    for (const code of coRequisites) {
      const el = document.querySelector(`[data-subject="${code}"]`);
      if (!el) continue;
      
      const rect = el.getBoundingClientRect();
      const center = {
        x: (rect.left + rect.width / 2 - svgRect.left) / zoomLevel,
        y: (rect.top + rect.height / 2 - svgRect.top) / zoomLevel,
      };
      
      // Straight line for co-requisites
      paths.push({
        d: `M ${selectedCenter.x} ${selectedCenter.y} L ${center.x} ${center.y}`,
        color: '#22C55E',
        strokeWidth: 2.5 * zoomLevel,
        isGlow: false,
        isCoRequisite: true,
      });
    }
    
    // Draw prerequisite/dependent connections
    for (const code of connectedCodes) {
      const el = document.querySelector(`[data-subject="${code}"]`);
      if (!el) continue;
      
      const rect = el.getBoundingClientRect();
      const center = {
        x: (rect.left + rect.width / 2 - svgRect.left) / zoomLevel,
        y: (rect.top + rect.height / 2 - svgRect.top) / zoomLevel,
      };
      
      const isPrerequisite = prerequisites.includes(code);
      const color = isPrerequisite ? '#9333EA' : '#14B8A6'; // Purple or teal
      
      // Create curved path with bezier curve
      const path = createCurvedPath(selectedCenter, center, isPrerequisite);
      
      // Add glow effect
      paths.push({
        d: path,
        color: color,
        strokeWidth: 5 * zoomLevel,
        isGlow: true,
        isCoRequisite: false,
      });
      
      // Add main line
      paths.push({
        d: path,
        color: color,
        strokeWidth: 2 * zoomLevel,
        isGlow: false,
        isCoRequisite: false,
      });
    }
  }
  
  function createCurvedPath(
    from: { x: number; y: number }, 
    to: { x: number; y: number },
    isPrerequisite: boolean
  ): string {
    // Control points for bezier curve
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    
    const cp1 = {
      x: from.x + dx * 0.3,
      y: from.y - 40 * zoomLevel,
    };
    const cp2 = {
      x: from.x + dx * 0.7,
      y: to.y - 40 * zoomLevel,
    };
    
    if (isPrerequisite) {
      // Arrow points toward selected subject
      return `M ${to.x} ${to.y} C ${cp2.x} ${cp2.y}, ${cp1.x} ${cp1.y}, ${from.x} ${from.y}`;
    } else {
      // Arrow points away from selected subject
      return `M ${from.x} ${from.y} C ${cp1.x} ${cp1.y}, ${cp2.x} ${cp2.y}, ${to.x} ${to.y}`;
    }
  }
</script>

<svg
  bind:this={svgElement}
  class="absolute inset-0 pointer-events-none overflow-visible"
  style="width: 100%; height: 100%;"
>
  <defs>
    <!-- Arrow marker -->
    <marker
      id="arrowhead"
      markerWidth="10"
      markerHeight="7"
      refX="9"
      refY="3.5"
      orient="auto"
    >
      <polygon points="0 0, 10 3.5, 0 7" fill="#14B8A6" />
    </marker>
    <marker
      id="arrowhead-purple"
      markerWidth="10"
      markerHeight="7"
      refX="9"
      refY="3.5"
      orient="auto"
    >
      <polygon points="0 0, 10 3.5, 0 7" fill="#9333EA" />
    </marker>
  </defs>
  
  {#each paths as path}
    <path
      d={path.d}
      fill="none"
      stroke={path.color}
      stroke-width={path.strokeWidth}
      stroke-opacity={path.isGlow ? 0.3 : 1}
      stroke-linecap="round"
      marker-end={!path.isGlow && !path.isCoRequisite 
        ? `url(#arrowhead${path.color === '#9333EA' ? '-purple' : ''})` 
        : undefined}
    />
  {/each}
</svg>
```

### Alternative: D3.js Force-Directed Graph

For more complex layouts, consider D3.js:

```typescript
// src/lib/components/fluxograma/FluxogramD3.svelte
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import * as d3 from 'd3';
  import type { CursoModel } from '$lib/types/fluxograma';
  
  export let courseData: CursoModel;
  export let width = 1200;
  export let height = 800;
  
  let container: HTMLDivElement;
  let svg: d3.Selection<SVGSVGElement, unknown, null, undefined>;
  
  interface Node {
    id: string;
    semester: number;
    status: string;
    x?: number;
    y?: number;
    fx?: number;
    fy?: number;
  }
  
  interface Link {
    source: string;
    target: string;
    type: 'prerequisite' | 'corequisite';
  }
  
  onMount(() => {
    const nodes: Node[] = courseData.materias.map(m => ({
      id: m.codigoMateria,
      semester: m.nivel,
      status: m.status || 'future',
    }));
    
    const links: Link[] = [
      ...courseData.preRequisitos.map(pr => ({
        source: pr.codigoMateriaRequisito,
        target: getMateriaCodeById(courseData.materias, pr.idMateria) || '',
        type: 'prerequisite' as const,
      })),
      ...courseData.coRequisitos.map(cr => ({
        source: cr.codigoMateriaCoRequisito,
        target: getMateriaCodeById(courseData.materias, cr.idMateria) || '',
        type: 'corequisite' as const,
      })),
    ].filter(l => l.target);
    
    svg = d3.select(container)
      .append('svg')
      .attr('width', width)
      .attr('height', height)
      .attr('viewBox', [0, 0, width, height])
      .call(d3.zoom<SVGSVGElement, unknown>()
        .scaleExtent([0.5, 3])
        .on('zoom', (event) => {
          g.attr('transform', event.transform);
        })
      );
    
    const g = svg.append('g');
    
    // Create simulation
    const simulation = d3.forceSimulation(nodes as d3.SimulationNodeDatum[])
      .force('link', d3.forceLink(links).id((d: any) => d.id).distance(100))
      .force('charge', d3.forceManyBody().strength(-200))
      .force('x', d3.forceX().x((d: any) => (d.semester / courseData.semestres) * width * 0.8 + 100))
      .force('y', d3.forceY(height / 2));
    
    // Draw links
    const link = g.append('g')
      .selectAll('path')
      .data(links)
      .join('path')
      .attr('stroke', d => d.type === 'corequisite' ? '#22C55E' : '#9333EA')
      .attr('stroke-width', 2)
      .attr('fill', 'none')
      .attr('marker-end', 'url(#arrow)');
    
    // Draw nodes
    const node = g.append('g')
      .selectAll('rect')
      .data(nodes)
      .join('rect')
      .attr('width', 100)
      .attr('height', 60)
      .attr('rx', 8)
      .attr('fill', d => getStatusColor(d.status))
      .call(d3.drag<SVGRectElement, Node>()
        .on('start', dragstarted)
        .on('drag', dragged)
        .on('end', dragended)
      );
    
    // Add labels
    const labels = g.append('g')
      .selectAll('text')
      .data(nodes)
      .join('text')
      .text(d => d.id)
      .attr('fill', 'white')
      .attr('font-size', 10)
      .attr('text-anchor', 'middle');
    
    simulation.on('tick', () => {
      link.attr('d', (d: any) => {
        const dx = d.target.x - d.source.x;
        const dy = d.target.y - d.source.y;
        const dr = Math.sqrt(dx * dx + dy * dy);
        return `M${d.source.x + 50},${d.source.y + 30}
                A${dr},${dr} 0 0,1 ${d.target.x + 50},${d.target.y + 30}`;
      });
      
      node
        .attr('x', (d: any) => d.x)
        .attr('y', (d: any) => d.y);
      
      labels
        .attr('x', (d: any) => d.x + 50)
        .attr('y', (d: any) => d.y + 35);
    });
    
    function dragstarted(event: d3.D3DragEvent<SVGRectElement, Node, Node>, d: Node) {
      if (!event.active) simulation.alphaTarget(0.3).restart();
      d.fx = d.x;
      d.fy = d.y;
    }
    
    function dragged(event: d3.D3DragEvent<SVGRectElement, Node, Node>, d: Node) {
      d.fx = event.x;
      d.fy = event.y;
    }
    
    function dragended(event: d3.D3DragEvent<SVGRectElement, Node, Node>, d: Node) {
      if (!event.active) simulation.alphaTarget(0);
      d.fx = null;
      d.fy = null;
    }
    
    function getStatusColor(status: string): string {
      switch (status) {
        case 'completed': return 'url(#grad-completed)';
        case 'current': return 'url(#grad-current)';
        case 'selected': return 'url(#grad-selected)';
        default: return 'rgba(255,255,255,0.1)';
      }
    }
  });
  
  onDestroy(() => {
    svg?.remove();
  });
</script>

<div bind:this={container} class="w-full h-full"></div>
```

---

## 6. Zoom Controls

Button and slider controls for zoom level.

**Flutter Source**: `fluxograma_legend_controls.dart`

```typescript
// src/lib/components/fluxograma/FluxogramaLegendControls.svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let zoomLevel: number = 1;
  export let showConnections: boolean = false;
  export let isAnonymous: boolean = false;
  
  const dispatch = createEventDispatcher<{
    zoomChange: number;
    connectionsChange: boolean;
  }>();
  
  function adjustZoom(delta: number) {
    const newZoom = Math.max(0.5, Math.min(2, zoomLevel + delta));
    dispatch('zoomChange', newZoom);
  }
  
  const legendItems = [
    { colors: ['#4ADE80', '#22C55E'], label: 'Concluídas' },
    { colors: ['#A78BFA', '#8B5CF6'], label: 'Em Curso' },
    { colors: ['#F59E0B', '#D97706'], label: 'Próximo semestre' },
  ];
</script>

<div class="bg-black/30 rounded-lg p-4 mb-6">
  <div class="flex flex-wrap items-center justify-between gap-4">
    <!-- Legend -->
    <div class="flex flex-wrap gap-4">
      {#if !isAnonymous}
        {#each legendItems as item}
          <div class="flex items-center gap-2">
            <div 
              class="w-4 h-4 rounded"
              style="background: linear-gradient(135deg, {item.colors[0]}, {item.colors[1]});"
            />
            <span class="text-white text-sm">{item.label}</span>
          </div>
        {/each}
      {/if}
      
      <!-- Connections Toggle -->
      <label class="flex items-center gap-2 cursor-pointer">
        <input
          type="checkbox"
          bind:checked={showConnections}
          on:change={() => dispatch('connectionsChange', showConnections)}
          class="w-4 h-4 rounded accent-purple-500"
        />
        <span class="text-white text-sm">Mostrar conexões</span>
      </label>
    </div>
    
    <!-- Zoom Controls -->
    <div class="flex items-center gap-2 bg-white/10 rounded-lg px-2">
      <button
        class="p-2 text-white hover:bg-white/10 rounded transition"
        on:click={() => adjustZoom(-0.1)}
        aria-label="Diminuir zoom"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-width="2" d="M20 12H4" />
        </svg>
      </button>
      
      <span class="text-white text-sm w-12 text-center">
        {Math.round(zoomLevel * 100)}%
      </span>
      
      <button
        class="p-2 text-white hover:bg-white/10 rounded transition"
        on:click={() => adjustZoom(0.1)}
        aria-label="Aumentar zoom"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
      </button>
    </div>
  </div>
</div>
```

---

## 7. Subject Details Modal

Full subject information dialog with tabs.

**Flutter Source**: `materia_data_dialog_content.dart`

```typescript
// src/lib/components/fluxograma/SubjectDetailsModal.svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { MateriaModel, CursoModel } from '$lib/types/fluxograma';
  
  export let subject: MateriaModel;
  export let curso: CursoModel;
  export let isAnonymous: boolean = false;
  
  const dispatch = createEventDispatcher<{ close: void }>();
  
  let activeTab: 'info' | 'prerequisites' | 'equivalents' = 'info';
  
  // Get prerequisites from curso
  $: prerequisites = curso.preRequisitos
    .filter(pr => getMateriaCodeById(curso.materias, pr.idMateria) === subject.codigoMateria)
    .map(pr => ({
      codigo: pr.codigoMateriaRequisito,
      nome: pr.nomeMateriaRequisito,
    }));
  
  // Get co-requisites
  $: corequisites = curso.coRequisitos
    .filter(cr => getMateriaCodeById(curso.materias, cr.idMateria) === subject.codigoMateria)
    .map(cr => ({
      codigo: cr.codigoMateriaCoRequisito,
      nome: cr.nomeMateriaCoRequisito,
    }));
  
  // Get equivalents
  $: equivalents = curso.equivalencias
    .filter(eq => eq.codigoMateriaOrigem === subject.codigoMateria)
    .map(eq => ({
      codigo: eq.codigoMateriaEquivalente,
      nome: eq.nomeMateriaEquivalente,
    }));
  
  function getMateriaCodeById(materias: MateriaModel[], id: number): string | null {
    return materias.find(m => m.idMateria === id)?.codigoMateria || null;
  }
  
  function getStatusColor(): string {
    const status = subject.status?.toLowerCase() || '';
    if (isAnonymous && ['current', 'selected'].includes(status)) {
      return 'rgba(255,255,255,0.1)';
    }
    
    switch (status) {
      case 'completed': return '#22C55E';
      case 'current': return '#8B5CF6';
      case 'selected': return '#E11D48';
      default: return 'rgba(255,255,255,0.1)';
    }
  }
  
  function getStatusText(): string {
    const status = subject.status?.toLowerCase() || '';
    if (isAnonymous && ['current', 'selected'].includes(status)) {
      return 'Disponível';
    }
    
    switch (status) {
      case 'completed': return 'Concluída';
      case 'current': return 'Em Curso';
      case 'selected': return 'Selecionada';
      default: return 'Disponível';
    }
  }
</script>

<div 
  class="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4"
  on:click|self={() => dispatch('close')}
  on:keydown={(e) => e.key === 'Escape' && dispatch('close')}
  role="dialog"
  aria-modal="true"
>
  <div 
    class="bg-[#1A1A1A] rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-hidden
           border border-white/10 shadow-2xl"
  >
    <!-- Header -->
    <div 
      class="p-6 bg-gradient-to-r from-purple-900/80 to-pink-900/80"
    >
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <h2 class="text-xl md:text-2xl font-bold text-white">
            {subject.codigoMateria} - {subject.nomeMateria}
          </h2>
        </div>
        
        <div class="flex items-center gap-4">
          <span 
            class="px-3 py-1 rounded-full text-sm text-white"
            style="background-color: {getStatusColor()};"
          >
            {getStatusText()}
          </span>
          
          <button
            class="text-white/70 hover:text-white transition"
            on:click={() => dispatch('close')}
            aria-label="Fechar"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
    </div>
    
    <!-- Tabs -->
    <div class="flex border-b border-white/10">
      {#each [
        { id: 'info', label: 'Informações' },
        { id: 'prerequisites', label: 'Pré-requisitos' },
        { id: 'equivalents', label: 'Equivalências' },
      ] as tab}
        <button
          class="flex-1 px-4 py-3 text-sm font-medium transition
                 {activeTab === tab.id 
                   ? 'text-purple-400 border-b-2 border-purple-400' 
                   : 'text-gray-400 hover:text-white'}"
          on:click={() => activeTab = tab.id}
        >
          {tab.label}
        </button>
      {/each}
    </div>
    
    <!-- Content -->
    <div class="p-6 overflow-y-auto max-h-96">
      {#if activeTab === 'info'}
        <div class="space-y-4">
          <div class="grid grid-cols-2 gap-4">
            <div class="bg-white/5 rounded-lg p-3">
              <p class="text-gray-400 text-xs">Créditos</p>
              <p class="text-white text-lg font-bold">{subject.creditos}</p>
            </div>
            <div class="bg-white/5 rounded-lg p-3">
              <p class="text-gray-400 text-xs">Semestre</p>
              <p class="text-white text-lg font-bold">{subject.nivel}º</p>
            </div>
            {#if subject.mencao && !isAnonymous}
              <div class="bg-white/5 rounded-lg p-3">
                <p class="text-gray-400 text-xs">Menção</p>
                <p class="text-white text-lg font-bold">{subject.mencao}</p>
              </div>
            {/if}
            {#if subject.professor && !isAnonymous}
              <div class="bg-white/5 rounded-lg p-3">
                <p class="text-gray-400 text-xs">Professor</p>
                <p class="text-white text-sm">{subject.professor}</p>
              </div>
            {/if}
          </div>
          
          <div>
            <h3 class="text-gray-400 text-xs mb-2">Ementa</h3>
            <p class="text-white/80 text-sm leading-relaxed">
              {subject.ementa || 'Ementa não disponível.'}
            </p>
          </div>
        </div>
        
      {:else if activeTab === 'prerequisites'}
        <div class="space-y-4">
          {#if prerequisites.length > 0}
            <div>
              <h3 class="text-gray-400 text-xs mb-2">Pré-requisitos</h3>
              <div class="space-y-2">
                {#each prerequisites as prereq}
                  <div class="bg-purple-900/30 rounded-lg p-3 border border-purple-500/30">
                    <p class="text-purple-300 font-medium">{prereq.codigo}</p>
                    <p class="text-white/70 text-sm">{prereq.nome}</p>
                  </div>
                {/each}
              </div>
            </div>
          {:else}
            <p class="text-gray-400">Esta matéria não possui pré-requisitos.</p>
          {/if}
          
          {#if corequisites.length > 0}
            <div>
              <h3 class="text-gray-400 text-xs mb-2">Co-requisitos</h3>
              <div class="space-y-2">
                {#each corequisites as coreq}
                  <div class="bg-green-900/30 rounded-lg p-3 border border-green-500/30">
                    <p class="text-green-300 font-medium">{coreq.codigo}</p>
                    <p class="text-white/70 text-sm">{coreq.nome}</p>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
        </div>
        
      {:else if activeTab === 'equivalents'}
        {#if equivalents.length > 0}
          <div class="space-y-2">
            {#each equivalents as equiv}
              <div class="bg-blue-900/30 rounded-lg p-3 border border-blue-500/30">
                <p class="text-blue-300 font-medium">{equiv.codigo}</p>
                <p class="text-white/70 text-sm">{equiv.nome}</p>
              </div>
            {/each}
          </div>
        {:else}
          <p class="text-gray-400">Esta matéria não possui equivalências registradas.</p>
        {/if}
      {/if}
    </div>
    
    <!-- Footer -->
    {#if !isAnonymous && subject.status === 'future'}
      <div class="p-4 border-t border-white/10">
        <button
          class="w-full py-3 bg-gradient-to-r from-purple-600 to-pink-600 
                 text-white font-bold rounded-lg hover:opacity-90 transition"
        >
          ADICIONAR AO PRÓXIMO SEMESTRE
        </button>
      </div>
    {/if}
  </div>
</div>
```

---

## 8. Progress Section

Statistics cards showing credits, completion percentage, etc.

**Flutter Source**: `progress_summary_section.dart`

```typescript
// src/lib/components/fluxograma/ProgressSummarySection.svelte
<script lang="ts">
  import type { CursoModel } from '$lib/types/fluxograma';
  import { authStore } from '$lib/stores/auth.store';
  
  export let courseData: CursoModel;
  
  // Calculate progress
  $: completedSubjects = courseData.materias.filter(m => m.status === 'completed');
  $: currentSubjects = courseData.materias.filter(m => m.status === 'current');
  $: totalSubjects = courseData.materias.filter(m => m.nivel > 0); // Exclude optativas
  
  $: completedCredits = completedSubjects.reduce((sum, m) => sum + m.creditos, 0);
  $: currentCredits = currentSubjects.reduce((sum, m) => sum + m.creditos, 0);
  $: totalCredits = courseData.totalCreditos || 0;
  
  $: progressPercentage = totalCredits > 0 
    ? Math.round((completedCredits / totalCredits) * 100) 
    : 0;
  
  $: currentSemester = $authStore.user?.dadosFluxograma?.semestreAtual || 1;
</script>

<div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
  <!-- Credits Progress Card -->
  <div class="bg-black/30 rounded-lg p-6">
    <div class="flex items-center gap-3 mb-4">
      <svg class="w-6 h-6 text-purple-500" fill="currentColor" viewBox="0 0 24 24">
        <path d="M12 3L1 9l4 2.18v6L12 21l7-3.82v-6l2-1.09V17h2V9L12 3z" />
      </svg>
      <h3 class="text-white font-bold">Progresso de Créditos</h3>
    </div>
    
    <div class="space-y-3">
      <div class="flex justify-between text-white">
        <span>Créditos Concluídos</span>
        <span class="font-bold text-green-400">{completedCredits}</span>
      </div>
      <div class="flex justify-between text-white">
        <span>Créditos em Curso</span>
        <span class="font-bold text-purple-400">{currentCredits}</span>
      </div>
      <div class="flex justify-between text-white">
        <span>Total Necessário</span>
        <span class="font-bold">{totalCredits}</span>
      </div>
      
      <!-- Progress Bar -->
      <div class="mt-4">
        <div class="flex justify-between text-sm text-gray-400 mb-1">
          <span>Progresso</span>
          <span>{progressPercentage}%</span>
        </div>
        <div class="h-2 bg-white/10 rounded-full overflow-hidden">
          <div 
            class="h-full bg-gradient-to-r from-green-500 to-green-400 transition-all"
            style="width: {progressPercentage}%"
          />
        </div>
      </div>
    </div>
  </div>
  
  <!-- Current Semester Card -->
  <div class="bg-black/30 rounded-lg p-6">
    <div class="flex items-center gap-3 mb-4">
      <svg class="w-6 h-6 text-blue-500" fill="currentColor" viewBox="0 0 24 24">
        <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z" />
      </svg>
      <h3 class="text-white font-bold">Semestre Atual</h3>
    </div>
    
    <div class="text-center py-4">
      <p class="text-5xl font-bold text-white">{currentSemester}º</p>
      <p class="text-gray-400 mt-2">semestre</p>
    </div>
    
    <div class="mt-4 space-y-2">
      <div class="flex justify-between text-white text-sm">
        <span>Matérias em curso</span>
        <span class="font-bold">{currentSubjects.length}</span>
      </div>
      <div class="flex justify-between text-white text-sm">
        <span>Créditos este semestre</span>
        <span class="font-bold">{currentCredits}</span>
      </div>
    </div>
  </div>
  
  <!-- Recommendations Card -->
  <div class="bg-black/30 rounded-lg p-6">
    <div class="flex items-center gap-3 mb-4">
      <svg class="w-6 h-6 text-orange-500" fill="currentColor" viewBox="0 0 24 24">
        <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
      </svg>
      <h3 class="text-white font-bold">Recomendações</h3>
    </div>
    
    <div class="text-center py-8">
      <svg class="w-12 h-12 text-purple-500 mx-auto mb-2" fill="currentColor" viewBox="0 0 24 24">
        <path d="M19.43 12.98c.04-.32.07-.64.07-.98s-.03-.66-.07-.98l2.11-1.65c.19-.15.24-.42.12-.64l-2-3.46c-.12-.22-.39-.3-.61-.22l-2.49 1c-.52-.4-1.08-.73-1.69-.98l-.38-2.65C14.46 2.18 14.25 2 14 2h-4c-.25 0-.46.18-.49.42l-.38 2.65c-.61.25-1.17.59-1.69.98l-2.49-1c-.23-.09-.49 0-.61.22l-2 3.46c-.13.22-.07.49.12.64l2.11 1.65c-.04.32-.07.65-.07.98s.03.66.07.98l-2.11 1.65c-.19.15-.24.42-.12.64l2 3.46c.12.22.39.3.61.22l2.49-1c.52.4 1.08.73 1.69.98l.38 2.65c.03.24.24.42.49.42h4c.25 0 .46-.18.49-.42l.38-2.65c.61-.25 1.17-.59 1.69-.98l2.49 1c.23.09.49 0 .61-.22l2-3.46c.12-.22.06-.49-.12-.64l-2.11-1.65z" />
      </svg>
      <p class="text-white font-bold">Em breve</p>
      <p class="text-gray-400 text-sm mt-1">Funcionalidade em desenvolvimento</p>
    </div>
  </div>
</div>
```

---

## 9. Optativas Modal

Modal for selecting and adding elective subjects.

**Flutter Source**: `optativas_modal.dart`

```typescript
// src/lib/components/fluxograma/OptativasModal.svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { MateriaModel } from '$lib/types/fluxograma';
  
  export let optativas: MateriaModel[];
  
  const dispatch = createEventDispatcher<{
    select: { materia: MateriaModel; semestre: number };
    close: void;
  }>();
  
  let searchQuery = '';
  let selectedMateria: MateriaModel | null = null;
  let selectedSemestre = 1;
  
  $: filteredOptativas = optativas.filter(m => 
    m.nomeMateria.toLowerCase().includes(searchQuery.toLowerCase()) ||
    m.codigoMateria.toLowerCase().includes(searchQuery.toLowerCase())
  );
  
  function handleConfirm() {
    if (selectedMateria) {
      dispatch('select', { 
        materia: selectedMateria, 
        semestre: selectedSemestre 
      });
    }
  }
</script>

<div 
  class="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4"
  on:click|self={() => dispatch('close')}
  on:keydown={(e) => e.key === 'Escape' && dispatch('close')}
  role="dialog"
  aria-modal="true"
>
  <div class="bg-white rounded-2xl max-w-4xl w-full max-h-[80vh] overflow-hidden">
    <!-- Header -->
    <div class="bg-gradient-to-r from-purple-600 to-blue-600 p-5 flex justify-between items-center">
      <h2 class="text-2xl font-bold text-white">Adicionar Optativa</h2>
      <button
        class="text-white/80 hover:text-white transition"
        on:click={() => dispatch('close')}
      >
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
    
    <!-- Search and Semester -->
    <div class="p-5 space-y-4 border-b">
      <input
        type="text"
        bind:value={searchQuery}
        placeholder="Buscar optativa..."
        class="w-full px-4 py-3 border rounded-lg focus:outline-none 
               focus:ring-2 focus:ring-purple-500"
      />
      
      <div class="flex items-center gap-3">
        <label class="text-gray-700 font-medium">Semestre:</label>
        <select
          bind:value={selectedSemestre}
          class="px-4 py-2 border rounded-lg focus:outline-none 
                 focus:ring-2 focus:ring-purple-500"
        >
          {#each Array.from({ length: 10 }, (_, i) => i + 1) as sem}
            <option value={sem}>{sem}º</option>
          {/each}
        </select>
      </div>
    </div>
    
    <!-- Table Header -->
    <div class="grid grid-cols-12 gap-4 px-5 py-3 bg-gray-100 font-medium text-gray-700">
      <div class="col-span-2">Código</div>
      <div class="col-span-5">Nome</div>
      <div class="col-span-2">Créditos</div>
      <div class="col-span-3">Ação</div>
    </div>
    
    <!-- Table Content -->
    <div class="max-h-80 overflow-y-auto">
      {#each filteredOptativas as optativa (optativa.codigoMateria)}
        <div 
          class="grid grid-cols-12 gap-4 px-5 py-3 border-b items-center
                 hover:bg-gray-50 transition cursor-pointer
                 {selectedMateria?.codigoMateria === optativa.codigoMateria ? 'bg-blue-50' : ''}"
          on:click={() => selectedMateria = optativa}
        >
          <div class="col-span-2 font-medium">{optativa.codigoMateria}</div>
          <div class="col-span-5 text-gray-600">{optativa.nomeMateria}</div>
          <div class="col-span-2 text-gray-600">{optativa.creditos}</div>
          <div class="col-span-3">
            <button
              class="px-4 py-1 bg-purple-600 text-white rounded-lg text-sm
                     hover:bg-purple-700 transition"
              on:click|stopPropagation={() => {
                selectedMateria = optativa;
                handleConfirm();
              }}
            >
              Adicionar
            </button>
          </div>
        </div>
      {:else}
        <div class="p-8 text-center text-gray-500">
          Nenhuma optativa encontrada.
        </div>
      {/each}
    </div>
    
    <!-- Footer -->
    <div class="p-4 border-t flex justify-end gap-3">
      <button
        class="px-6 py-2 border rounded-lg hover:bg-gray-50 transition"
        on:click={() => dispatch('close')}
      >
        Cancelar
      </button>
      <button
        class="px-6 py-2 bg-purple-600 text-white rounded-lg 
               hover:bg-purple-700 transition disabled:opacity-50"
        disabled={!selectedMateria}
        on:click={handleConfirm}
      >
        Confirmar
      </button>
    </div>
  </div>
</div>
```

---

## 10. Screenshot Export

Using html2canvas to export the fluxograma as an image.

**Flutter Source**: Uses `screenshot` package

```typescript
// src/lib/utils/screenshot.ts
import html2canvas from 'html2canvas';

export async function captureFluxograma(
  element: HTMLElement,
  filename: string = 'fluxograma.png'
): Promise<void> {
  try {
    // Apply temporary styles for better capture
    const originalTransform = element.style.transform;
    element.style.transform = 'scale(1)';
    
    const canvas = await html2canvas(element, {
      backgroundColor: '#1a1a1a',
      scale: 2, // Higher resolution
      useCORS: true,
      logging: false,
      allowTaint: true,
    });
    
    // Restore original transform
    element.style.transform = originalTransform;
    
    // Convert to blob and download
    canvas.toBlob((blob) => {
      if (!blob) {
        throw new Error('Failed to create image blob');
      }
      
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      link.click();
      
      URL.revokeObjectURL(url);
    }, 'image/png');
    
  } catch (error) {
    console.error('Screenshot capture failed:', error);
    throw error;
  }
}

// Usage in store
// src/lib/stores/fluxograma.store.ts
import { captureFluxograma } from '$lib/utils/screenshot';

// In the store actions:
async saveScreenshot(): Promise<void> {
  const container = document.getElementById('fluxogram-container');
  if (!container) {
    throw new Error('Fluxogram container not found');
  }
  
  const courseName = get(this).courseData?.nomeCurso.replace(/\s+/g, '_') || 'curso';
  const timestamp = Date.now();
  const filename = `fluxograma_${courseName}_${timestamp}.png`;
  
  await captureFluxograma(container, filename);
}
```

---

## 11. State Management - Fluxograma Store

Centralized store for all fluxograma state.

```typescript
// src/lib/stores/fluxograma.store.ts
import { writable, derived, get } from 'svelte/store';
import type { CursoModel, MateriaModel } from '$lib/types/fluxograma';
import { fluxogramaService } from '$lib/services/fluxograma.service';
import { authStore } from '$lib/stores/auth.store';
import { captureFluxograma } from '$lib/utils/screenshot';

interface OptativaAdicionada {
  materia: MateriaModel;
  semestre: number;
}

interface FluxogramaState {
  courseData: CursoModel | null;
  matrizesCurriculares: CursoModel[];
  loading: boolean;
  error: string | null;
  zoomLevel: number;
  showConnections: boolean;
  isAnonymous: boolean;
  optativasAdicionadas: OptativaAdicionada[];
  selectedSubjectCode: string | null;
  hoveredSubjectCode: string | null;
}

const initialState: FluxogramaState = {
  courseData: null,
  matrizesCurriculares: [],
  loading: false,
  error: null,
  zoomLevel: 1.0,
  showConnections: false,
  isAnonymous: false,
  optativasAdicionadas: [],
  selectedSubjectCode: null,
  hoveredSubjectCode: null,
};

function createFluxogramaStore() {
  const { subscribe, set, update } = writable<FluxogramaState>(initialState);
  
  return {
    subscribe,
    
    async loadCourseData(courseName: string): Promise<void> {
      update(s => ({ ...s, loading: true, error: null }));
      
      try {
        const cursos = await fluxogramaService.getCourseData(courseName);
        
        const auth = get(authStore);
        const isAnon = !auth.isAuthenticated || courseName !== auth.user?.dadosFluxograma?.nomeCurso;
        
        let selectedCurso: CursoModel;
        
        if (isAnon) {
          selectedCurso = cursos[0];
        } else {
          selectedCurso = cursos.find(c => 
            c.nomeCurso === courseName &&
            c.matrizCurricular === auth.user?.dadosFluxograma?.matrizCurricular
          ) || cursos[0];
        }
        
        // Apply user progress to materias if authenticated
        if (!isAnon && auth.user?.dadosFluxograma) {
          selectedCurso = applyUserProgress(selectedCurso, auth.user.dadosFluxograma);
        }
        
        // Calculate optimal zoom based on course size
        const optimalZoom = calculateOptimalZoom(selectedCurso);
        
        update(s => ({
          ...s,
          courseData: selectedCurso,
          matrizesCurriculares: cursos,
          isAnonymous: isAnon,
          zoomLevel: optimalZoom,
          loading: false,
        }));
        
      } catch (error) {
        update(s => ({
          ...s,
          loading: false,
          error: error instanceof Error ? error.message : 'Failed to load course data',
        }));
      }
    },
    
    setZoom(level: number): void {
      update(s => ({ 
        ...s, 
        zoomLevel: Math.max(0.5, Math.min(2.0, level)) 
      }));
    },
    
    setShowConnections(show: boolean): void {
      update(s => ({ ...s, showConnections: show }));
    },
    
    selectSubject(code: string | null): void {
      update(s => ({ ...s, selectedSubjectCode: code }));
    },
    
    hoverSubject(code: string | null): void {
      update(s => ({ ...s, hoveredSubjectCode: code }));
    },
    
    addOptativa(materia: MateriaModel, semestre: number): void {
      update(s => {
        const exists = s.optativasAdicionadas.some(
          o => o.materia.codigoMateria === materia.codigoMateria
        );
        
        if (exists) return s;
        
        return {
          ...s,
          optativasAdicionadas: [
            ...s.optativasAdicionadas,
            { materia, semestre }
          ],
        };
      });
    },
    
    removeOptativa(codigoMateria: string): void {
      update(s => ({
        ...s,
        optativasAdicionadas: s.optativasAdicionadas.filter(
          o => o.materia.codigoMateria !== codigoMateria
        ),
      }));
    },
    
    async saveScreenshot(): Promise<void> {
      const state = get({ subscribe });
      const container = document.getElementById('fluxogram-container');
      
      if (!container) {
        throw new Error('Fluxogram container not found');
      }
      
      const courseName = state.courseData?.nomeCurso.replace(/\s+/g, '_') || 'curso';
      const timestamp = Date.now();
      const filename = `fluxograma_${courseName}_${timestamp}.png`;
      
      await captureFluxograma(container, filename);
    },
    
    reset(): void {
      set(initialState);
    },
  };
}

function applyUserProgress(curso: CursoModel, dadosFluxograma: any): CursoModel {
  const materiasPorCodigo = new Map(
    curso.materias.map(m => [m.codigoMateria, m])
  );
  
  const cursadas = dadosFluxograma.dadosFluxograma.flat();
  
  for (const materia of cursadas) {
    const cursoMateria = materiasPorCodigo.get(materia.codigoMateria);
    if (cursoMateria) {
      const isCompleted = ['SS', 'MS', 'MM'].includes(materia.mencao);
      const isCurrent = materia.status === 'MATR';
      
      cursoMateria.status = isCompleted ? 'completed' : isCurrent ? 'current' : '';
      cursoMateria.mencao = materia.mencao;
      cursoMateria.professor = materia.professor;
    }
  }
  
  return { ...curso, materias: [...curso.materias] };
}

function calculateOptimalZoom(curso: CursoModel): number {
  const totalSemestres = curso.semestres;
  const totalMaterias = curso.materias.length;
  const densidadeMedia = totalMaterias / totalSemestres;
  
  let baseZoom = 0.7;
  
  if (totalSemestres <= 8) baseZoom = 0.85;
  else if (totalSemestres <= 10) baseZoom = 0.7;
  else if (totalSemestres <= 12) baseZoom = 0.6;
  else baseZoom = 0.5;
  
  if (densidadeMedia > 8) baseZoom -= 0.1;
  else if (densidadeMedia > 6) baseZoom -= 0.05;
  
  if (totalMaterias > 60) baseZoom -= 0.1;
  else if (totalMaterias > 45) baseZoom -= 0.05;
  
  return Math.max(0.35, Math.min(0.9, baseZoom));
}

export const fluxogramaStore = createFluxogramaStore();
```

---

## 12. Type Definitions

```typescript
// src/lib/types/fluxograma.ts
export interface MateriaModel {
  ementa: string;
  idMateria: number;
  nomeMateria: string;
  codigoMateria: string;
  nivel: number;
  creditos: number;
  status?: string;
  mencao?: string;
  professor?: string;
  preRequisitos: MateriaModel[];
  hasAnyPrerequisitesNotCompleted?: boolean;
}

export interface PreRequisitoModel {
  idPreRequisito: number;
  idMateria: number;
  idMateriaRequisito: number;
  codigoMateriaRequisito: string;
  nomeMateriaRequisito: string;
}

export interface CoRequisitoModel {
  idCoRequisito: number;
  idMateria: number;
  idMateriaCoRequisito: number;
  codigoMateriaCoRequisito: string;
  nomeMateriaCoRequisito: string;
}

export interface EquivalenciaModel {
  idEquivalencia: number;
  codigoMateriaOrigem: string;
  codigoMateriaEquivalente: string;
  nomeMateriaEquivalente: string;
}

export interface CursoModel {
  nomeCurso: string;
  matrizCurricular: string;
  idCurso: number;
  totalCreditos: number;
  classificacao: string;
  tipoCurso: string;
  materias: MateriaModel[];
  semestres: number;
  equivalencias: EquivalenciaModel[];
  preRequisitos: PreRequisitoModel[];
  coRequisitos: CoRequisitoModel[];
}

export interface CursoMinimal {
  nomeCurso: string;
  matrizCurricular: string;
  idCurso: number;
  totalCreditos: number;
  classificacao: string;
  tipoCurso: string;
}

export interface PrerequisiteVisualizationData {
  subject: string;
  chain: string[][];
  dependents: string[];
  allPrerequisites: string[];
  canBeTaken: boolean;
  depth: number;
  isRoot: boolean;
  isLeaf: boolean;
}
```

---

## 13. API Service

> **⚡ ALREADY IMPLEMENTED:** The fluxograma service has been created at `src/lib/services/fluxograma.service.ts` as part of plan 14 (Supabase Direct + RLS). All queries go directly to Supabase with RLS — no backend calls. Also depends on `src/lib/services/supabase-data.service.ts`. See [14-SUPABASE-DIRECT-RLS.md](14-SUPABASE-DIRECT-RLS.md). The code below is kept for reference but the actual implementation is already in place.

```typescript
// src/lib/services/fluxograma.service.ts
import { api } from '$lib/utils/api';
import type { CursoModel, CursoMinimal, MateriaModel } from '$lib/types/fluxograma';

class FluxogramaService {
  async getAllCursos(): Promise<CursoMinimal[]> {
    const response = await api.get<any[]>('/cursos/all-cursos');
    return response.map(c => ({
      nomeCurso: c.nome_curso,
      matrizCurricular: c.matriz_curricular,
      idCurso: c.id_curso,
      totalCreditos: c.creditos,
      classificacao: c.classificacao || 'outro',
      tipoCurso: c.tipo_curso || 'outro',
    }));
  }
  
  async getCourseData(courseName: string): Promise<CursoModel[]> {
    if (!courseName) {
      throw new Error('Nome do curso não informado');
    }
    
    const response = await api.get<any[]>(
      `/fluxograma/fluxograma?nome_curso=${encodeURIComponent(courseName)}`
    );
    
    return response.map(this.parseCursoModel);
  }
  
  async getMateriaData(idMateria: number): Promise<MateriaModel> {
    const response = await api.get<any>(`/materias/${idMateria}`);
    return this.parseMateriaModel(response);
  }
  
  async deleteFluxogramaUser(userId: string, token: string): Promise<void> {
    await api.delete('/fluxograma/delete-fluxograma', {
      headers: {
        'user-id': userId,
        'Authorization': `Bearer ${token}`,
      },
    });
  }
  
  private parseCursoModel(json: any): CursoModel {
    const materias = (json.materias_por_curso || []).map((m: any) => ({
      ementa: m.materias?.ementa || m.ementa,
      idMateria: m.materias?.id_materia || m.id_materia,
      nomeMateria: m.materias?.nome_materia || m.nome_materia,
      codigoMateria: m.materias?.codigo_materia || m.codigo_materia,
      creditos: (m.materias?.carga_horaria || m.carga_horaria) / 15,
      nivel: m.nivel || 0,
      preRequisitos: [],
    }));
    
    const preRequisitos = (json.pre_requisitos || []).map((pr: any) => ({
      idPreRequisito: pr.id_pre_requisito,
      idMateria: pr.id_materia,
      idMateriaRequisito: pr.id_materia_requisito,
      codigoMateriaRequisito: pr.codigo_materia_requisito,
      nomeMateriaRequisito: pr.nome_materia_requisito,
    }));
    
    const coRequisitos = (json.co_requisitos || []).map((cr: any) => ({
      idCoRequisito: cr.id_co_requisito,
      idMateria: cr.id_materia,
      idMateriaCoRequisito: cr.id_materia_corequisito,
      codigoMateriaCoRequisito: cr.codigo_materia_corequisito,
      nomeMateriaCoRequisito: cr.nome_materia_corequisito,
    }));
    
    const equivalencias = (json.equivalencias || []).map((eq: any) => ({
      idEquivalencia: eq.id_equivalencia,
      codigoMateriaOrigem: eq.codigo_materia_origem,
      codigoMateriaEquivalente: eq.codigo_materia_equivalente,
      nomeMateriaEquivalente: eq.nome_materia_equivalente,
    }));
    
    const maxSemestre = Math.max(...materias.map((m: any) => m.nivel || 0), 0);
    
    return {
      nomeCurso: json.nome_curso,
      matrizCurricular: json.matriz_curricular,
      idCurso: json.id_curso,
      totalCreditos: json.creditos,
      tipoCurso: json.tipo_curso,
      classificacao: json.classificacao,
      materias,
      semestres: maxSemestre,
      equivalencias,
      preRequisitos,
      coRequisitos,
    };
  }
  
  private parseMateriaModel(json: any): MateriaModel {
    return {
      ementa: json.ementa,
      idMateria: json.id_materia,
      nomeMateria: json.nome_materia,
      codigoMateria: json.codigo_materia,
      creditos: json.carga_horaria / 15,
      nivel: json.nivel || 0,
      preRequisitos: [],
    };
  }
}

export const fluxogramaService = new FluxogramaService();
```

---

## 14. Implementation Checklist

> **STATUS: ✅ IMPLEMENTED** — All fluxograma components, store, and pages are complete.

### Phase 1: Core Infrastructure
- [x] Create TypeScript type definitions
- [x] Implement fluxograma service API calls
- [x] Create fluxograma store with state management
- [x] Set up routes (`/fluxogramas`, `/fluxogramas/[courseName]`, `/meu-fluxograma`)

### Phase 2: Basic Visualization
- [x] FluxogramasIndexScreen - course listing page
- [x] SemesterColumn component - layout structure
- [x] SubjectCard component - styled course cards
- [x] FluxogramContainer - basic scrollable container

### Phase 3: Interactive Features
- [x] Zoom controls (slider + buttons)
- [x] Pan/drag navigation
- [x] Subject card click handlers
- [x] Hover effects and animations

### Phase 4: Connection Lines
- [x] PrerequisiteConnections SVG component
- [x] Build prerequisite/dependent maps
- [x] Draw curved bezier paths
- [x] Arrow markers for direction
- [x] Color coding (purple prerequisite, teal dependent, green co-requisite)

### Phase 5: Modals & Dialogs
- [x] SubjectDetailsModal with tabs
- [x] OptativasModal for elective selection  
- [x] Progress summary section

### Phase 6: Advanced Features
- [x] Screenshot export with html2canvas
- [x] User progress integration
- [x] Equivalencies handling
- [x] Legend and controls panel

### Phase 7: Performance & Polish
- [ ] Optimize SVG rendering for large curricula
- [x] Add loading states and error handling
- [ ] Mobile responsive adjustments (needs manual testing)
- [x] Accessibility improvements (ARIA labels, keyboard nav)

---

## 15. Dependency Installation

```bash
# Required packages
npm install d3 html2canvas

# Type definitions
npm install -D @types/d3

# Optional: panzoom for simpler pan/zoom
npm install panzoom
```

---

## 16. Key Differences from Flutter

| Flutter | SvelteKit | Notes |
|---------|-----------|-------|
| `CustomPaint` for lines | SVG `<path>` elements | More flexible, CSS-stylable |
| `InteractiveViewer` | CSS transform + drag events | Simpler implementation |
| `GlobalKey` for positions | `data-*` attributes + `getBoundingClientRect()` | Different positioning approach |
| `Screenshot` package | `html2canvas` library | Similar concept, web-native |
| `ScrollController` | Native scroll APIs | Less boilerplate needed |
| `FutureBuilder` | `{#await}` blocks | Cleaner syntax |
| `StatefulWidget` | Svelte reactive statements | Less code overall |

---

## 17. Performance Considerations

1. **Virtualization**: For very large curricula (50+ subjects), consider virtualizing the semester columns
2. **SVG Optimization**: Batch path updates, use `will-change: transform` for animations
3. **Lazy Loading**: Load course data only when navigating to fluxograma page
4. **Memoization**: Cache computed prerequisite chains
5. **Debouncing**: Debounce zoom/pan events for smoother interaction

---

## Notes

This is the most complex feature in the application. Consider implementing in phases:

1. Start with basic grid layout without connections
2. Add static connection lines
3. Implement interactive hover/select states
4. Add zoom/pan functionality
5. Finally, add screenshot and advanced features

The recommended approach uses SVG for connection lines as it provides better CSS integration and debugging compared to Canvas.
