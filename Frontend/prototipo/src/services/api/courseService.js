import CONFIG from '../../utils/constants/config.js';
import { getStoredToken } from '../../utils/helpers/common.js';

class CourseService {
    async getAllCourses() {
        try {
            const response = await fetch(`${CONFIG.API.BASE_URL}${CONFIG.API.ENDPOINTS.COURSES}`, {
                headers: {
                    'Authorization': `Bearer ${getStoredToken()}`
                }
            });

            if (!response.ok) {
                throw new Error('Erro ao buscar cursos');
            }

            return await response.json();
        } catch (error) {
            throw error;
        }
    }

    async getCourseById(id) {
        try {
            const response = await fetch(`${CONFIG.API.BASE_URL}${CONFIG.API.ENDPOINTS.COURSES}/${id}`, {
                headers: {
                    'Authorization': `Bearer ${getStoredToken()}`
                }
            });

            if (!response.ok) {
                throw new Error('Erro ao buscar curso');
            }

            return await response.json();
        } catch (error) {
            throw error;
        }
    }

    async getCourseEquivalences(courseId) {
        try {
            const response = await fetch(`${CONFIG.API.BASE_URL}${CONFIG.API.ENDPOINTS.EQUIVALENCES}/${courseId}`, {
                headers: {
                    'Authorization': `Bearer ${getStoredToken()}`
                }
            });

            if (!response.ok) {
                throw new Error('Erro ao buscar equivalências');
            }

            return await response.json();
        } catch (error) {
            throw error;
        }
    }

    async getRecommendedCourses(interests) {
        try {
            const response = await fetch(`${CONFIG.API.BASE_URL}${CONFIG.API.ENDPOINTS.COURSES}/recommended`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${getStoredToken()}`
                },
                body: JSON.stringify({ interests })
            });

            if (!response.ok) {
                throw new Error('Erro ao buscar cursos recomendados');
            }

            return await response.json();
        } catch (error) {
            throw error;
        }
    }
}

export default new CourseService(); 