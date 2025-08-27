import { writable } from 'svelte/store';

// User interface based on Flutter app
export interface User {
  id: string;
  email: string;
  name?: string;
  dadosFluxograma?: any;
  createdAt?: string;
}

// Auth stores
export const user = writable<User | null>(null);
export const isAnonymous = writable<boolean>(false);
export const isLoading = writable<boolean>(false);

// Auth actions
export const authActions = {
  setUser: (userData: User | null) => {
    user.set(userData);
    if (userData) {
      localStorage.setItem('user', JSON.stringify(userData));
    } else {
      localStorage.removeItem('user');
    }
  },

  setAnonymous: (anonymous: boolean) => {
    isAnonymous.set(anonymous);
    localStorage.setItem('isAnonymous', JSON.stringify(anonymous));
  },

  setLoading: (loading: boolean) => {
    isLoading.set(loading);
  },

  logout: () => {
    user.set(null);
    isAnonymous.set(false);
    localStorage.removeItem('user');
    localStorage.removeItem('isAnonymous');
  },

  initialize: () => {
    // Load from localStorage on app start
    const savedUser = localStorage.getItem('user');
    const savedAnonymous = localStorage.getItem('isAnonymous');

    if (savedUser) {
      try {
        user.set(JSON.parse(savedUser));
      } catch (e) {
        console.error('Error parsing saved user:', e);
        localStorage.removeItem('user');
      }
    }

    if (savedAnonymous) {
      try {
        isAnonymous.set(JSON.parse(savedAnonymous));
      } catch (e) {
        console.error('Error parsing anonymous state:', e);
        localStorage.removeItem('isAnonymous');
      }
    }
  }
};
