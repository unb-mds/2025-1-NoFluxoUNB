# 10 - PDF Upload Feature Migration

This document covers the migration of the PDF Upload (Upload Histórico) feature from Flutter to SvelteKit.

## Overview

The PDF Upload feature allows students to upload their academic transcript (histórico acadêmico) PDF from SIGAA, extract course data, match disciplines with the database, and generate a personalized flowchart. Key features include:
- Drag-and-drop file upload with file picker fallback
- PDF file validation (type and size)
- Upload progress indicator
- Backend processing with discipline matching
- Course selection modal when multiple matches found
- Results display with found/not found disciplines
- Save to database and navigate to flowchart

---

## 1. Page Layout

### Flutter Source Analysis

The Flutter implementation uses:
- `AnimatedBackground` with floating colored circles
- `AppNavbar` for navigation
- Centered upload container with dotted border
- Help button below the upload area
- Results section showing processed disciplines

### SvelteKit Implementation

**File: `src/routes/upload-historico/+page.svelte`**

```svelte
<script lang="ts">
  import { goto } from '$app/navigation';
  import AnimatedBackground from '$lib/components/AnimatedBackground.svelte';
  import Navbar from '$lib/components/Navbar.svelte';
  import FileDropzone from '$lib/components/upload/FileDropzone.svelte';
  import UploadProgress from '$lib/components/upload/UploadProgress.svelte';
  import UploadSuccess from '$lib/components/upload/UploadSuccess.svelte';
  import ProcessingResults from '$lib/components/upload/ProcessingResults.svelte';
  import HelpButton from '$lib/components/upload/HelpButton.svelte';
  import HelpModal from '$lib/components/upload/HelpModal.svelte';
  import CourseSelectionModal from '$lib/components/upload/CourseSelectionModal.svelte';
  import { uploadStore, type UploadState } from '$lib/stores/uploadStore';
  import { toastStore } from '$lib/stores/toastStore';

  let showHelpModal = false;
  let showCourseModal = false;
  let courseSelectionData: { message: string; cursos: any[]; keywords?: string[] } | null = null;

  // Reactive state from store
  $: uploadState = $uploadStore.state;
  $: progress = $uploadStore.progress;
  $: fileName = $uploadStore.fileName;
  $: disciplinasCasadas = $uploadStore.disciplinasCasadas;
  $: dadosValidacao = $uploadStore.dadosValidacao;
  $: materiasOptativas = $uploadStore.materiasOptativas;

  function handleCourseSelectionRequired(event: CustomEvent) {
    courseSelectionData = event.detail;
    showCourseModal = true;
  }

  async function handleCourseSelected(event: CustomEvent) {
    showCourseModal = false;
    const selectedCourse = event.detail;
    await uploadStore.retryWithSelectedCourse(selectedCourse);
  }

  function handleCourseSelectionCancelled() {
    showCourseModal = false;
    uploadStore.reset();
  }
</script>

<svelte:head>
  <title>Upload Histórico | NoFluxoUNB</title>
</svelte:head>

<div class="upload-page">
  <AnimatedBackground />
  
  <div class="content-wrapper">
    <Navbar />
    
    <main class="main-content">
      <div class="upload-container">
        {#if uploadState === 'initial'}
          <FileDropzone 
            on:courseSelectionRequired={handleCourseSelectionRequired}
          />
        {:else if uploadState === 'uploading'}
          <UploadProgress {progress} />
        {:else if uploadState === 'success'}
          <UploadSuccess 
            {fileName}
            on:continue={() => goto('/meu-fluxograma')}
            on:reset={() => uploadStore.reset()}
          />
        {/if}
      </div>

      {#if uploadState === 'initial'}
        <HelpButton on:click={() => showHelpModal = true} />
      {/if}

      {#if disciplinasCasadas && disciplinasCasadas.length > 0}
        <ProcessingResults 
          {disciplinasCasadas}
          {dadosValidacao}
          {materiasOptativas}
        />
      {/if}
    </main>
  </div>
</div>

<HelpModal bind:open={showHelpModal} />

<CourseSelectionModal 
  bind:open={showCourseModal}
  data={courseSelectionData}
  on:select={handleCourseSelected}
  on:cancel={handleCourseSelectionCancelled}
/>

<style>
  .upload-page {
    position: relative;
    min-height: 100vh;
    background-color: #000;
  }

  .content-wrapper {
    position: relative;
    z-index: 1;
    display: flex;
    flex-direction: column;
    min-height: 100vh;
  }

  .main-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 32px 16px;
    gap: 32px;
  }

  .upload-container {
    width: 100%;
    max-width: 700px;
  }

  @media (max-width: 600px) {
    .main-content {
      padding: 16px;
      gap: 24px;
    }

    .upload-container {
      max-width: 100%;
    }
  }
</style>
```

---

## 2. File Picker with Drag-and-Drop

### Flutter Source Analysis

The Flutter implementation uses:
- `FilePicker.platform.pickFiles()` with `allowedExtensions: ['pdf']`
- `MouseRegion` for hover detection
- `DottedBorder` package for visual styling
- Pulse animation on upload icon

### SvelteKit Implementation

**File: `src/lib/components/upload/FileDropzone.svelte`**

```svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { uploadStore } from '$lib/stores/uploadStore';
  import { toastStore } from '$lib/stores/toastStore';
  import { scale, fade } from 'svelte/transition';

  const dispatch = createEventDispatcher();

  let isDragging = false;
  let isHovering = false;
  let fileInput: HTMLInputElement;

  const MAX_FILE_SIZE_MB = 10;
  const ALLOWED_TYPES = ['application/pdf'];
  const ALLOWED_EXTENSIONS = ['.pdf'];

  function validateFile(file: File): { valid: boolean; error?: string } {
    // Check file type
    if (!ALLOWED_TYPES.includes(file.type)) {
      const extension = file.name.split('.').pop()?.toLowerCase();
      if (!extension || !ALLOWED_EXTENSIONS.includes(`.${extension}`)) {
        return { valid: false, error: 'Apenas arquivos PDF são aceitos.' };
      }
    }

    // Check file size
    const fileSizeMB = file.size / (1024 * 1024);
    if (fileSizeMB > MAX_FILE_SIZE_MB) {
      return { 
        valid: false, 
        error: `O arquivo é muito grande. Tamanho máximo: ${MAX_FILE_SIZE_MB}MB` 
      };
    }

    return { valid: true };
  }

  async function handleFile(file: File) {
    const validation = validateFile(file);
    
    if (!validation.valid) {
      toastStore.error(validation.error!);
      return;
    }

    try {
      await uploadStore.uploadFile(file, {
        onCourseSelectionRequired: (data) => {
          dispatch('courseSelectionRequired', data);
        }
      });
    } catch (error) {
      console.error('Erro ao processar arquivo:', error);
      toastStore.error('Erro ao processar o arquivo. Tente novamente.');
    }
  }

  function handleDrop(event: DragEvent) {
    event.preventDefault();
    isDragging = false;

    const files = event.dataTransfer?.files;
    if (files && files.length > 0) {
      handleFile(files[0]);
    }
  }

  function handleDragOver(event: DragEvent) {
    event.preventDefault();
    isDragging = true;
  }

  function handleDragLeave(event: DragEvent) {
    event.preventDefault();
    isDragging = false;
  }

  function handleClick() {
    fileInput?.click();
  }

  function handleFileInput(event: Event) {
    const target = event.target as HTMLInputElement;
    const files = target.files;
    if (files && files.length > 0) {
      handleFile(files[0]);
    }
    // Reset input so same file can be selected again
    target.value = '';
  }

  function handleKeyDown(event: KeyboardEvent) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      handleClick();
    }
  }
</script>

<div 
  class="dropzone"
  class:dragging={isDragging}
  class:hovering={isHovering}
  on:drop={handleDrop}
  on:dragover={handleDragOver}
  on:dragleave={handleDragLeave}
  on:click={handleClick}
  on:keydown={handleKeyDown}
  on:mouseenter={() => isHovering = true}
  on:mouseleave={() => isHovering = false}
  role="button"
  tabindex="0"
  aria-label="Área de upload de arquivo PDF"
>
  <input 
    type="file"
    accept=".pdf,application/pdf"
    bind:this={fileInput}
    on:change={handleFileInput}
    hidden
  />

  <div class="dropzone-content">
    <div class="icon-container" class:pulse={!isDragging}>
      <svg 
        xmlns="http://www.w3.org/2000/svg" 
        viewBox="0 0 24 24" 
        fill="none" 
        stroke="currentColor" 
        stroke-width="2"
        class="upload-icon"
      >
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
        <polyline points="17 8 12 3 7 8" />
        <line x1="12" y1="3" x2="12" y2="15" />
      </svg>
    </div>

    <h2 class="title">
      {#if isDragging}
        Solte o arquivo aqui
      {:else}
        Arraste seu histórico acadêmico aqui
      {/if}
    </h2>

    <span class="divider">ou</span>

    <button 
      class="select-button"
      type="button"
      on:click|stopPropagation={handleClick}
    >
      <svg 
        xmlns="http://www.w3.org/2000/svg" 
        viewBox="0 0 24 24" 
        fill="none" 
        stroke="currentColor" 
        stroke-width="2"
        class="button-icon"
      >
        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
        <polyline points="14 2 14 8 20 8" />
        <line x1="12" y1="18" x2="12" y2="12" />
        <line x1="9" y1="15" x2="15" y2="15" />
      </svg>
      Selecionar Histórico
    </button>

    <p class="hint">Somente arquivos PDF são aceitos</p>
  </div>
</div>

<style>
  .dropzone {
    position: relative;
    padding: 32px;
    border: 2px dashed rgba(255, 255, 255, 0.5);
    border-radius: 16px;
    background-color: rgba(255, 255, 255, 0.15);
    cursor: pointer;
    transition: all 0.3s ease;
  }

  .dropzone:hover,
  .dropzone.hovering {
    border-color: rgba(255, 255, 255, 0.8);
    background-color: rgba(255, 255, 255, 0.25);
    transform: translateY(-5px);
  }

  .dropzone.dragging {
    border-color: #007BFF;
    background-color: rgba(0, 123, 255, 0.2);
    border-style: solid;
  }

  .dropzone-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
  }

  .icon-container {
    width: 80px;
    height: 80px;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: rgba(255, 255, 255, 0.1);
    border-radius: 50%;
  }

  .icon-container.pulse {
    animation: pulse 2s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.05); }
  }

  .upload-icon {
    width: 40px;
    height: 40px;
    color: #fff;
  }

  .title {
    font-size: 24px;
    font-weight: 600;
    color: #fff;
    text-align: center;
    margin: 0;
  }

  .divider {
    font-size: 16px;
    color: rgba(255, 255, 255, 0.7);
  }

  .select-button {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 16px 32px;
    background-color: #007BFF;
    color: #fff;
    border: none;
    border-radius: 8px;
    font-size: 16px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.3s ease;
  }

  .select-button:hover {
    background-color: #0056b3;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 123, 255, 0.4);
  }

  .button-icon {
    width: 20px;
    height: 20px;
  }

  .hint {
    font-size: 14px;
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
  }

  @media (max-width: 600px) {
    .dropzone {
      padding: 24px 16px;
    }

    .icon-container {
      width: 60px;
      height: 60px;
    }

    .upload-icon {
      width: 30px;
      height: 30px;
    }

    .title {
      font-size: 18px;
    }

    .select-button {
      padding: 12px 24px;
      font-size: 14px;
      width: 100%;
      justify-content: center;
    }

    .hint {
      font-size: 12px;
    }
  }
</style>
```

