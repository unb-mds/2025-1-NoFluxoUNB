import CONFIG from '../../utils/constants/config.js';
import { isAuthenticated, logout } from '../../utils/helpers/common.js';

class Navigation {
    constructor() {
        this.render();
    }

    render() {
        const nav = document.createElement('nav');
        nav.className = 'bg-gray-900 py-4';
        nav.innerHTML = `
            <div class="container mx-auto px-4">
                <div class="flex justify-between items-center">
                    <div class="logo-container">
                        <a href="${CONFIG.ROUTES.HOME}" class="logo-text graffiti-font text-white text-2xl sm:text-3xl">
                            NOFLX UNB
                        </a>
                    </div>
                    
                    <div class="hidden md:flex space-x-8">
                        <a href="${CONFIG.ROUTES.HOME}" class="nav-item graffiti-font text-white text-xl">
                            HOME
                        </a>
                        <a href="${CONFIG.ROUTES.FLUXOGRAMAS}" class="nav-item graffiti-font text-white text-xl">
                            FLUXOGRAMA
                        </a>
                        <a href="${CONFIG.ROUTES.ASSISTENTE}" class="nav-item graffiti-font text-white text-xl">
                            ASSISTENTE
                        </a>
                        <a href="${CONFIG.ROUTES.HOME}#sobre" class="nav-item graffiti-font text-white text-xl">
                            SOBRE NÓS
                        </a>
                        ${this.renderAuthButton()}
                    </div>

                    <button id="mobile-menu-btn" class="md:hidden text-white">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
                        </svg>
                    </button>
                </div>

                <div id="mobile-menu" class="md:hidden hidden mt-4">
                    <div class="flex flex-col space-y-4">
                        <a href="${CONFIG.ROUTES.HOME}" class="nav-item graffiti-font text-white text-xl">
                            HOME
                        </a>
                        <a href="${CONFIG.ROUTES.FLUXOGRAMAS}" class="nav-item graffiti-font text-white text-xl">
                            FLUXOGRAMA
                        </a>
                        <a href="${CONFIG.ROUTES.ASSISTENTE}" class="nav-item graffiti-font text-white text-xl">
                            ASSISTENTE
                        </a>
                        <a href="${CONFIG.ROUTES.HOME}#sobre" class="nav-item graffiti-font text-white text-xl">
                            SOBRE NÓS
                        </a>
                        ${this.renderAuthButton(true)}
                    </div>
                </div>
            </div>
        `;

        document.body.insertBefore(nav, document.body.firstChild);
        this.initializeEventListeners();
    }

    renderAuthButton(isMobile = false) {
        if (isAuthenticated()) {
            return `
                <button onclick="window.logout()" class="nav-item graffiti-font text-white text-xl bg-gradient-to-r from-purple-600 to-pink-600 px-4 py-2 rounded-full hover:from-purple-700 hover:to-pink-700 transition-all duration-300">
                    SAIR
                </button>
            `;
        } else {
            return `
                <a href="${CONFIG.ROUTES.LOGIN}" class="nav-item graffiti-font text-white text-xl bg-gradient-to-r from-purple-600 to-pink-600 px-4 py-2 rounded-full hover:from-purple-700 hover:to-pink-700 transition-all duration-300">
                    ACESSE NOSSO SISTEMA
                </a>
            `;
        }
    }

    initializeEventListeners() {
        const mobileMenuBtn = document.getElementById('mobile-menu-btn');
        const mobileMenu = document.getElementById('mobile-menu');

        mobileMenuBtn.addEventListener('click', () => {
            mobileMenu.classList.toggle('hidden');
        });

        // Adiciona a função de logout ao escopo global
        window.logout = logout;
    }
}

export default Navigation; 