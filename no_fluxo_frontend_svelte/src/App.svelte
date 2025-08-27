<script lang="ts">
  import { Router, Route } from 'svelte-routing';
  import '../styles/index.css';

  // Components
  import AppNavbar from './components/AppNavbar.svelte';
  import HomeScreen from './pages/HomeScreen.svelte';
  import AuthPage from './pages/AuthPage.svelte';
  import FluxogramasIndexScreen from './pages/FluxogramasIndexScreen.svelte';
  import MeuFluxogramaScreen from './pages/MeuFluxogramaScreen.svelte';
  import AssistenteScreen from './pages/AssistenteScreen.svelte';
  import UploadHistoricoScreen from './pages/UploadHistoricoScreen.svelte';
  import PasswordRecoveryScreen from './pages/PasswordRecoveryScreen.svelte';

  // Store for app state
  import { user } from './stores/auth';
  import { isAnonymous } from './stores/auth';

  export let url = '';

  // Navigation handler
  function navigate(path: string) {
    window.location.hash = path;
  }
</script>

<main class="app">
  <Router {url}>
    <!-- Navigation -->
    <AppNavbar {navigate} />

    <!-- Routes -->
    <Route path="/" component={HomeScreen} />
    <Route path="/home" component={HomeScreen} />
    <Route path="/login" component={AuthPage} login={true} />
    <Route path="/signup" component={AuthPage} login={false} />
    <Route path="/password-recovery" component={PasswordRecoveryScreen} />
    <Route path="/assistente" component={AssistenteScreen} />
    <Route path="/upload-historico" component={UploadHistoricoScreen} />
    <Route path="/fluxogramas" component={FluxogramasIndexScreen} />
    <Route path="/meu-fluxograma" component={MeuFluxogramaScreen} />
    <Route path="/meu-fluxograma/:courseName" component={MeuFluxogramaScreen} />
    <Route path="/login-anonimo" component={HomeScreen} />

    <!-- 404 Route -->
    <Route path="/*">
      <div class="error-page">
        <h1 class="typography-headline-large">Página não encontrada</h1>
        <p class="typography-body-large">A página que você está procurando não existe.</p>
        <button class="btn gradient-primary" on:click={() => navigate('/')}>
          Voltar ao início
        </button>
      </div>
    </Route>
  </Router>
</main>

<style>
  .app {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
  }

  .error-page {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 60vh;
    text-align: center;
    padding: var(--spacing-2xl);
    gap: var(--spacing-xl);
  }
</style>