---

## 3. File Validation

### Validation Rules

```typescript
// src/lib/utils/fileValidation.ts

export interface FileValidationResult {
  valid: boolean;
  error?: string;
}

export interface FileValidationOptions {
  maxSizeMB?: number;
  allowedTypes?: string[];
  allowedExtensions?: string[];
}

const DEFAULT_OPTIONS: Required<FileValidationOptions> = {
  maxSizeMB: 10,
  allowedTypes: ['application/pdf'],
  allowedExtensions: ['.pdf']
};

export function validatePdfFile(
  file: File, 
  options: FileValidationOptions = {}
): FileValidationResult {
  const config = { ...DEFAULT_OPTIONS, ...options };

  // Check if file exists
  if (!file) {
    return { valid: false, error: 'Nenhum arquivo selecionado.' };
  }

  // Check file name
  if (!file.name || file.name.trim() === '') {
    return { valid: false, error: 'Nome do arquivo inválido.' };
  }

  // Check file type by MIME type
  const isValidMimeType = config.allowedTypes.includes(file.type);
  
  // Check file type by extension (fallback)
  const extension = `.${file.name.split('.').pop()?.toLowerCase()}`;
  const isValidExtension = config.allowedExtensions.includes(extension);

  if (!isValidMimeType && !isValidExtension) {
    return { 
      valid: false, 
      error: 'Tipo de arquivo não suportado. Apenas arquivos PDF são aceitos.' 
    };
  }

  // Check file size
  const fileSizeMB = file.size / (1024 * 1024);
  if (fileSizeMB > config.maxSizeMB) {
    return { 
      valid: false, 
      error: `O arquivo é muito grande (${fileSizeMB.toFixed(1)}MB). Tamanho máximo: ${config.maxSizeMB}MB` 
    };
  }

  // Check if file is empty
  if (file.size === 0) {
    return { valid: false, error: 'O arquivo está vazio.' };
  }

  return { valid: true };
}
```

---

## 4. Upload Progress

### Flutter Source Analysis

The Flutter implementation uses:
- `LinearProgressIndicator` with animated gradient
- Progress percentage text display
- Animated gradient that moves across the progress bar

### SvelteKit Implementation

**File: `src/lib/components/upload/UploadProgress.svelte`**

```svelte
<script lang="ts">
  export let progress: number = 0;
  
  $: displayProgress = Math.min(100, Math.max(0, progress));
  $: progressText = `${Math.round(displayProgress)}%`;
</script>

<div class="progress-container">
  <h3 class="title">Processando seu histórico...</h3>
  
  <div class="progress-bar-container">
    <div class="progress-bar">
      <div 
        class="progress-fill"
        style="width: {displayProgress}%"
      >
        <div class="gradient-animation"></div>
      </div>
    </div>
  </div>
  
  <span class="progress-text">{progressText}</span>
</div>

<style>
  .progress-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 24px;
    padding: 32px;
    border: 2px dashed rgba(255, 255, 255, 0.5);
    border-radius: 16px;
    background-color: rgba(255, 255, 255, 0.15);
  }

  .title {
    font-size: 20px;
    font-weight: 600;
    color: #fff;
    margin: 0;
    text-align: center;
  }

  .progress-bar-container {
    width: 100%;
    max-width: 400px;
  }

  .progress-bar {
    width: 100%;
    height: 16px;
    background-color: rgba(255, 255, 255, 0.2);
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.1);
  }

  .progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #007BFF, #00C6FF);
    border-radius: 8px;
    transition: width 0.3s ease;
    position: relative;
    overflow: hidden;
  }

  .gradient-animation {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(
      90deg,
      transparent 0%,
      rgba(255, 255, 255, 0.3) 50%,
      transparent 100%
    );
    animation: shimmer 2s linear infinite;
  }

  @keyframes shimmer {
    0% { transform: translateX(-100%); }
    100% { transform: translateX(100%); }
  }

  .progress-text {
    font-size: 16px;
    font-weight: 500;
    color: #fff;
  }

  @media (max-width: 600px) {
    .progress-container {
      padding: 24px 16px;
      gap: 16px;
    }

    .title {
      font-size: 16px;
    }

    .progress-bar {
      height: 12px;
    }

    .progress-text {
      font-size: 14px;
    }
  }
</style>
```

---

## 5. Upload Service

> **⚡ ALREADY IMPLEMENTED:** The upload service has been created at `src/lib/services/upload.service.ts` as part of plan 14 (Supabase Direct + RLS). It uses a **hybrid approach**: `uploadPdf()` and `casarDisciplinas()` still call the backend API, while `saveFluxogramaToDB()` uses direct Supabase queries. See [14-SUPABASE-DIRECT-RLS.md](14-SUPABASE-DIRECT-RLS.md). The code below is kept for reference but the actual implementation is already in place.

### Flutter Source Analysis

The Flutter service uses:
- `http.MultipartRequest` for file upload
- `dartz` `Either` for result/error handling
- Three main methods: `uploadPdfBytes`, `casarDisciplinas`, `uploadFluxogramaToDB`

### SvelteKit Implementation

**File: `src/lib/services/uploadService.ts`**

