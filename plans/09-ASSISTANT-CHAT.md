# 09 - AI Assistant Chat Feature Migration

This document covers the migration of the AI Assistant Chat feature from Flutter to SvelteKit.

## Overview

The AI Assistant (Assistente NoFluxo) is a chat interface that helps students discover courses to add to their flowchart. Key features include:
- Chat with AI backend for course recommendations
- Quick action tags for common topics
- Loading animation with curiosidades (fun facts)
- Markdown rendering for AI responses
- Auto-scroll to newest messages

---

## 1. Chat Interface Layout

### Flutter Source Analysis

The Flutter implementation uses a two-column layout:
- **Main Chat (2/3 width)**: Header, message list, input field
- **Side Panel (1/3 width)**: Selected courses, flowchart preview

### SvelteKit Implementation

**File: `src/routes/assistente/+page.svelte`**

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import AnimatedBackground from '$lib/components/AnimatedBackground.svelte';
  import Navbar from '$lib/components/Navbar.svelte';
  import ChatContainer from '$lib/components/assistente/ChatContainer.svelte';
  import SelectedCourses from '$lib/components/assistente/SelectedCourses.svelte';
  import FluxogramPreview from '$lib/components/assistente/FluxogramPreview.svelte';
</script>

<div class="assistant-page">
  <AnimatedBackground />
  
  <div class="content-wrapper">
    <Navbar />
    
    <main class="main-content">
      <div class="layout-grid">
        <!-- Main Chat Area (2/3) -->
        <section class="chat-section">
          <ChatContainer />
        </section>
        
        <!-- Side Panel (1/3) -->
        <aside class="side-panel">
          <SelectedCourses />
          <FluxogramPreview />
        </aside>
      </div>
    </main>
  </div>
</div>

<style>
  .assistant-page {
    position: relative;
    min-height: 100vh;
    background-color: #1a1a1a;
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
    padding: 24px 32px;
  }

  .layout-grid {
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: 24px;
    height: calc(100vh - 120px);
  }

  .chat-section {
    display: flex;
    flex-direction: column;
    min-height: 0;
  }

  .side-panel {
    display: flex;
    flex-direction: column;
    gap: 24px;
    overflow-y: auto;
  }

  /* Responsive */
  @media (max-width: 1024px) {
    .layout-grid {
      grid-template-columns: 1fr;
    }
    
    .side-panel {
      display: none;
    }
  }
</style>
```

---

## 2. Message Components

### 2.1 Chat Message Bubble

**File: `src/lib/components/assistente/ChatMessage.svelte`**

```svelte
<script lang="ts">
  import { marked } from 'marked';
  import DOMPurify from 'dompurify';
  import { fly } from 'svelte/transition';
  
  export let message: {
    id: string;
    text: string;
    isUser: boolean;
    timestamp: Date;
    status?: 'sending' | 'sent' | 'error';
  };
  
  // Configure marked for safe rendering
  marked.setOptions({
    breaks: true,
    gfm: true
  });
  
  $: htmlContent = DOMPurify.sanitize(marked.parse(message.text) as string);
</script>

<div 
  class="message-wrapper"
  class:user-message={message.isUser}
  in:fly={{ y: 20, duration: 300 }}
