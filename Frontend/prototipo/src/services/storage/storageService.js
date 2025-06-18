import CONFIG from '../../utils/constants/config.js';

class StorageService {
    setItem(key, value) {
        try {
            const serializedValue = JSON.stringify(value);
            localStorage.setItem(key, serializedValue);
        } catch (error) {
            console.error('Erro ao salvar no localStorage:', error);
        }
    }

    getItem(key) {
        try {
            const serializedValue = localStorage.getItem(key);
            return serializedValue ? JSON.parse(serializedValue) : null;
        } catch (error) {
            console.error('Erro ao ler do localStorage:', error);
            return null;
        }
    }

    removeItem(key) {
        try {
            localStorage.removeItem(key);
        } catch (error) {
            console.error('Erro ao remover do localStorage:', error);
        }
    }

    clear() {
        try {
            localStorage.clear();
        } catch (error) {
            console.error('Erro ao limpar localStorage:', error);
        }
    }

    // Métodos específicos para o projeto
    saveUserCourses(courses) {
        this.setItem('user_courses', courses);
    }

    getUserCourses() {
        return this.getItem('user_courses') || [];
    }

    saveUserProgress(progress) {
        this.setItem('user_progress', progress);
    }

    getUserProgress() {
        return this.getItem('user_progress') || {};
    }

    saveUserPreferences(preferences) {
        this.setItem('user_preferences', preferences);
    }

    getUserPreferences() {
        return this.getItem('user_preferences') || {};
    }
}

export default new StorageService(); 