```typescript
import { Result, ok, err } from '$lib/utils/result';
import { apiClient } from '$lib/api/client';
import type { 
  DadosExtraidos, 
  DisciplinaCasada, 
  DadosValidacao,
  DadosFluxogramaUser,
  CursoDisponivel
} from '$lib/types/upload';

export interface UploadPdfResponse {
  extracted_data: any[];
  curso_extraido: string;
  matriz_curricular: string;
  matricula: string;
  media_ponderada: number;
  frequencia_geral: number;
  numero_semestre: number;
  semestre_atual: string;
  suspensoes: string[];
}

export interface CasarDisciplinasResponse {
  disciplinas_casadas: DisciplinaCasada[];
  materias_concluidas: any[];
  materias_pendentes: any[];
  materias_optativas: any[];
  resumo: {
    percentual_conclusao_obrigatorias: number;
    total_disciplinas: number;
    total_obrigatorias_concluidas: number;
    total_obrigatorias_pendentes: number;
    total_optativas: number;
  };
  dados_validacao: DadosValidacao;
}

export interface CourseSelectionError {
  type: 'COURSE_SELECTION';
  message: string;
  cursos_disponiveis: CursoDisponivel[];
  palavras_chave_encontradas?: string[];
}

/**
 * Upload PDF file to backend for parsing
 */
export async function uploadPdfBytes(
  file: File
): Promise<Result<UploadPdfResponse, string>> {
  try {
    console.log('Uploading PDF:', file.name);
    
    const formData = new FormData();
    formData.append('pdf', file, file.name);

    const response = await fetch(`${import.meta.env.VITE_API_URL}/fluxograma/read_pdf`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error('Error uploading PDF:', response.status, errorBody);
      
      try {
        const errorData = JSON.parse(errorBody);
        return err(errorData.error || `Erro ao fazer upload do PDF: ${response.status}`);
      } catch {
        return err(`Erro ao fazer upload do PDF: ${response.status}`);
      }
    }

    const data = await response.json();
    console.log('PDF processed successfully');
    console.log('Extracted data:', data.extracted_data?.length ?? 0, 'items');
    console.log('Course extracted:', data.curso_extraido);

    return ok(data);
  } catch (error) {
    console.error('Exception while uploading PDF:', error);
    return err(`Erro ao fazer upload do PDF: ${error}`);
  }
}

/**
 * Match extracted disciplines with database
 */
export async function casarDisciplinas(
  dadosExtraidos: DadosExtraidos
): Promise<Result<CasarDisciplinasResponse, string | CourseSelectionError>> {
  try {
    console.log('Starting discipline matching...');
    console.log('Extracted data:', dadosExtraidos.extracted_data?.length ?? 0, 'disciplines');

    const response = await fetch(`${import.meta.env.VITE_API_URL}/fluxograma/casar_disciplinas`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ dados_extraidos: dadosExtraidos }),
    });

    console.log('Response status:', response.statusCode);

    if (!response.ok) {
      const errorBody = await response.text();
      console.warn('Error response:', response.status, errorBody);

      try {
        const errorData = JSON.parse(errorBody);

        // Check if it's a course selection error
        if (errorData.cursos_disponiveis) {
          console.log('Course selection error:', errorData.message);
          return err({
            type: 'COURSE_SELECTION',
            message: errorData.message,
            cursos_disponiveis: errorData.cursos_disponiveis,
            palavras_chave_encontradas: errorData.palavras_chave_encontradas,
          } as CourseSelectionError);
        }

        return err(errorData.error || `Erro ao processar disciplinas: ${response.status}`);
      } catch {
        return err(`Erro ao processar disciplinas: ${response.status}`);
      }
    }

    const resultado = await response.json();
    console.log('Backend response received successfully');
    logResultadoDetalhado(resultado);

    return ok(resultado);
  } catch (error) {
    console.error('Exception while matching disciplines:', error);
    return err(`Erro ao processar disciplinas: ${error}`);
  }
}

/**
 * Save flowchart data to database
 */
export async function uploadFluxogramaToDB(
  dadosFluxograma: DadosFluxogramaUser,
  authToken: string
): Promise<Result<string, string>> {
  try {
    console.log('Saving flowchart to database...');

    const requestBody = {
      fluxograma: dadosFluxograma,
      periodo_letivo: dadosFluxograma.semestreAtual,
    };

    const response = await fetch(`${import.meta.env.VITE_API_URL}/fluxograma/upload-dados-fluxograma`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`,
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error('Error saving flowchart:', response.status, errorBody);

      try {
        const errorData = JSON.parse(errorBody);
        return err(errorData.error || `Erro ao salvar fluxograma: ${response.status}`);
      } catch {
        return err(`Erro ao salvar fluxograma: ${response.status}`);
      }
    }

    console.log('Flowchart saved successfully');
    return ok('Fluxograma salvo com sucesso');
  } catch (error) {
    console.error('Exception while saving flowchart:', error);
    return err(`Erro ao salvar fluxograma: ${error}`);
  }
}

/**
 * Log detailed discipline matching results
 */
function logResultadoDetalhado(resultado: CasarDisciplinasResponse): void {
  console.log('=== DISCIPLINE MATCHING RESULTS ===');
  console.log('Total matched disciplines:', resultado.disciplinas_casadas?.length ?? 0);
  console.log('Completed mandatory subjects:', resultado.materias_concluidas?.length ?? 0);
  console.log('Pending mandatory subjects:', resultado.materias_pendentes?.length ?? 0);
  console.log('Elective subjects:', resultado.materias_optativas?.length ?? 0);

  if (resultado.resumo) {
    console.log('Completion percentage:', resultado.resumo.percentual_conclusao_obrigatorias?.toFixed(1) ?? 'N/A', '%');
    console.log('Total disciplines in transcript:', resultado.resumo.total_disciplinas ?? 0);
  }

  if (resultado.dados_validacao) {
    console.log('=== VALIDATION DATA ===');
    console.log('IRA:', resultado.dados_validacao.ira ?? 'N/A');
    console.log('Weighted average:', resultado.dados_validacao.media_ponderada ?? 'N/A');
    console.log('Integrated hours:', resultado.dados_validacao.horas_integralizadas ?? 0, 'h');
  }
}
```

---

## 6. Processing Flow

### Upload Store

**File: `src/lib/stores/uploadStore.ts`**

```typescript
import { writable, derived } from 'svelte/store';
import { 
  uploadPdfBytes, 
  casarDisciplinas, 
  uploadFluxogramaToDB,
  type UploadPdfResponse,
  type CasarDisciplinasResponse,
  type CourseSelectionError
} from '$lib/services/uploadService';
import { authStore } from '$lib/stores/authStore';
import type { DisciplinaCasada, DadosValidacao, DadosFluxogramaUser, DadosMateria } from '$lib/types/upload';

export type UploadState = 'initial' | 'uploading' | 'processing' | 'success' | 'error';

interface UploadStoreState {
  state: UploadState;
  progress: number;
  fileName: string | null;
  dadosExtraidos: UploadPdfResponse | null;
  disciplinasCasadas: DisciplinaCasada[] | null;
  dadosValidacao: DadosValidacao | null;
  materiasOptativas: any[] | null;
  error: string | null;
}

const initialState: UploadStoreState = {
  state: 'initial',
  progress: 0,
  fileName: null,
  dadosExtraidos: null,
  disciplinasCasadas: null,
  dadosValidacao: null,
  materiasOptativas: null,
  error: null,
};

