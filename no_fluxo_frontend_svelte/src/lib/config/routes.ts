// Route path constants
export const ROUTES = {
  // Public routes
  HOME: '/',
  LOGIN: '/login',
  SIGNUP: '/signup',
  PASSWORD_RECOVERY: '/password-recovery',
  ANONYMOUS_LOGIN: '/login-anonimo',

  // Protected routes
  ASSISTENTE: '/assistente',
  UPLOAD_HISTORICO: '/upload-historico',
  FLUXOGRAMAS: '/fluxogramas',
  MEU_FLUXOGRAMA: '/meu-fluxograma',

  // Auth routes
  AUTH_CALLBACK: '/auth/callback',
  AUTH_RESET_PASSWORD: '/auth/reset-password',

  // Dynamic routes
  meuFluxograma: (courseName: string) => `/meu-fluxograma/${encodeURIComponent(courseName)}`,
} as const;

// Routes that don't require authentication
export const PUBLIC_ROUTES = [
  '/',
  '/home',
  '/login',
  '/signup',
  '/password-recovery',
  '/login-anonimo',
  '/auth/callback',
  '/auth/reset-password',
] as const;

// Protected routes require authentication
export const PROTECTED_ROUTES = [
  '/assistente',
  '/upload-historico',
  '/fluxogramas',
  '/meu-fluxograma',
] as const;

// Check if route requires authentication
export function requiresAuth(pathname: string): boolean {
  if (PUBLIC_ROUTES.includes(pathname as any)) {
    return false;
  }
  return PROTECTED_ROUTES.some((route) => pathname.startsWith(route));
}

// Auth page routes (where logged-in users should be redirected away from)
export const AUTH_ROUTES = [
  '/login',
  '/signup',
  '/password-recovery',
  '/login-anonimo',
] as const;

export function isAuthRoute(pathname: string): boolean {
  return AUTH_ROUTES.includes(pathname as any);
}
