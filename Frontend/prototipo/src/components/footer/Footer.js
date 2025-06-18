import CONFIG from '../../utils/constants/config.js';

class Footer {
    constructor() {
        this.render();
    }

    render() {
        const footer = document.createElement('footer');
        footer.className = 'bg-gray-900 py-8';
        footer.innerHTML = `
            <div class="container mx-auto px-4">
                <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
                    <div class="text-center md:text-left">
                        <h3 class="text-white text-xl font-bold mb-4">NOFLX UNB</h3>
                        <p class="text-gray-400">
                            Uma plataforma para ajudar estudantes da UNB a planejarem seus cursos de forma eficiente.
                        </p>
                    </div>
                    
                    <div class="text-center">
                        <h3 class="text-white text-xl font-bold mb-4">Links Rápidos</h3>
                        <ul class="space-y-2">
                            <li>
                                <a href="${CONFIG.ROUTES.HOME}" class="text-gray-400 hover:text-white transition-colors">
                                    Home
                                </a>
                            </li>
                            <li>
                                <a href="${CONFIG.ROUTES.FLUXOGRAMAS}" class="text-gray-400 hover:text-white transition-colors">
                                    Fluxogramas
                                </a>
                            </li>
                            <li>
                                <a href="${CONFIG.ROUTES.ASSISTENTE}" class="text-gray-400 hover:text-white transition-colors">
                                    Assistente
                                </a>
                            </li>
                            <li>
                                <a href="${CONFIG.ROUTES.HOME}#sobre" class="text-gray-400 hover:text-white transition-colors">
                                    Sobre Nós
                                </a>
                            </li>
                        </ul>
                    </div>
                    
                    <div class="text-center md:text-right">
                        <h3 class="text-white text-xl font-bold mb-4">Contato</h3>
                        <ul class="space-y-2">
                            <li class="text-gray-400">
                                <a href="mailto:contato@nofluxo.com" class="hover:text-white transition-colors">
                                    contato@nofluxo.com
                                </a>
                            </li>
                            <li class="text-gray-400">
                                <a href="https://github.com/nofluxo" target="_blank" class="hover:text-white transition-colors">
                                    GitHub
                                </a>
                            </li>
                        </ul>
                    </div>
                </div>
                
                <div class="mt-8 pt-8 border-t border-gray-800 text-center">
                    <p class="text-gray-400">
                        © ${new Date().getFullYear()} NOFLX UNB. Todos os direitos reservados.
                    </p>
                </div>
            </div>
        `;

        document.body.appendChild(footer);
    }
}

export default Footer; 