>
  {#if !message.isUser}
    <div class="avatar ai-avatar">
      <span>A</span>
    </div>
  {/if}
  
  <div 
    class="message-bubble"
    class:user-bubble={message.isUser}
    class:ai-bubble={!message.isUser}
    class:error={message.status === 'error'}
  >
    {#if message.isUser}
      <p class="message-text">{message.text}</p>
    {:else}
      <div class="markdown-content">
        {@html htmlContent}
      </div>
    {/if}
    
    {#if message.status === 'error'}
      <button class="retry-button" on:click>
        Tentar novamente
      </button>
    {/if}
  </div>
  
  {#if message.isUser}
    <div class="avatar user-avatar">
      <span>U</span>
    </div>
  {/if}
</div>

<style>
  .message-wrapper {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 16px;
  }

  .message-wrapper.user-message {
    flex-direction: row-reverse;
  }

  .avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .avatar span {
    color: white;
    font-weight: 700;
    font-size: 18px;
    font-family: 'Poppins', sans-serif;
  }

  .ai-avatar {
    background-color: #B72EFF;
  }

  .user-avatar {
    background-color: #3B82F6;
  }

  .message-bubble {
    max-width: 70%;
    padding: 16px;
    border-radius: 16px;
    color: white;
    font-family: 'Poppins', sans-serif;
    font-size: 16px;
    line-height: 1.5;
  }

  .ai-bubble {
    background-color: rgba(255, 255, 255, 0.1);
    border-top-left-radius: 4px;
  }

  .user-bubble {
    background-color: rgba(139, 92, 246, 0.8);
    border-top-right-radius: 4px;
  }

  .message-bubble.error {
    border: 1px solid #EF4444;
    background-color: rgba(239, 68, 68, 0.1);
  }

  .message-text {
    margin: 0;
    white-space: pre-wrap;
    word-break: break-word;
  }

  /* Markdown Styles */
  .markdown-content :global(p) {
    margin: 0 0 12px 0;
  }

  .markdown-content :global(p:last-child) {
    margin-bottom: 0;
  }

  .markdown-content :global(strong) {
    font-weight: 700;
  }

  .markdown-content :global(em) {
    font-style: italic;
  }

  .markdown-content :global(a) {
    color: #60A5FA;
    text-decoration: underline;
  }

  .markdown-content :global(h1),
  .markdown-content :global(h2),
  .markdown-content :global(h3),
  .markdown-content :global(h4),
  .markdown-content :global(h5),
  .markdown-content :global(h6) {
    margin: 16px 0 8px 0;
    font-weight: 700;
  }

  .markdown-content :global(h1) { font-size: 24px; }
  .markdown-content :global(h2) { font-size: 22px; }
  .markdown-content :global(h3) { font-size: 20px; }
  .markdown-content :global(h4) { font-size: 18px; }
  .markdown-content :global(h5) { font-size: 16px; }
  .markdown-content :global(h6) { font-size: 14px; }

  .markdown-content :global(code) {
    background-color: rgba(0, 0, 0, 0.3);
    padding: 2px 6px;
    border-radius: 4px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 14px;
    color: #22C55E;
  }

  .markdown-content :global(pre) {
    background-color: rgba(0, 0, 0, 0.4);
    padding: 12px;
    border-radius: 8px;
    overflow-x: auto;
    margin: 12px 0;
  }

  .markdown-content :global(pre code) {
    background: none;
    padding: 0;
  }

  .markdown-content :global(blockquote) {
    border-left: 4px solid #8B5CF6;
    padding: 8px 16px;
    margin: 12px 0;
    color: rgba(255, 255, 255, 0.8);
    font-style: italic;
  }

  .markdown-content :global(ul),
  .markdown-content :global(ol) {
    margin: 8px 0;
    padding-left: 24px;
  }

  .markdown-content :global(li) {
    margin-bottom: 4px;
  }

  .markdown-content :global(table) {
    width: 100%;
    border-collapse: collapse;
    margin: 12px 0;
  }

  .markdown-content :global(th),
  .markdown-content :global(td) {
    border: 1px solid rgba(255, 255, 255, 0.2);
    padding: 8px;
  }

  .markdown-content :global(th) {
    background-color: rgba(0, 0, 0, 0.3);
    font-weight: 700;
  }

  .retry-button {
    margin-top: 12px;
    padding: 8px 16px;
    background-color: #EF4444;
    color: white;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-family: 'Poppins', sans-serif;
    font-size: 14px;
    transition: background-color 0.2s;
  }

  .retry-button:hover {
    background-color: #DC2626;
  }
</style>
```

### 2.2 Typing Indicator

**File: `src/lib/components/assistente/TypingIndicator.svelte`**

```svelte
<script lang="ts">
  import { onMount_onDestroy } from 'svelte';
  
  let dots = [0, 1, 2];
  let animationValues = [0, 0, 0];
  let animationFrame: number;
  
  onMount(() => {
    let startTime = performance.now();
    
    const animate = (currentTime: number) => {
      const elapsed = currentTime - startTime;
      
      // Staggered animation for each dot
      dots.forEach((_, index) => {
        const offset = index * 200; // 200ms stagger
        const cyclePosition = ((elapsed + offset) % 1200) / 1200;
        animationValues[index] = Math.sin(cyclePosition * Math.PI);
      });
      
      animationValues = [...animationValues];
      animationFrame = requestAnimationFrame(animate);
    };
    
    animationFrame = requestAnimationFrame(animate);
    
    return () => {
      cancelAnimationFrame(animationFrame);
    };
  });
</script>

<div class="typing-wrapper">
  <div class="avatar">
    <span>A</span>
  </div>
  
  <div class="typing-bubble">
    <div class="dots-container">
      {#each dots as _, index}
        <span 
          class="dot"
          style="opacity: {0.3 + (animationValues[index] * 0.7)}"
        ></span>
      {/each}
    </div>
  </div>
</div>

<style>
  .typing-wrapper {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 16px;
  }

  .avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background-color: #B72EFF;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .avatar span {
    color: white;
    font-weight: 700;
    font-size: 18px;
    font-family: 'Poppins', sans-serif;
  }

  .typing-bubble {
    background-color: rgba(255, 255, 255, 0.1);
    padding: 16px;
    border-radius: 16px;
    border-top-left-radius: 4px;
  }

  .dots-container {
    display: flex;
    gap: 4px;
    align-items: center;
  }

  .dot {
    width: 8px;
    height: 8px;
    background-color: #8B5CF6;
    border-radius: 50%;
    transition: opacity 0.1s ease;
  }
</style>
```

---

## 3. Chat Input Component

**File: `src/lib/components/assistente/ChatInput.svelte`**

```svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  
  export let disabled = false;
  export let placeholder = 'Digite sua mensagem...';
  
  const dispatch = createEventDispatcher<{
    send: string;
  }>();
  
  let inputValue = '';
  let inputEl: HTMLInputElement;
  
  function handleSubmit() {
    const trimmed = inputValue.trim();
    if (trimmed && !disabled) {
      dispatch('send', trimmed);
      inputValue = '';
      inputEl?.focus();
    }
  }
  
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      handleSubmit();
    }
  }
</script>

<div class="input-container">
  <div class="input-wrapper">
    <input
      bind:this={inputEl}
      bind:value={inputValue}
      on:keydown={handleKeydown}
      {placeholder}
      {disabled}
      type="text"
      class="chat-input"
    />
  </div>
  
  <button 
    class="send-button"
    on:click={handleSubmit}
    disabled={disabled || !inputValue.trim()}
    aria-label="Enviar mensagem"
  >
    <svg 
      width="24" 
      height="24" 
      viewBox="0 0 24 24" 
      fill="none" 
      xmlns="http://www.w3.org/2000/svg"
    >
      <path 
        d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" 
        fill="currentColor"
      />
    </svg>
  </button>
</div>

<style>
  .input-container {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 20px;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
  }

  .input-wrapper {
    flex: 1;
    background-color: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.18);
    border-radius: 24px;
  }

  .chat-input {
    width: 100%;
    padding: 16px 20px;
    background: transparent;
    border: none;
    outline: none;
    color: white;
    font-family: 'Poppins', sans-serif;
    font-size: 16px;
  }

  .chat-input::placeholder {
    color: rgba(255, 255, 255, 0.54);
  }

  .chat-input:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .send-button {
    width: 48px;
    height: 48px;
    border-radius: 24px;
    border: none;
    background: linear-gradient(135deg, #8B5CF6, #EC4899);
    color: white;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: transform 0.2s, opacity 0.2s;
  }

  .send-button:hover:not(:disabled) {
    transform: scale(1.05);
  }

  .send-button:active:not(:disabled) {
    transform: scale(0.95);
  }

  .send-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
```

---

## 4. Quick Tags Component

**File: `src/lib/components/assistente/QuickTags.svelte`**

```svelte
<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { fly } from 'svelte/transition';
  
  const dispatch = createEventDispatcher<{
    select: string;
  }>();
  
  const interestTags = [
    'Programação',
    'Dados',
    'Design',
    'Gestão',
    'Pesquisa',
    'Inovação'
  ] as const;
  
  let selectedTags = new Set<string>();
  
  function handleTagClick(tag: string) {
    if (selectedTags.has(tag)) {
      selectedTags.delete(tag);
    } else {
      selectedTags.add(tag);
    }
    selectedTags = selectedTags;
    
    // Dispatch the tag selection
    dispatch('select', tag);
  }
</script>

<div class="quick-tags-wrapper" in:fly={{ y: 20, duration: 300 }}>
  <div class="avatar">
    <span>A</span>
  </div>
  
  <div class="tags-bubble">
    <p class="prompt-text">
      Você pode selecionar algumas áreas de interesse:
    </p>
    
    <div class="tags-container">
      {#each interestTags as tag}
        <button
          class="tag-chip"
          class:selected={selectedTags.has(tag)}
          on:click={() => handleTagClick(tag)}
        >
          {tag}
        </button>
      {/each}
    </div>
  </div>
</div>

<style>
  .quick-tags-wrapper {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 16px;
  }

  .avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background-color: #B72EFF;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .avatar span {
    color: white;
    font-weight: 700;
    font-size: 18px;
    font-family: 'Poppins', sans-serif;
  }

  .tags-bubble {
    background-color: rgba(255, 255, 255, 0.1);
    padding: 16px;
    border-radius: 16px;
    border-top-left-radius: 4px;
    max-width: 70%;
  }

  .prompt-text {
    color: white;
    font-family: 'Poppins', sans-serif;
    font-size: 16px;
    margin: 0 0 12px 0;
  }

  .tags-container {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .tag-chip {
    padding: 6px 12px;
    border-radius: 20px;
    border: 1px solid rgba(255, 255, 255, 0.3);
    background-color: transparent;
    color: white;
    font-family: 'Poppins', sans-serif;
    font-weight: 500;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .tag-chip:hover {
    background-color: rgba(255, 255, 255, 0.1);
    border-color: rgba(255, 255, 255, 0.5);
  }

  .tag-chip.selected {
    background-color: #22C55E;
    border-color: #22C55E;
  }
</style>
```

---

## 5. Loading State with Curiosidades

**File: `src/lib/components/assistente/LoadingMessage.svelte`**

```svelte
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { fade, fly } from 'svelte/transition';
  
  // Fun facts in Portuguese (from Flutter source)
  const curiosidades = [
    "🐙 Polvo tem três corações\nDois bombeiam sangue para as guelras, e um para o resto do corpo. Quando ele nada, o coração principal para de bater!",
    "☕ Cafeína pode ser encontrada em mais de 60 plantas diferentes\nAlém do café, também tem cafeína no chá, cacau, guaraná, e até em algumas folhas que você provavelmente nunca ouviu falar.",
    "🚀 Astronautas crescem até 5 cm no espaço\nA gravidade menor faz a coluna se expandir temporariamente. Quando voltam pra Terra, voltam ao tamanho normal.",
    "🧬 Você compartilha cerca de 60% do seu DNA com uma banana\nPor mais maluco que pareça, somos todos parte da mesma grande árvore da vida. 🍌",
    "🎨 A cor rosa não existe no espectro de luz visível\nEla é uma ilusão criada pelo cérebro como uma mistura de vermelho e azul — que nem se tocam no arco-íris.",
    "🐶 Cães conseguem sentir o cheiro do tempo\nEles percebem a passagem do tempo com base na concentração de cheiros no ambiente. Meio como se 'cheirassem o passado'.",
    "🔢 O símbolo \"@\" tem diferentes nomes no mundo\nNo Brasil é \"arroba\", mas na Alemanha é \"Klammeraffe\" (macaco-aranha), e em Israel é chamado de \"strudel\".",
    "🌎 A Terra é mais redonda do que uma bola de sinuca oficial\nSe você escalasse a Terra para o tamanho de uma bola de sinuca, ela seria mais lisa que a bola!",
    "🧠 Seu cérebro consome cerca de 20% da sua energia\nMesmo representando só uns 2% do seu peso corporal total.",
    "📷 A primeira foto de um ser humano foi tirada por acaso\nFoi em 1838, por Louis Daguerre. A rua estava vazia, mas um homem parado engraxando os sapatos ficou tempo suficiente para aparecer.",
  ];
  
  let currentIndex = 0;
  let intervalId: ReturnType<typeof setInterval>;
  let dotOpacities = [1, 0.5, 0.3];
  let animationFrame: number;
  
  // Pick random initial curiosidade
  onMount(() => {
    currentIndex = Math.floor(Math.random() * curiosidades.length);
    
    // Rotate curiosidades every 7 seconds
    intervalId = setInterval(() => {
      let newIndex;
      do {
        newIndex = Math.floor(Math.random() * curiosidades.length);
      } while (newIndex === currentIndex && curiosidades.length > 1);
      currentIndex = newIndex;
    }, 7000);
    
    // Animate dots
    let startTime = performance.now();
    const animateDots = (currentTime: number) => {
      const elapsed = currentTime - startTime;
      const cyclePosition = (elapsed % 1500) / 1500;
      
      dotOpacities = [
        1,
        0.5 + 0.5 * Math.sin(cyclePosition * Math.PI),
        0.3 + 0.7 * Math.sin(cyclePosition * Math.PI),
      ];
      
      animationFrame = requestAnimationFrame(animateDots);
    };
    
    animationFrame = requestAnimationFrame(animateDots);
  });
  
  onDestroy(() => {
    clearInterval(intervalId);
    cancelAnimationFrame(animationFrame);
  });
  
  $: curiosidade = curiosidades[currentIndex];
</script>

<div class="loading-wrapper" in:fly={{ y: 20, duration: 300 }}>
  <div class="avatar">
    <span>A</span>
  </div>
  
  <div class="loading-bubble">
    <div class="thinking-row">
      <div class="dots-container">
        {#each dotOpacities as opacity}
          <span class="dot" style="opacity: {opacity}"></span>
        {/each}
      </div>
      <span class="thinking-text">IA está pensando...</span>
    </div>
    
    <div class="curiosidade-section">
      <span class="curiosidade-label">Você sabia?</span>
      {#key currentIndex}
        <p class="curiosidade-text" in:fade={{ duration: 300 }}>
          {curiosidade}
        </p>
      {/key}
    </div>
  </div>
</div>

<style>
  .loading-wrapper {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 16px;
  }

  .avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background-color: #B72EFF;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .avatar span {
    color: white;
    font-weight: 700;
    font-size: 18px;
    font-family: 'Poppins', sans-serif;
  }

  .loading-bubble {
    background-color: rgba(255, 255, 255, 0.1);
    padding: 16px;
    border-radius: 16px;
    border-top-left-radius: 4px;
    max-width: 70%;
  }

  .thinking-row {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 10px;
  }

  .dots-container {
    display: flex;
    gap: 4px;
  }

  .dot {
    width: 8px;
    height: 8px;
    background-color: #8B5CF6;
    border-radius: 50%;
  }

  .thinking-text {
    color: rgba(255, 255, 255, 0.7);
    font-family: 'Poppins', sans-serif;
    font-size: 14px;
    font-style: italic;
  }

  .curiosidade-section {
    margin-top: 10px;
  }

  .curiosidade-label {
    display: block;
    color: rgba(255, 255, 255, 0.8);
    font-family: 'Poppins', sans-serif;
    font-weight: 700;
    font-size: 12px;
    margin-bottom: 4px;
  }

  .curiosidade-text {
    color: rgba(255, 255, 255, 0.7);
    font-family: 'Poppins', sans-serif;
    font-size: 12px;
    font-style: italic;
    margin: 0;
    white-space: pre-wrap;
    line-height: 1.4;
  }
</style>
```

---

## 6. Message Store

**File: `src/lib/stores/chatStore.ts`**

```typescript
import { writable, derived, get } from 'svelte/store';

export interface ChatMessage {
  id: string;
  text: string;
  isUser: boolean;
  timestamp: Date;
  status: 'sending' | 'sent' | 'error';
}

interface ChatState {
  messages: ChatMessage[];
  isLoading: boolean;
  error: string | null;
  showQuickTags: boolean;
}

// Generate unique ID
function generateId(): string {
  return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

// Initial welcome message
const initialMessages: ChatMessage[] = [
  {
    id: generateId(),
    text: 'Olá! Sou o assistente NoFluxo. Estou aqui para te ajudar a encontrar matérias interessantes para adicionar ao seu fluxograma.\nMe conte quais áreas você tem interesse ou quais habilidades gostaria de desenvolver! Tente ser o mais curto possível na sua mensagem, para que eu consiga entender melhor o que você quer.',
    isUser: false,
    timestamp: new Date(),
    status: 'sent'
  }
];

const initialState: ChatState = {
  messages: initialMessages,
  isLoading: false,
  error: null,
  showQuickTags: true
};

function createChatStore() {
  const { subscribe, set, update } = writable<ChatState>(initialState);
  
  return {
    subscribe,
    
    // Add user message
    addUserMessage(text: string): string {
      const id = generateId();
      const message: ChatMessage = {
        id,
        text,
        isUser: true,
        timestamp: new Date(),
        status: 'sending'
      };
      
      update(state => ({
        ...state,
        messages: [...state.messages, message],
        isLoading: true,
        showQuickTags: false,
        error: null
      }));
      
      return id;
    },
    
    // Update message status
    updateMessageStatus(id: string, status: ChatMessage['status']) {
      update(state => ({
        ...state,
        messages: state.messages.map(msg =>
          msg.id === id ? { ...msg, status } : msg
        )
      }));
    },
    
    // Add AI response
    addAIMessage(text: string) {
      const message: ChatMessage = {
        id: generateId(),
        text,
        isUser: false,
        timestamp: new Date(),
        status: 'sent'
      };
      
      update(state => ({
        ...state,
        messages: [...state.messages, message],
        isLoading: false
      }));
    },
    
    // Set loading state
    setLoading(isLoading: boolean) {
      update(state => ({ ...state, isLoading }));
    },
    
    // Set error
    setError(error: string | null) {
      update(state => ({ ...state, error, isLoading: false }));
    },
    
    // Retry failed message
    retryMessage(id: string) {
      const state = get({ subscribe });
      const message = state.messages.find(m => m.id === id);
      if (message && message.status === 'error') {
        this.updateMessageStatus(id, 'sending');
        return message.text;
      }
      return null;
    },
    
    // Reset to initial state
    reset() {
      set(initialState);
    }
  };
}

export const chatStore = createChatStore();

// Derived stores for components
export const messages = derived(chatStore, $state => $state.messages);
export const isLoading = derived(chatStore, $state => $state.isLoading);
export const showQuickTags = derived(chatStore, $state => $state.showQuickTags);
export const chatError = derived(chatStore, $state => $state.error);
```

---

## 7. API Integration

**File: `src/lib/services/assistantService.ts`**

```typescript
import { env } from '$env/dynamic/public';

const API_BASE_URL = env.PUBLIC_API_URL || 'http://localhost:8000';

interface AssistantRequest {
  materia: string;
}

interface AssistantResponse {
  resultado?: string;
  erro?: string;
}

export class AssistantService {
  private static readonly endpoint = '/assistente';
  
  static async sendMessage(message: string): Promise<string> {
    const url = `${API_BASE_URL}${this.endpoint}`;
    
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ materia: message } as AssistantRequest)
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data: AssistantResponse = await response.json();
      
      if (data.erro) {
        throw new Error(data.erro);
      }
      
      return data.resultado || 'Sem resposta da IA.';
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`Erro ao se comunicar com a IA: ${error.message}`);
      }
      throw new Error('Erro ao se comunicar com a IA.');
    }
  }
}
```

**File: `src/lib/actions/chatActions.ts`**

```typescript
import { chatStore } from '$lib/stores/chatStore';
import { AssistantService } from '$lib/services/assistantService';

export async function sendMessage(text: string): Promise<void> {
  const messageId = chatStore.addUserMessage(text);
  
  try {
    const response = await AssistantService.sendMessage(text);
    chatStore.updateMessageStatus(messageId, 'sent');
    chatStore.addAIMessage(response);
  } catch (error) {
    chatStore.updateMessageStatus(messageId, 'error');
    chatStore.setError(error instanceof Error ? error.message : 'Erro desconhecido');
  }
}

export async function sendQuickTag(tag: string): Promise<void> {
  await sendMessage(tag);
}

export async function retryFailedMessage(messageId: string): Promise<void> {
  const text = chatStore.retryMessage(messageId);
  if (text) {
    try {
      const response = await AssistantService.sendMessage(text);
      chatStore.updateMessageStatus(messageId, 'sent');
      chatStore.addAIMessage(response);
    } catch (error) {
      chatStore.updateMessageStatus(messageId, 'error');
      chatStore.setError(error instanceof Error ? error.message : 'Erro desconhecido');
    }
  }
}
```

---

## 8. Animations

### 8.1 Message Appear Animation (built into ChatMessage)

The `fly` transition from Svelte is used:

```svelte
<div in:fly={{ y: 20, duration: 300 }}>
  <!-- message content -->
</div>
```

### 8.2 CSS Pulse Animation for Loading

**File: `src/lib/styles/animations.css`**

```css
/* Pulse animation for loading states */
@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

.animate-pulse {
  animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

/* Dot bounce animation */
@keyframes bounce {
  0%, 80%, 100% {
    transform: scale(0);
  }
  40% {
    transform: scale(1);
  }
}

.dot-bounce {
  animation: bounce 1.4s infinite ease-in-out both;
}

.dot-bounce:nth-child(1) {
  animation-delay: -0.32s;
}

.dot-bounce:nth-child(2) {
  animation-delay: -0.16s;
}

/* Fade in animation */
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-fade-in {
  animation: fadeIn 0.3s ease-out forwards;
}

/* Slide up animation */
@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-slide-up {
  animation: slideUp 0.3s ease-out forwards;
}
```

### 8.3 Svelte Transition Actions

**File: `src/lib/transitions/chat.ts`**

```typescript
import { cubicOut } from 'svelte/easing';

export function messageIn(node: HTMLElement, { delay = 0, duration = 300 }) {
  return {
    delay,
    duration,
    css: (t: number) => {
      const eased = cubicOut(t);
      return `
        opacity: ${eased};
        transform: translateY(${(1 - eased) * 20}px);
      `;
    }
  };
}

export function typingDots(node: HTMLElement, { delay = 0, duration = 600 }) {
  return {
    delay,
    duration,
    css: (t: number) => {
      const eased = cubicOut(t);
      return `
        opacity: ${0.3 + eased * 0.7};
        transform: scale(${0.8 + eased * 0.2});
      `;
    }
  };
}
```

---

## 9. Scroll Behavior

Integrated into the ChatContainer component:

**File: `src/lib/components/assistente/ChatContainer.svelte`**

```svelte
<script lang="ts">
  import { onMount, afterUpdate, tick } from 'svelte';
  import { 
    messages, 
    isLoading, 
    showQuickTags 
  } from '$lib/stores/chatStore';
  import { sendMessage, sendQuickTag, retryFailedMessage } from '$lib/actions/chatActions';
  import ChatMessage from './ChatMessage.svelte';
  import ChatInput from './ChatInput.svelte';
  import QuickTags from './QuickTags.svelte';
  import LoadingMessage from './LoadingMessage.svelte';
  
  let messagesContainer: HTMLDivElement;
  let shouldAutoScroll = true;
  
  // Auto-scroll to bottom when new messages arrive
  async function scrollToBottom(smooth = true) {
    if (!messagesContainer || !shouldAutoScroll) return;
    
    await tick();
    
    messagesContainer.scrollTo({
      top: messagesContainer.scrollHeight,
      behavior: smooth ? 'smooth' : 'auto'
    });
  }
  
  // Check if user has scrolled up
  function handleScroll() {
    if (!messagesContainer) return;
    
    const { scrollTop, scrollHeight, clientHeight } = messagesContainer;
    const distanceFromBottom = scrollHeight - scrollTop - clientHeight;
    
    // If user is near bottom (within 100px), enable auto-scroll
    shouldAutoScroll = distanceFromBottom < 100;
  }
  
  // Scroll when messages change
  $: if ($messages.length > 0) {
    scrollToBottom();
  }
  
  // Scroll when loading state changes
  $: if ($isLoading) {
    scrollToBottom();
  }
  
  // Initial scroll on mount
  onMount(() => {
    scrollToBottom(false);
  });
  
  function handleSendMessage(event: CustomEvent<string>) {
    sendMessage(event.detail);
  }
  
  function handleQuickTagSelect(event: CustomEvent<string>) {
    sendQuickTag(event.detail);
  }
  
  function handleRetry(event: CustomEvent, messageId: string) {
    retryFailedMessage(messageId);
  }
</script>

<div class="chat-container">
  <!-- Header -->
  <header class="chat-header">
    <div class="title-row">
      <span class="title-white">ASSISTENTE </span>
      <span class="title-pink">NOFLUXO</span>
    </div>
    <div class="status-indicator">
      <span class="status-dot"></span>
      <span class="status-text">Online</span>
    </div>
  </header>
  
  <!-- Messages Area -->
  <div 
    class="messages-area"
    bind:this={messagesContainer}
    on:scroll={handleScroll}
  >
    {#each $messages as message (message.id)}
      <ChatMessage 
        {message} 
        on:click={() => message.status === 'error' && handleRetry(new CustomEvent('retry'), message.id)}
      />
    {/each}
    
    {#if $showQuickTags && $messages.length === 1}
      <QuickTags on:select={handleQuickTagSelect} />
    {/if}
    
    {#if $isLoading}
      <LoadingMessage />
    {/if}
  </div>
  
  <!-- Input Area -->
  <ChatInput 
    on:send={handleSendMessage}
    disabled={$isLoading}
  />
</div>

<style>
  .chat-container {
    display: flex;
    flex-direction: column;
    height: 100%;
    max-width: 900px;
    margin: 0 auto;
    background-color: rgba(255, 255, 255, 0.07);
    border-radius: 18px;
    border: 1px solid rgba(255, 255, 255, 0.08);
    overflow: hidden;
  }

  .chat-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 24px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  }

  .title-row {
    display: flex;
    align-items: center;
  }

  .title-white {
    font-family: 'Permanent Marker', cursive;
    color: white;
    font-size: 32px;
    font-weight: 700;
    letter-spacing: 2px;
  }

  .title-pink {
    font-family: 'Permanent Marker', cursive;
    color: #FF277E;
    font-size: 32px;
    font-weight: 700;
    letter-spacing: 2px;
  }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .status-dot {
    width: 10px;
    height: 10px;
    background-color: #22C55E;
    border-radius: 50%;
  }

  .status-text {
    color: white;
    font-family: 'Poppins', sans-serif;
    font-size: 14px;
  }

  .messages-area {
    flex: 1;
    overflow-y: auto;
    padding: 24px;
    scroll-behavior: smooth;
  }

  /* Custom scrollbar */
  .messages-area::-webkit-scrollbar {
    width: 8px;
  }

  .messages-area::-webkit-scrollbar-track {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 4px;
  }

  .messages-area::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.2);
    border-radius: 4px;
  }

  .messages-area::-webkit-scrollbar-thumb:hover {
    background: rgba(255, 255, 255, 0.3);
  }
</style>
```

---

## 10. Error Handling

### 10.1 Error Display Component

**File: `src/lib/components/assistente/ErrorToast.svelte`**

```svelte
<script lang="ts">
  import { fade, fly } from 'svelte/transition';
  import { chatError, chatStore } from '$lib/stores/chatStore';
  
  function dismissError() {
    chatStore.setError(null);
  }
</script>

{#if $chatError}
  <div 
    class="error-toast"
    in:fly={{ y: -20, duration: 300 }}
    out:fade={{ duration: 200 }}
  >
    <div class="error-icon">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
        <path 
          d="M12 22C6.477 22 2 17.523 2 12S6.477 2 12 2s10 4.477 10 10-4.477 10-10 10zm-1-7v2h2v-2h-2zm0-8v6h2V7h-2z" 
          fill="currentColor"
        />
      </svg>
    </div>
    <span class="error-message">{$chatError}</span>
    <button class="dismiss-button" on:click={dismissError}>
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
        <path 
          d="M18 6L6 18M6 6l12 12" 
          stroke="currentColor" 
          stroke-width="2" 
          stroke-linecap="round"
        />
      </svg>
    </button>
  </div>
{/if}

<style>
  .error-toast {
    position: fixed;
    top: 80px;
    left: 50%;
    transform: translateX(-50%);
    z-index: 100;
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    background-color: #7F1D1D;
    border: 1px solid #EF4444;
    border-radius: 12px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    max-width: 90%;
  }

  .error-icon {
    color: #FCA5A5;
    flex-shrink: 0;
  }

  .error-message {
    color: #FECACA;
    font-family: 'Poppins', sans-serif;
    font-size: 14px;
  }

  .dismiss-button {
    color: #FCA5A5;
    background: none;
    border: none;
    cursor: pointer;
    padding: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: color 0.2s;
    flex-shrink: 0;
  }

  .dismiss-button:hover {
    color: white;
  }
</style>
```

### 10.2 Retry Logic (integrated in ChatMessage)

The retry button in `ChatMessage.svelte` dispatches an event:

```svelte
{#if message.status === 'error'}
  <button class="retry-button" on:click>
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
      <path 
        d="M17.65 6.35A7.958 7.958 0 0012 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08A5.99 5.99 0 0112 18c-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z" 
        fill="currentColor"
      />
    </svg>
    Tentar novamente
  </button>
{/if}
```

---

## Complete Integration Example

**File: `src/routes/assistente/+page.svelte`** (Full Version)

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import AnimatedBackground from '$lib/components/AnimatedBackground.svelte';
  import Navbar from '$lib/components/Navbar.svelte';
  import ChatContainer from '$lib/components/assistente/ChatContainer.svelte';
  import SelectedCourses from '$lib/components/assistente/SelectedCourses.svelte';
  import FluxogramPreview from '$lib/components/assistente/FluxogramPreview.svelte';
  import ErrorToast from '$lib/components/assistente/ErrorToast.svelte';
  import { chatStore } from '$lib/stores/chatStore';
  
  // Reset chat when leaving page (optional)
  onMount(() => {
    return () => {
      // chatStore.reset(); // Uncomment to reset on unmount
    };
  });
</script>

<svelte:head>
  <title>Assistente NoFluxo</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous">
  <link href="https://fonts.googleapis.com/css2?family=Permanent+Marker&family=Poppins:wght@400;500;600;700&family=JetBrains+Mono&display=swap" rel="stylesheet">
</svelte:head>

<div class="assistant-page">
  <AnimatedBackground />
  <ErrorToast />
  
  <div class="content-wrapper">
    <Navbar />
    
    <main class="main-content">
      <!-- Page Header -->
      <header class="page-header">
        <h1 class="page-title">
          <span class="title-white">ASSISTENTE </span>
          <span class="title-pink">NOFLUXO</span>
        </h1>
        <div class="status-badge">
          <span class="status-dot"></span>
          <span class="status-text">Online</span>
        </div>
      </header>
      
      <div class="layout-grid">
        <!-- Main Chat Area (2/3) -->
        <section class="chat-section">
          <ChatContainer />
        </section>
        
        <!-- Side Panel (1/3) -->
        <aside class="side-panel">
          <SelectedCourses />
          <FluxogramPreview />
          
          <button class="view-flowchart-btn">
            VER FLUXOGRAMA COMPLETO
          </button>
        </aside>
      </div>
    </main>
  </div>
</div>

<style>
  .assistant-page {
    position: relative;
    min-height: 100vh;
    background-color: #1a1a1a;
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
    padding: 24px 32px;
    display: flex;
    flex-direction: column;
  }

  .page-header {
    display: none; /* Header is inside ChatContainer */
  }

  .layout-grid {
    display: grid;
    grid-template-columns: 2fr 1fr;
    gap: 24px;
    flex: 1;
    min-height: 0;
  }

  .chat-section {
    display: flex;
    flex-direction: column;
    min-height: 0;
  }

  .side-panel {
    display: flex;
    flex-direction: column;
    gap: 24px;
    overflow-y: auto;
    padding-right: 8px;
  }

  .view-flowchart-btn {
    width: 100%;
    padding: 14px;
    background-color: rgba(255, 255, 255, 0.1);
    border: none;
    border-radius: 8px;
    color: white;
    font-family: 'Poppins', sans-serif;
    font-weight: 700;
    font-size: 15px;
    cursor: pointer;
    transition: background-color 0.2s;
  }

  .view-flowchart-btn:hover {
    background-color: rgba(255, 255, 255, 0.15);
  }

  /* Responsive */
  @media (max-width: 1024px) {
    .layout-grid {
      grid-template-columns: 1fr;
    }
    
    .side-panel {
      display: none;
    }
    
    .main-content {
      padding: 16px;
    }
  }
</style>
```

---

## Dependencies

Add these packages to your project:

```bash
npm install marked dompurify
npm install -D @types/dompurify
```

---

## File Structure Summary

```
src/
├── routes/
│   └── assistente/
│       └── +page.svelte
├── lib/
│   ├── components/
│   │   └── assistente/
│   │       ├── ChatContainer.svelte
│   │       ├── ChatMessage.svelte
│   │       ├── ChatInput.svelte
│   │       ├── QuickTags.svelte
│   │       ├── LoadingMessage.svelte
│   │       ├── TypingIndicator.svelte
│   │       ├── ErrorToast.svelte
│   │       ├── SelectedCourses.svelte
│   │       └── FluxogramPreview.svelte
│   ├── stores/
│   │   └── chatStore.ts
│   ├── services/
│   │   └── assistantService.ts
│   ├── actions/
│   │   └── chatActions.ts
│   ├── transitions/
│   │   └── chat.ts
│   └── styles/
│       └── animations.css
```

---

## Migration Checklist

- [ ] Create route: `/assistente`
- [ ] Implement ChatContainer with header, messages, and input
- [ ] Implement ChatMessage with markdown rendering
- [ ] Implement ChatInput with send button
- [ ] Implement QuickTags component
- [ ] Implement LoadingMessage with curiosidades carousel
- [ ] Implement TypingIndicator animation
- [x] Create chatStore with message management
- [x] Create assistantService for API calls
- [ ] Implement auto-scroll behavior
- [ ] Implement error handling with retry
- [ ] Add ErrorToast component
- [ ] Add animations and transitions
- [ ] Implement SelectedCourses panel (side panel)
- [ ] Implement FluxogramPreview (side panel)
- [ ] Add responsive design for mobile
- [ ] Import required fonts (Permanent Marker, Poppins, JetBrains Mono)
- [ ] Install dependencies (marked, dompurify)

---

## Key Differences from Flutter

| Aspect | Flutter | SvelteKit |
|--------|---------|-----------|
| State Management | `setState()` + local state | Svelte stores |
| Animation | `AnimationController` | CSS + Svelte transitions |
| HTTP Requests | `http` package | Native `fetch` |
| Markdown | `flutter_markdown` | `marked` + `dompurify` |
| Styling | Widget properties | CSS with scoped styles |
| Timers | `Timer.periodic` | `setInterval` |
| Lifecycle | `initState`/`dispose` | `onMount`/`onDestroy` |

---

## Environment Variables

Create `.env` file:

```env
PUBLIC_API_URL=http://localhost:8000
```

Or for production:

```env
PUBLIC_API_URL=https://api.nofluxo.com
```