function createUploadStore() {
  const { subscribe, set, update } = writable<UploadStoreState>(initialState);

  return {
    subscribe,

    reset: () => set(initialState),

    /**
     * Main upload flow:
     * 1. uploadPdfBytes - send PDF to backend
     * 2. casarDisciplinas - match subjects with database
     * 3. Animate progress
     * 4. Set success state
     */
    uploadFile: async (
      file: File,
      options?: {
        onCourseSelectionRequired?: (data: CourseSelectionError) => void;
      }
    ) => {
      update(s => ({ 
        ...s, 
        state: 'uploading', 
        progress: 0, 
        fileName: file.name,
        error: null 
      }));

      // Step 1: Upload PDF
      const uploadResult = await uploadPdfBytes(file);

      if (!uploadResult.ok) {
        update(s => ({ 
          ...s, 
          state: 'error', 
          error: uploadResult.error 
        }));
        throw new Error(uploadResult.error);
      }

      const dadosExtraidos = uploadResult.value;
      update(s => ({ ...s, dadosExtraidos, progress: 30 }));

      // Step 2: Match disciplines
      const casarResult = await casarDisciplinas(dadosExtraidos);

      if (!casarResult.ok) {
        // Check if it's a course selection error
        if (typeof casarResult.error === 'object' && casarResult.error.type === 'COURSE_SELECTION') {
          options?.onCourseSelectionRequired?.(casarResult.error);
          update(s => ({ ...s, state: 'initial', progress: 0 }));
          return;
        }

        update(s => ({ 
          ...s, 
          state: 'error', 
          error: casarResult.error as string 
        }));
        throw new Error(casarResult.error as string);
      }

      const resultado = casarResult.value;
      update(s => ({
        ...s,
        disciplinasCasadas: resultado.disciplinas_casadas,
        dadosValidacao: resultado.dados_validacao,
        materiasOptativas: resultado.materias_optativas,
        progress: 60,
      }));

      // Step 3: Animate progress to 100%
      await simulateProgress(60, 100);

      // Step 4: Success
      update(s => ({ ...s, state: 'success', progress: 100 }));
    },

    /**
     * Retry discipline matching with selected course
     */
    retryWithSelectedCourse: async (selectedCourse: { nome_curso: string; matriz_curricular: string }) => {
      let currentState: UploadStoreState;
      const unsubscribe = subscribe(s => currentState = s);
      unsubscribe();

      if (!currentState!.dadosExtraidos) {
        console.error('No extracted data available');
        return;
      }

      // Update extracted data with selected course
      const updatedDados = {
        ...currentState!.dadosExtraidos,
        curso_extraido: selectedCourse.nome_curso,
        matriz_curricular: selectedCourse.matriz_curricular,
      };

      update(s => ({ 
        ...s, 
        state: 'uploading', 
        progress: 30,
        dadosExtraidos: updatedDados 
      }));

      // Retry matching
      const casarResult = await casarDisciplinas(updatedDados);

      if (!casarResult.ok) {
        const errorMsg = typeof casarResult.error === 'string' 
          ? casarResult.error 
          : casarResult.error.message;
        update(s => ({ 
          ...s, 
          state: 'error', 
          error: errorMsg 
        }));
        throw new Error(errorMsg);
      }

      const resultado = casarResult.value;
      update(s => ({
        ...s,
        disciplinasCasadas: resultado.disciplinas_casadas,
        dadosValidacao: resultado.dados_validacao,
        materiasOptativas: resultado.materias_optativas,
        progress: 60,
      }));

      await simulateProgress(60, 100);
      update(s => ({ ...s, state: 'success', progress: 100 }));
    },

    /**
     * Save flowchart to database and navigate
     */
    saveToDatabase: async (): Promise<boolean> => {
      let currentState: UploadStoreState;
      const unsubscribe = subscribe(s => currentState = s);
      unsubscribe();

      if (!currentState!.dadosExtraidos || !currentState!.disciplinasCasadas || !currentState!.dadosValidacao) {
        console.error('Missing data for saving flowchart');
        return false;
      }

      // Build flowchart data structure
      const dadosFluxograma: DadosFluxogramaUser = {
        nomeCurso: currentState!.dadosValidacao.curso_extraido,
        matricula: currentState!.dadosExtraidos.matricula,
        matrizCurricular: currentState!.dadosExtraidos.matriz_curricular,
        ira: currentState!.dadosExtraidos.media_ponderada,
        suspensoes: currentState!.dadosExtraidos.suspensoes || [],
        semestreAtual: currentState!.dadosExtraidos.numero_semestre,
        anoAtual: currentState!.dadosExtraidos.semestre_atual,
        horasIntegralizadas: currentState!.dadosValidacao.horas_integralizadas,
        dadosFluxograma: buildDadosFluxograma(currentState!.disciplinasCasadas),
      };

      // Get auth token
      let authToken = '';
      const authUnsub = authStore.subscribe(auth => {
        authToken = auth.token || '';
      });
      authUnsub();

      if (!authToken) {
        console.error('No auth token available');
        return false;
      }

      const result = await uploadFluxogramaToDB(dadosFluxograma, authToken);

      if (!result.ok) {
        console.error('Error saving flowchart:', result.error);
        return false;
      }

      console.log('Flowchart saved successfully');
      return true;
    },
  };
}

/**
 * Build the 2D array structure for flowchart data
 */
function buildDadosFluxograma(disciplinasCasadas: DisciplinaCasada[]): DadosMateria[][] {
  // Initialize 20 semesters
  const dadosFluxograma: DadosMateria[][] = Array.from({ length: 20 }, () => []);

  for (const materia of disciplinasCasadas) {
    const nivel = materia.nivel ?? 0;
    
    if (nivel >= 0 && nivel < 20) {
      dadosFluxograma[nivel].push({
        id: materia.id_materia,
        codigo: materia.codigo,
        nome: materia.nome,
        creditos: materia.creditos,
        status: materia.status,
        mencao: materia.mencao,
        professor: materia.professor,
        situacao: materia.situacao,
        carga_horaria: materia.carga_horaria,
        encontrada_no_banco: materia.encontrada_no_banco,
      });
    }
  }

  return dadosFluxograma;
}

/**
 * Simulate progress animation
 */
async function simulateProgress(start: number, end: number): Promise<void> {
  const uploadStoreInstance = uploadStore;
  
  for (let i = start; i <= end; i += 5 + Math.floor(Math.random() * 10)) {
    uploadStoreInstance.subscribe(s => {
      // Do nothing, just trigger update
    })();
    
    // Update would happen here in real implementation
    await new Promise(resolve => setTimeout(resolve, 200 + Math.floor(Math.random() * 300)));
  }
}

