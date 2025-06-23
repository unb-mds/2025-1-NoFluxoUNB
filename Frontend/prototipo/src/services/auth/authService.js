import CONFIG from '../../utils/constants/config.js';
import { setStoredUser, setStoredToken, removeStoredUser, removeStoredToken } from '../../utils/helpers/common.js';

class AuthService {
    async login(email, password) {
        try {
            const response = await fetch(`${CONFIG.API.BASE_URL}${CONFIG.API.ENDPOINTS.LOGIN}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ email, password })
            });

            if (!response.ok) {
                throw new Error('Credenciais inválidas');
            }

            const data = await response.json();
            setStoredUser(data.user);
            setStoredToken(data.token);
            return data;
        } catch (error) {
            throw error;
        }
    }

    async register(userData) {
        try {
            const response = await fetch(`${CONFIG.API.BASE_URL}${CONFIG.API.ENDPOINTS.REGISTER}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(userData)
            });

            if (!response.ok) {
                throw new Error('Erro ao registrar usuário');
            }

            const data = await response.json();
            setStoredUser(data.user);
            setStoredToken(data.token);
            return data;
        } catch (error) {
            throw error;
        }
    }

    logout() {
        removeStoredUser();
        removeStoredToken();
    }

    async validateToken() {
        try {
            const token = localStorage.getItem(CONFIG.STORAGE.TOKEN_KEY);
            if (!token) return false;

            const response = await fetch(`${CONFIG.API.BASE_URL}/api/auth/validate`, {
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });

            return response.ok;
        } catch (error) {
            return false;
        }
    }
}

export default new AuthService(); 