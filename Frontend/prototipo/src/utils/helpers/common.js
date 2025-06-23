import CONFIG from '../constants/config.js';

// Função para navegar para uma rota específica
export const navigateTo = (route) => {
    window.location.href = route;
};

// Exibe um modal na tela com o conteúdo fornecido
export const showModal = (content) => {
    const modal = document.createElement('div');
    modal.className = 'modal';
    modal.innerHTML = `
        <div class="modal-content">
            ${content}
        </div>
    `;
    document.body.appendChild(modal);
    return modal;
};

// Remove o modal da tela
export const hideModal = (modal) => {
    if (modal) {
        modal.remove();
    }
};

// Formata o código da disciplina para exibir separação entre letras e números
export const formatCourseCode = (code) => {
    return code.replace(/([A-Z]+)(\d+)/, '$1 $2');
};

// Recupera o usuário armazenado no localStorage
export const getStoredUser = () => {
    const user = localStorage.getItem(CONFIG.STORAGE.USER_KEY);
    return user ? JSON.parse(user) : null;
};

// Salva o usuário no localStorage
export const setStoredUser = (user) => {
    localStorage.setItem(CONFIG.STORAGE.USER_KEY, JSON.stringify(user));
};

// Remove o usuário do localStorage
export const removeStoredUser = () => {
    localStorage.removeItem(CONFIG.STORAGE.USER_KEY);
};

// Recupera o token armazenado no localStorage
export const getStoredToken = () => {
    return localStorage.getItem(CONFIG.STORAGE.TOKEN_KEY);
};

// Salva o token no localStorage
export const setStoredToken = (token) => {
    localStorage.setItem(CONFIG.STORAGE.TOKEN_KEY, token);
};

// Remove o token do localStorage
export const removeStoredToken = () => {
    localStorage.removeItem(CONFIG.STORAGE.TOKEN_KEY);
};

// Verifica se o usuário está autenticado (possui token)
export const isAuthenticated = () => {
    return !!getStoredToken();
};

// Realiza logout removendo usuário e token, e redireciona para a tela de login
export const logout = () => {
    removeStoredUser();
    removeStoredToken();
    navigateTo(CONFIG.ROUTES.LOGIN);
}; 