export const uploadStore = createUploadStore();
```

---

## 7. Course Selection Modal

### Flutter Source Analysis

The Flutter implementation shows:
- Modal dialog when multiple courses match
- List of available courses with matrix info
- Cancel button to reset

### SvelteKit Implementation

**File: `src/lib/components/upload/CourseSelectionModal.svelte`**

```svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { fade, scale } from 'svelte/transition';
  import { clickOutside } from '$lib/actions/clickOutside';

  export let open = false;
  export let data: {
    message: string;
    cursos: Array<{ nome_curso: string; matriz_curricular?: string }>;
    keywords?: string[];
  } | null = null;

  const dispatch = createEventDispatcher();

  function handleSelect(curso: { nome_curso: string; matriz_curricular?: string }) {
    dispatch('select', curso);
  }

  function handleCancel() {
    dispatch('cancel');
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      handleCancel();
    }
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open && data}
  <div class="modal-overlay" transition:fade={{ duration: 200 }}>
    <div 
      class="modal" 
      transition:scale={{ duration: 200, start: 0.95 }}
      use:clickOutside
      on:clickOutside={handleCancel}
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
    >
      <h2 id="modal-title" class="modal-title">Selecione seu curso</h2>
      
      <p class="modal-message">
        {data.message || 'Por favor, selecione o curso correto:'}
      </p>

      {#if data.keywords && data.keywords.length > 0}
        <p class="keywords-info">
          Palavras-chave encontradas: {data.keywords.join(', ')}
        </p>
      {/if}

      <ul class="course-list">
        {#each data.cursos as curso}
          <li>
            <button 
              type="button"
              class="course-item"
              on:click={() => handleSelect(curso)}
            >
              <span class="course-name">{curso.nome_curso}</span>
              {#if curso.matriz_curricular}
                <span class="course-matrix">Matriz: {curso.matriz_curricular}</span>
              {/if}
            </button>
          </li>
        {/each}
      </ul>

      <div class="modal-actions">
        <button 
          type="button" 
          class="cancel-button"
          on:click={handleCancel}
        >
          Cancelar
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-overlay {
    position: fixed;
    inset: 0;
    background-color: rgba(0, 0, 0, 0.6);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 16px;
  }

  .modal {
    background-color: #fff;
    border-radius: 16px;
    padding: 24px;
    max-width: 500px;
    width: 100%;
    max-height: 80vh;
    overflow-y: auto;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  }

  .modal-title {
    font-size: 18px;
    font-weight: 700;
    color: #1A202C;
    margin: 0 0 16px 0;
  }

  .modal-message {
    font-size: 16px;
    color: #1A202C;
    margin: 0 0 8px 0;
  }

  .keywords-info {
    font-size: 12px;
    color: #666;
    font-style: italic;
    margin: 0 0 16px 0;
  }

  .course-list {
    list-style: none;
    padding: 0;
    margin: 0 0 24px 0;
    max-height: 300px;
    overflow-y: auto;
  }

  .course-item {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
    width: 100%;
    padding: 16px;
    border: none;
    background-color: #f7f7f7;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s ease;
    text-align: left;
    margin-bottom: 8px;
  }

  .course-item:hover {
    background-color: #e8f4ff;
    transform: translateX(4px);
  }

  .course-item:focus {
    outline: 2px solid #007BFF;
    outline-offset: 2px;
  }

  .course-name {
    font-size: 16px;
    font-weight: 500;
    color: #1A202C;
  }

  .course-matrix {
    font-size: 14px;
    color: #666;
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
  }

  .cancel-button {
    padding: 10px 20px;
    background: none;
    border: none;
    color: #666;
    font-size: 16px;
    cursor: pointer;
    border-radius: 8px;
    transition: all 0.2s ease;
  }

  .cancel-button:hover {
    background-color: #f0f0f0;
    color: #333;
  }

  @media (max-width: 600px) {
    .modal {
      padding: 20px;
    }

    .modal-title {
      font-size: 16px;
    }

    .modal-message {
      font-size: 14px;
    }

    .course-item {
      padding: 12px;
    }

    .course-name {
      font-size: 14px;
    }

    .course-matrix {
      font-size: 12px;
    }
  }
</style>
```

---

## 8. Results Display

### Flutter Source Analysis

The Flutter implementation displays:
- Total disciplines processed
- Found vs not found counts
- Elective subjects count
- Validation data (IRA, course, matrix, hours)
- Expandable lists for found/not found disciplines

### SvelteKit Implementation

**File: `src/lib/components/upload/ProcessingResults.svelte`**

```svelte
<script lang="ts">
  import type { DisciplinaCasada, DadosValidacao } from '$lib/types/upload';
  import DisciplinaList from './DisciplinaList.svelte';

  export let disciplinasCasadas: DisciplinaCasada[];
  export let dadosValidacao: DadosValidacao | null;
  export let materiasOptativas: any[] | null;

  $: disciplinasEncontradas = disciplinasCasadas.filter(d => 
    d.encontrada_no_banco === true || d.encontrada_no_banco === 'true'
  );
  
  $: disciplinasNaoEncontradas = disciplinasCasadas.filter(d => 
    d.encontrada_no_banco === false || d.encontrada_no_banco === 'false'
  );

  $: disciplinasComProfessor = disciplinasCasadas.filter(d => 
    d.professor && d.professor.toString().trim() !== ''
  );
</script>

<div class="results-container">
  <h3 class="results-title">📊 Resultado do Processamento:</h3>

  <div class="stats-grid">
    <div class="stat-item">
      <span class="stat-icon">📋</span>
      <span class="stat-text">Total de disciplinas processadas: <strong>{disciplinasCasadas.length}</strong></span>
    </div>

    <div class="stat-item success">
      <span class="stat-icon">✅</span>
      <span class="stat-text">Disciplinas encontradas no banco: <strong>{disciplinasEncontradas.length}</strong></span>
    </div>

    <div class="stat-item warning">
      <span class="stat-icon">❌</span>
      <span class="stat-text">Disciplinas não encontradas: <strong>{disciplinasNaoEncontradas.length}</strong></span>
    </div>

    {#if materiasOptativas}
      <div class="stat-item purple">
        <span class="stat-icon">🎯</span>
        <span class="stat-text">Matérias optativas: <strong>{materiasOptativas.length}</strong></span>
      </div>
    {/if}

    <div class="stat-item indigo">
      <span class="stat-icon">👨‍🏫</span>
      <span class="stat-text">Disciplinas com professor: <strong>{disciplinasComProfessor.length}</strong></span>
    </div>
  </div>

  {#if dadosValidacao}
    <div class="validation-section">
      <div class="validation-item cyan">
        <span>🎓 Curso:</span>
        <strong>{dadosValidacao.curso_extraido ?? 'N/A'}</strong>
      </div>

      <div class="validation-item cyan">
        <span>📋 Matriz:</span>
        <strong>{dadosValidacao.matriz_curricular ?? 'N/A'}</strong>
      </div>

      <div class="validation-item blue">
        <span>📊 IRA:</span>
        <strong>{dadosValidacao.ira?.toFixed(2) ?? 'N/A'}</strong>
      </div>

      <div class="validation-item blue">
        <span>📈 Média ponderada:</span>
        <strong>{dadosValidacao.media_ponderada?.toFixed(2) ?? 'N/A'}</strong>
      </div>

      <div class="validation-item blue">
        <span>📊 Frequência:</span>
        <strong>{dadosValidacao.frequencia_geral?.toFixed(2) ?? 'N/A'}%</strong>
      </div>

      <div class="validation-item blue">
        <span>⏱️ Horas integralizadas:</span>
        <strong>{dadosValidacao.horas_integralizadas}h</strong>
      </div>

      {#if dadosValidacao.pendencias && Array.isArray(dadosValidacao.pendencias) && dadosValidacao.pendencias.length > 0}
        <div class="validation-item warning">
          <span>⚠️ Pendências:</span>
          <strong>{dadosValidacao.pendencias.join(', ')}</strong>
        </div>
      {/if}
    </div>
  {/if}

  {#if disciplinasEncontradas.length > 0}
    <DisciplinaList 
      titulo="✅ Disciplinas Encontradas ({disciplinasEncontradas.length})"
      disciplinas={disciplinasEncontradas}
      tipo="encontradas"
    />
  {/if}

  {#if disciplinasNaoEncontradas.length > 0}
    <DisciplinaList 
      titulo="❌ Disciplinas Não Encontradas ({disciplinasNaoEncontradas.length})"
      disciplinas={disciplinasNaoEncontradas}
      tipo="nao-encontradas"
    />
  {/if}

  <div class="tips-section">
    <p class="tip">💡 Dica: Verifique o console para mais detalhes</p>
    <p class="tip success">🎯 Processamento automático: Curso e matriz extraídos do PDF</p>
  </div>
</div>

<style>
  .results-container {
    width: 100%;
    max-width: 900px;
    padding: 16px;
    background-color: rgba(255, 255, 255, 0.1);
    border-radius: 12px;
  }

  .results-title {
    color: #fff;
    font-size: 18px;
    font-weight: 700;
    margin: 0 0 16px 0;
  }

  .stats-grid {
    display: flex;
    flex-direction: column;
    gap: 4px;
    margin-bottom: 16px;
  }

  .stat-item {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #fff;
    font-size: 14px;
  }

  .stat-item.success { color: #4ade80; }
  .stat-item.warning { color: #fb923c; }
  .stat-item.purple { color: #c084fc; }
  .stat-item.indigo { color: #818cf8; }

  .stat-icon {
    flex-shrink: 0;
  }

  .validation-section {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 8px;
    margin-bottom: 16px;
    padding: 12px;
    background-color: rgba(255, 255, 255, 0.05);
    border-radius: 8px;
  }

  .validation-item {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
  }

  .validation-item.cyan { color: #22d3ee; }
  .validation-item.blue { color: #60a5fa; }
  .validation-item.warning { color: #fb923c; }

  .tips-section {
    margin-top: 16px;
  }

  .tip {
    font-size: 12px;
    color: rgba(255, 255, 255, 0.7);
    margin: 4px 0;
  }

  .tip.success {
    color: #4ade80;
    font-weight: 500;
  }

  @media (max-width: 600px) {
    .results-container {
      padding: 12px;
    }

    .results-title {
      font-size: 16px;
    }

    .stat-item {
      font-size: 12px;
    }

    .validation-section {
      grid-template-columns: 1fr;
    }
  }
</style>
```

**File: `src/lib/components/upload/DisciplinaList.svelte`**

```svelte
<script lang="ts">
  import { slide } from 'svelte/transition';
  import type { DisciplinaCasada } from '$lib/types/upload';

  export let titulo: string;
  export let disciplinas: DisciplinaCasada[];
  export let tipo: 'encontradas' | 'nao-encontradas';

  let expanded = false;

  // Sort by nivel
  $: sortedDisciplinas = [...disciplinas].sort((a, b) => {
    const nivelA = a.nivel ?? 0;
    const nivelB = b.nivel ?? 0;
    return nivelA - nivelB;
  });

  $: headerColor = tipo === 'encontradas' ? '#4ade80' : '#fb923c';
</script>

<div class="list-container">
  <button 
    type="button"
    class="list-header"
    on:click={() => expanded = !expanded}
    aria-expanded={expanded}
    style="--header-color: {headerColor}"
  >
    <span class="header-title">{titulo}</span>
    <svg 
      class="chevron"
      class:rotated={expanded}
      xmlns="http://www.w3.org/2000/svg" 
      viewBox="0 0 24 24" 
      fill="none" 
      stroke="currentColor" 
      stroke-width="2"
    >
      <polyline points="6 9 12 15 18 9" />
    </svg>
  </button>

  {#if expanded}
    <div class="list-content" transition:slide={{ duration: 200 }}>
      {#each sortedDisciplinas as disciplina}
        <div class="disciplina-card">
          <div class="disciplina-header">
            <span class="codigo">{disciplina.codigo ?? 'S/CÓDIGO'}</span>
            <span class="nome">{disciplina.nome ?? 'Nome não disponível'}</span>
          </div>

          {#if disciplina.situacao}
            <div class="disciplina-row">
              <span class="label">Situação:</span>
              <span 
                class="value"
                class:aprovado={disciplina.situacao.toLowerCase().includes('aprovado')}
              >
                {disciplina.situacao}
              </span>
            </div>
          {/if}

          <div class="disciplina-meta">
            {#if disciplina.creditos != null}
              <span class="meta-item">Créditos: {disciplina.creditos}</span>
            {/if}
            {#if disciplina.nivel != null}
              <span class="meta-item">
                Nível: {disciplina.nivel === 0 ? 'Optativa' : disciplina.nivel}
              </span>
            {/if}
            {#if disciplina.mencao}
              <span class="meta-item">Menção: {disciplina.mencao}</span>
            {/if}
          </div>

          {#if disciplina.professor}
            <div class="disciplina-row">
              <span class="label">Professor:</span>
              <span class="value">{disciplina.professor}</span>
            </div>
          {/if}

          {#if disciplina.ano_periodo}
            <div class="disciplina-row">
              <span class="label">Ano/Período:</span>
              <span class="value">{disciplina.ano_periodo}</span>
            </div>
          {/if}

          {#if disciplina.turma}
            <div class="disciplina-row">
              <span class="label">Turma:</span>
              <span class="value">{disciplina.turma}</span>
            </div>
          {/if}

          {#if disciplina.frequencia != null}
            <div class="disciplina-row">
              <span class="label">Frequência:</span>
              <span class="value">{disciplina.frequencia}</span>
            </div>
          {/if}

          {#if disciplina.carga_horaria != null}
            <div class="disciplina-row">
              <span class="label">Carga horária:</span>
              <span class="value">{disciplina.carga_horaria}</span>
            </div>
          {/if}

          {#if disciplina.status}
            <div class="disciplina-row">
              <span class="label">Status:</span>
              <span class="value">{disciplina.status}</span>
            </div>
          {/if}

          {#if tipo === 'nao-encontradas' && disciplina.motivo_nao_encontrada}
            <div class="disciplina-row error">
              <span class="label">Motivo:</span>
              <span class="value">{disciplina.motivo_nao_encontrada}</span>
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .list-container {
    margin-bottom: 12px;
    background-color: rgba(255, 255, 255, 0.05);
    border-radius: 8px;
    overflow: hidden;
  }

  .list-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 12px 16px;
    background: none;
    border: none;
    cursor: pointer;
    color: var(--header-color);
    font-weight: 700;
    font-size: 14px;
    transition: background-color 0.2s ease;
  }

  .list-header:hover {
    background-color: rgba(255, 255, 255, 0.05);
  }

  .chevron {
    width: 20px;
    height: 20px;
    transition: transform 0.2s ease;
  }

  .chevron.rotated {
    transform: rotate(180deg);
  }

  .list-content {
    max-height: 400px;
    overflow-y: auto;
    padding: 8px;
  }

  .disciplina-card {
    padding: 12px;
    margin-bottom: 8px;
    background-color: rgba(255, 255, 255, 0.08);
    border-radius: 6px;
  }

  .disciplina-card:last-child {
    margin-bottom: 0;
  }

  .disciplina-header {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 8px;
  }

  .codigo {
    color: rgba(255, 255, 255, 0.7);
    font-size: 12px;
  }

  .nome {
    color: #fff;
    font-weight: 600;
    font-size: 14px;
  }

  .disciplina-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 4px;
    font-size: 12px;
  }

  .label {
    color: rgba(255, 255, 255, 0.7);
  }

  .value {
    color: rgba(255, 255, 255, 0.9);
  }

  .value.aprovado {
    color: #4ade80;
  }

  .disciplina-row.error .value {
    color: #f87171;
    font-style: italic;
  }

  .disciplina-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
    margin-top: 8px;
  }

  .meta-item {
    font-size: 12px;
    color: rgba(255, 255, 255, 0.7);
  }

  @media (max-width: 600px) {
    .list-header {
      padding: 10px 12px;
      font-size: 12px;
    }

    .disciplina-card {
      padding: 10px;
    }

    .nome {
      font-size: 12px;
    }

    .disciplina-row,
    .meta-item {
      font-size: 10px;
    }
  }
</style>
```

---

## 9. Error Handling

### Error Toast Component

**File: `src/lib/components/Toast.svelte`**

```svelte
<script lang="ts">
  import { fly, fade } from 'svelte/transition';
  import { toastStore, type Toast } from '$lib/stores/toastStore';

  $: toasts = $toastStore;

  function getIcon(type: Toast['type']): string {
    switch (type) {
      case 'success': return '✅';
      case 'error': return '❌';
      case 'warning': return '⚠️';
      case 'info': return 'ℹ️';
      default: return 'ℹ️';
    }
  }

  function dismiss(id: string) {
    toastStore.remove(id);
  }
</script>

<div class="toast-container">
  {#each toasts as toast (toast.id)}
    <div 
      class="toast toast--{toast.type}"
      role="alert"
      in:fly={{ y: -20, duration: 300 }}
      out:fade={{ duration: 200 }}
    >
      <span class="toast-icon">{getIcon(toast.type)}</span>
      <span class="toast-message">{toast.message}</span>
      <button 
        type="button"
        class="toast-dismiss"
        on:click={() => dismiss(toast.id)}
        aria-label="Fechar notificação"
      >
        ×
      </button>
    </div>
  {/each}
</div>

<style>
  .toast-container {
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 9999;
    display: flex;
    flex-direction: column;
    gap: 8px;
    max-width: 400px;
  }

  .toast {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 14px 16px;
    border-radius: 8px;
    background-color: #fff;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    border-left: 4px solid;
  }

  .toast--success {
    border-color: #10b981;
    background-color: #ecfdf5;
  }

  .toast--error {
    border-color: #ef4444;
    background-color: #fef2f2;
  }

  .toast--warning {
    border-color: #f59e0b;
    background-color: #fffbeb;
  }

  .toast--info {
    border-color: #3b82f6;
    background-color: #eff6ff;
  }

  .toast-icon {
    flex-shrink: 0;
    font-size: 18px;
  }

  .toast-message {
    flex: 1;
    font-size: 14px;
    color: #1f2937;
  }

  .toast-dismiss {
    flex-shrink: 0;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: none;
    border: none;
    font-size: 20px;
    color: #6b7280;
    cursor: pointer;
    border-radius: 4px;
    transition: background-color 0.2s;
  }

  .toast-dismiss:hover {
    background-color: rgba(0, 0, 0, 0.05);
  }

  @media (max-width: 600px) {
    .toast-container {
      left: 16px;
      right: 16px;
      max-width: none;
    }
  }
</style>
```

### Toast Store

**File: `src/lib/stores/toastStore.ts`**

```typescript
import { writable } from 'svelte/store';

export interface Toast {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  message: string;
  duration?: number;
}

function createToastStore() {
  const { subscribe, update } = writable<Toast[]>([]);

  function add(toast: Omit<Toast, 'id'>) {
    const id = crypto.randomUUID();
    const duration = toast.duration ?? 5000;

    update(toasts => [...toasts, { ...toast, id }]);

    if (duration > 0) {
      setTimeout(() => remove(id), duration);
    }
  }

  function remove(id: string) {
    update(toasts => toasts.filter(t => t.id !== id));
  }

  return {
    subscribe,
    add,
    remove,
    success: (message: string, duration?: number) => add({ type: 'success', message, duration }),
    error: (message: string, duration?: number) => add({ type: 'error', message, duration: duration ?? 7000 }),
    warning: (message: string, duration?: number) => add({ type: 'warning', message, duration }),
    info: (message: string, duration?: number) => add({ type: 'info', message, duration }),
  };
}

export const toastStore = createToastStore();
```

### Upload Error Handling Patterns

```typescript
// In uploadStore.ts or component

// Pattern 1: Handle service errors
try {
  await uploadStore.uploadFile(file, {
    onCourseSelectionRequired: (data) => {
      // Show course selection modal
      showCourseModal = true;
      courseSelectionData = data;
    }
  });
} catch (error) {
  if (error instanceof Error) {
    toastStore.error(error.message);
  } else {
    toastStore.error('Erro desconhecido ao processar arquivo.');
  }
}

// Pattern 2: Handle specific error types
function handleUploadError(error: string | CourseSelectionError) {
  if (typeof error === 'object' && error.type === 'COURSE_SELECTION') {
    // This is expected - show modal
    return;
  }

  // Map common errors to user-friendly messages
  const errorMessages: Record<string, string> = {
    'Error uploading PDF': 'Erro ao enviar o arquivo. Verifique sua conexão.',
    'Error processing disciplines': 'Erro ao processar disciplinas. Tente novamente.',
    'Network Error': 'Erro de conexão. Verifique sua internet.',
  };

  for (const [key, message] of Object.entries(errorMessages)) {
    if (error.includes(key)) {
      toastStore.error(message);
      return;
    }
  }

  toastStore.error(error);
}
```

---

## 10. Success Flow

### Success State Component

**File: `src/lib/components/upload/UploadSuccess.svelte`**

```svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { fade, scale } from 'svelte/transition';
  import { uploadStore } from '$lib/stores/uploadStore';
  import { toastStore } from '$lib/stores/toastStore';

  export let fileName: string | null;

  const dispatch = createEventDispatcher();

  let isLoading = false;

  async function handleContinue() {
    isLoading = true;

    try {
      const success = await uploadStore.saveToDatabase();

      if (success) {
        toastStore.success('Fluxograma salvo com sucesso!');
        dispatch('continue');
      } else {
        toastStore.error('Erro ao salvar fluxograma. Tente novamente.');
      }
    } catch (error) {
      console.error('Error saving flowchart:', error);
      toastStore.error('Erro ao salvar fluxograma. Tente novamente.');
    } finally {
      isLoading = false;
    }
  }

  function handleReset() {
    dispatch('reset');
  }
</script>

<div class="success-container" in:fade={{ duration: 300 }}>
  <div class="success-card" in:scale={{ duration: 300, delay: 100 }}>
    <div class="success-icon">
      <svg 
        xmlns="http://www.w3.org/2000/svg" 
        viewBox="0 0 24 24" 
        fill="none" 
        stroke="currentColor" 
        stroke-width="3"
      >
        <polyline points="20 6 9 17 4 12" />
      </svg>
    </div>

    <h2 class="success-title">Histórico processado com sucesso!</h2>
    
    <p class="success-subtitle">
      Seu fluxograma personalizado está sendo gerado.
    </p>

    <button 
      type="button"
      class="continue-button"
      on:click={handleContinue}
      disabled={isLoading}
    >
      {#if isLoading}
        <span class="spinner"></span>
        Salvando...
      {:else}
        Continuar para o Fluxograma
      {/if}
    </button>
  </div>

  {#if fileName}
    <div class="file-info" in:fade={{ duration: 200, delay: 200 }}>
      <span class="file-label">Arquivo selecionado:</span>
      <div class="file-item">
        <svg 
          class="file-icon"
          xmlns="http://www.w3.org/2000/svg" 
          viewBox="0 0 24 24" 
          fill="none" 
          stroke="currentColor" 
          stroke-width="2"
        >
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
          <polyline points="14 2 14 8 20 8" />
        </svg>
        <span class="file-name">{fileName}</span>
        <button 
          type="button"
          class="remove-button"
          on:click={handleReset}
          aria-label="Remover arquivo"
        >
          <svg 
            xmlns="http://www.w3.org/2000/svg" 
            viewBox="0 0 24 24" 
            fill="none" 
            stroke="currentColor" 
            stroke-width="2"
          >
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        </button>
      </div>
    </div>
  {/if}
</div>

<style>
  .success-container {
    display: flex;
    flex-direction: column;
    gap: 32px;
    align-items: center;
  }

  .success-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    padding: 36px 32px;
    background-color: rgba(0, 0, 0, 0.85);
    border: 2px dashed rgba(255, 255, 255, 0.5);
    border-radius: 20px;
    text-align: center;
  }

  .success-icon {
    width: 64px;
    height: 64px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 4px solid #4ade80;
    border-radius: 50%;
    color: #4ade80;
  }

  .success-icon svg {
    width: 32px;
    height: 32px;
  }

  .success-title {
    font-size: 24px;
    font-weight: 700;
    color: #fff;
    margin: 0;
  }

  .success-subtitle {
    font-size: 16px;
    color: rgba(255, 255, 255, 0.7);
    margin: 0;
  }

  .continue-button {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    width: 100%;
    padding: 12px 24px;
    background-color: #007BFF;
    color: #fff;
    border: none;
    border-radius: 8px;
    font-size: 16px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.3s ease;
    min-height: 48px;
  }

  .continue-button:hover:not(:disabled) {
    background-color: #0056b3;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 123, 255, 0.4);
  }

  .continue-button:disabled {
    opacity: 0.7;
    cursor: not-allowed;
  }

  .spinner {
    width: 18px;
    height: 18px;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top-color: #fff;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .file-info {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .file-label {
    font-size: 14px;
    font-weight: 600;
    color: #fff;
  }

  .file-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px;
    background-color: rgba(255, 255, 255, 0.18);
    border-radius: 12px;
  }

  .file-icon {
    width: 20px;
    height: 20px;
    color: #fff;
    flex-shrink: 0;
  }

  .file-name {
    font-size: 14px;
    font-weight: 500;
    color: #fff;
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .remove-button {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    background: none;
    border: none;
    color: #fff;
    cursor: pointer;
    border-radius: 4px;
    transition: all 0.2s ease;
  }

  .remove-button:hover {
    color: #f87171;
    background-color: rgba(248, 113, 113, 0.1);
  }

  .remove-button svg {
    width: 18px;
    height: 18px;
  }

  @media (max-width: 600px) {
    .success-card {
      padding: 24px 20px;
    }

    .success-icon {
      width: 48px;
      height: 48px;
    }

    .success-icon svg {
      width: 24px;
      height: 24px;
    }

    .success-title {
      font-size: 18px;
    }

    .success-subtitle {
      font-size: 14px;
    }

    .continue-button {
      font-size: 14px;
      padding: 10px 20px;
    }
  }
</style>
```

---

## 11. Type Definitions

**File: `src/lib/types/upload.ts`**

```typescript
export interface DadosExtraidos {
  extracted_data: ExtractedDisciplina[];
  curso_extraido: string;
  matriz_curricular: string;
  matricula: string;
  media_ponderada: number;
  frequencia_geral: number;
  numero_semestre: number;
  semestre_atual: string;
  suspensoes?: string[];
}

export interface ExtractedDisciplina {
  codigo: string;
  nome: string;
  creditos?: number;
  carga_horaria?: number;
  situacao?: string;
  mencao?: string;
  periodo?: string;
}

export interface DisciplinaCasada {
  id_materia?: number;
  codigo?: string;
  nome: string;
  creditos?: number;
  nivel?: number;
  status?: string;
  situacao?: string;
  mencao?: string;
  professor?: string;
  turma?: string;
  ano_periodo?: string;
  frequencia?: number;
  carga_horaria?: number;
  tipo_dado?: string;
  encontrada_no_banco: boolean | string;
  motivo_nao_encontrada?: string;
}

export interface DadosValidacao {
  ira?: number;
  media_ponderada?: number;
  frequencia_geral?: number;
  horas_integralizadas: number;
  curso_extraido?: string;
  matriz_curricular?: string;
  pendencias?: string[];
}

export interface CursoDisponivel {
  nome_curso: string;
  matriz_curricular?: string;
}

export interface DadosMateria {
  id?: number;
  codigo?: string;
  nome: string;
  creditos?: number;
  status?: string;
  mencao?: string;
  professor?: string;
  situacao?: string;
  carga_horaria?: number;
  encontrada_no_banco: boolean | string;
}

export interface DadosFluxogramaUser {
  nomeCurso: string;
  matricula: string;
  matrizCurricular: string;
  ira: number;
  suspensoes: string[];
  semestreAtual: number;
  anoAtual: string;
  horasIntegralizadas: number;
  dadosFluxograma: DadosMateria[][];
}
```

---

## 12. Help Button and Modal

### Help Button

**File: `src/lib/components/upload/HelpButton.svelte`**

```svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  function handleClick() {
    dispatch('click');
  }
</script>

<button 
  type="button"
  class="help-button"
  on:click={handleClick}
  aria-label="Como obter seu histórico acadêmico"
>
  <svg 
    xmlns="http://www.w3.org/2000/svg" 
    viewBox="0 0 24 24" 
    fill="none" 
    stroke="currentColor" 
    stroke-width="2"
    class="help-icon"
  >
    <circle cx="12" cy="12" r="10" />
    <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" />
    <line x1="12" y1="17" x2="12.01" y2="17" />
  </svg>
  <span>Como obter seu histórico acadêmico?</span>
</button>

<style>
  .help-button {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 12px 24px;
    background: linear-gradient(90deg, #7B2FF2, #F357A8);
    color: #fff;
    border: none;
    border-radius: 16px;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 4px 24px rgba(123, 47, 242, 0.15);
  }

  .help-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 30px rgba(123, 47, 242, 0.25);
  }

  .help-icon {
    width: 20px;
    height: 20px;
    flex-shrink: 0;
  }

  @media (max-width: 600px) {
    .help-button {
      padding: 10px 16px;
      font-size: 14px;
    }

    .help-icon {
      width: 18px;
      height: 18px;
    }
  }
</style>
```

### Help Modal

**File: `src/lib/components/upload/HelpModal.svelte`**

```svelte
<script lang="ts">
  import { fade, scale } from 'svelte/transition';
  import { clickOutside } from '$lib/actions/clickOutside';

  export let open = false;

  function close() {
    open = false;
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      close();
    }
  }

  const steps = [
    {
      title: '1º PASSO - Acesse o SIGAA',
      description: 'Entre no SIGAA com seu login e senha institucional.',
      image: '/images/help/tela_de_cadastro.png',
      alt: 'Tela de login do SIGAA',
    },
    {
      title: '2º PASSO - Selecione "Emitir Histórico"',
      description: 'No menu lateral, clique em Ensino e depois em Emitir Histórico.',
      image: '/images/help/emitir_historico.png',
      alt: 'Menu Emitir Histórico no SIGAA',
    },
    {
      title: '3º PASSO - Faça o upload do PDF para o NoFluxoUNB',
      description: 'Salve o arquivo PDF gerado em seu computador e faça o upload nesta página.',
      image: '/images/help/historico_baixado.png',
      alt: 'Exemplo de histórico acadêmico gerado',
    },
  ];
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open}
  <div class="modal-overlay" transition:fade={{ duration: 200 }}>
    <div 
      class="modal"
      transition:scale={{ duration: 200, start: 0.95 }}
      use:clickOutside
      on:clickOutside={close}
      role="dialog"
      aria-modal="true"
      aria-labelledby="help-modal-title"
    >
      <header class="modal-header">
        <h2 id="help-modal-title" class="modal-title">
          Como obter seu histórico acadêmico
        </h2>
        <button 
          type="button"
          class="close-button"
          on:click={close}
          aria-label="Fechar"
        >
          <svg 
            xmlns="http://www.w3.org/2000/svg" 
            viewBox="0 0 24 24" 
            fill="none" 
            stroke="currentColor" 
            stroke-width="2"
          >
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        </button>
      </header>

      <div class="modal-content">
        {#each steps as step}
          <div class="step">
            <h3 class="step-title">{step.title}</h3>
            <p class="step-description">{step.description}</p>
            <div class="step-image-container">
              <img 
                src={step.image} 
                alt={step.alt}
                class="step-image"
                loading="lazy"
              />
            </div>
          </div>
        {/each}
      </div>

      <footer class="modal-footer">
        <button 
          type="button"
          class="understood-button"
          on:click={close}
        >
          Entendi
        </button>
      </footer>
    </div>
  </div>
{/if}

<style>
  .modal-overlay {
    position: fixed;
    inset: 0;
    background-color: rgba(0, 0, 0, 0.6);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 16px;
  }

  .modal {
    background-color: #fff;
    border-radius: 16px;
    max-width: 700px;
    width: 100%;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  }

  .modal-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    padding: 24px;
    border-bottom: 1px solid #e5e7eb;
  }

  .modal-title {
    font-size: 22px;
    font-weight: 700;
    color: #1A202C;
    margin: 0;
  }

  .close-button {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    background: none;
    border: none;
    color: #9ca3af;
    cursor: pointer;
    border-radius: 6px;
    transition: all 0.2s;
    flex-shrink: 0;
  }

  .close-button:hover {
    background-color: #f3f4f6;
    color: #6b7280;
  }

  .close-button svg {
    width: 24px;
    height: 24px;
  }

  .modal-content {
    padding: 24px;
  }

  .step {
    margin-bottom: 32px;
  }

  .step:last-child {
    margin-bottom: 0;
  }

  .step-title {
    font-size: 18px;
    font-weight: 700;
    color: #1A202C;
    margin: 0 0 6px 0;
  }

  .step-description {
    font-size: 16px;
    color: #1A202C;
    margin: 0 0 12px 0;
  }

  .step-image-container {
    text-align: center;
  }

  .step-image {
    max-width: 400px;
    width: 100%;
    border-radius: 12px;
    border: 1px solid #e5e7eb;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  }

  .modal-footer {
    display: flex;
    justify-content: center;
    padding: 16px 24px 24px;
  }

  .understood-button {
    padding: 12px 32px;
    background-color: #1B469B;
    color: #fff;
    border: none;
    border-radius: 8px;
    font-size: 18px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
  }

  .understood-button:hover {
    background-color: #153a7d;
  }

  @media (max-width: 600px) {
    .modal-header {
      padding: 16px;
    }

    .modal-title {
      font-size: 18px;
    }

    .modal-content {
      padding: 16px;
    }

    .step {
      margin-bottom: 24px;
    }

    .step-title {
      font-size: 16px;
    }

    .step-description {
      font-size: 14px;
    }

    .step-image {
      max-width: 280px;
    }

    .modal-footer {
      padding: 12px 16px 20px;
    }

    .understood-button {
      padding: 10px 24px;
      font-size: 16px;
    }
  }
</style>
```

---

## 13. Click Outside Action

**File: `src/lib/actions/clickOutside.ts`**

```typescript
export function clickOutside(node: HTMLElement) {
  const handleClick = (event: MouseEvent) => {
    if (node && !node.contains(event.target as Node) && !event.defaultPrevented) {
      node.dispatchEvent(new CustomEvent('clickOutside', { detail: event }));
    }
  };

  document.addEventListener('click', handleClick, true);

  return {
    destroy() {
      document.removeEventListener('click', handleClick, true);
    }
  };
}
```

---

## 14. File Summary

| SvelteKit File | Purpose |
|----------------|---------|
| `src/routes/upload-historico/+page.svelte` | Main upload page |
| `src/lib/components/upload/FileDropzone.svelte` | Drag-and-drop file picker |
| `src/lib/components/upload/UploadProgress.svelte` | Progress bar during upload |
| `src/lib/components/upload/UploadSuccess.svelte` | Success state with continue button |
| `src/lib/components/upload/ProcessingResults.svelte` | Display extracted disciplines |
| `src/lib/components/upload/DisciplinaList.svelte` | Expandable discipline list |
| `src/lib/components/upload/HelpButton.svelte` | Help button with gradient |
| `src/lib/components/upload/HelpModal.svelte` | Step-by-step instructions modal |
| `src/lib/components/upload/CourseSelectionModal.svelte` | Course selection when multiple matches |
| `src/lib/components/Toast.svelte` | Toast notifications |
| `src/lib/services/uploadService.ts` | API calls for upload flow |
| `src/lib/stores/uploadStore.ts` | Upload state management |
| `src/lib/stores/toastStore.ts` | Toast notification store |
| `src/lib/types/upload.ts` | TypeScript type definitions |
| `src/lib/utils/fileValidation.ts` | File validation utilities |
| `src/lib/actions/clickOutside.ts` | Click outside directive |

---

## 15. Migration Checklist

> **STATUS: ✅ IMPLEMENTED** — All PDF upload components and state management are complete.

- [x] Create upload route page
- [x] Implement FileDropzone with drag-and-drop
- [x] Add file validation (PDF, size limits)
- [x] Create UploadProgress component with animated gradient
- [x] Implement upload service with FormData
- [x] Create uploadStore for state management
- [x] Add discipline matching (casarDisciplinas)
- [x] Implement CourseSelectionModal for multiple matches
- [x] Create UploadSuccess component
- [x] Add ProcessingResults with expandable lists
- [x] Implement HelpButton and HelpModal
- [x] Create Toast notification system (using svelte-sonner)
- [x] Add saveToDatabase functionality
- [x] Implement navigation to fluxograma on success
- [x] Add responsive styles for mobile/tablet
- [ ] Copy help images to static folder
- [ ] Test error handling scenarios (needs manual testing)
