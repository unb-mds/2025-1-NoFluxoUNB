// Elementos do DOM - Seleção de todos os elementos necessários para manipulação
const menuBtn = document.getElementById('menu-btn'); // Botão do menu hamburguer
const mobileMenu = document.getElementById('mobile-menu'); // Menu mobile
const fileInput = document.getElementById('fileInput'); // Input de arquivo
const uploadContainer = document.getElementById('uploadContainer'); // Container de upload
const uploadInitial = document.getElementById('uploadInitial'); // Estado inicial do upload
const uploadingState = document.getElementById('uploadingState'); // Estado de upload em progresso
const successState = document.getElementById('successState'); // Estado de sucesso
const fileList = document.getElementById('fileList'); // Lista de arquivos
const fileName = document.getElementById('fileName'); // Nome do arquivo
const removeFileBtn = document.getElementById('removeFileBtn'); // Botão de remover arquivo
const progressBar = document.getElementById('progressBar'); // Barra de progresso
const progressText = document.getElementById('progressText'); // Texto de progresso
const continueBtn = document.getElementById('continueBtn'); // Botão de continuar
const helpBtn = document.getElementById('helpBtn'); // Botão de ajuda
const helpModal = document.getElementById('helpModal'); // Modal de ajuda
const closeHelpBtn = document.getElementById('closeHelpBtn'); // Botão de fechar ajuda (X)
const closeHelpBtnBottom = document.getElementById('closeHelpBtnBottom'); // Botão de fechar ajuda (Entendi)
const fileItem = document.getElementById('fileItem'); // Item visual do arquivo selecionado

// Toggle do menu hamburguer - Alterna a visibilidade do menu mobile
menuBtn.addEventListener('click', function() {
    menuBtn.classList.toggle('open');
    mobileMenu.classList.toggle('active');
});

// Fechar menu mobile ao clicar fora - Melhora a experiência do usuário
document.addEventListener('click', function(e) {
    if (!menuBtn.contains(e.target) && !mobileMenu.contains(e.target) && mobileMenu.classList.contains('active')) {
        menuBtn.classList.remove('open');
        mobileMenu.classList.remove('active');
    }
});

// Manipulador de mudança do input de arquivo
fileInput.addEventListener('change', function(e) {
    if (this.files && this.files[0]) {
        fileName.textContent = this.files[0].name;
        fileList.classList.remove('hidden');
        fileItem.classList.add('file-item');
        fileItem.classList.remove('file-item--solido');
        helpBtn.style.display = 'none'; // Esconde o botão de ajuda
        simularUpload();
    }
});

// Botão de remover arquivo - Permite ao usuário remover o arquivo selecionado
removeFileBtn.addEventListener('click', function() {
    fileInput.value = '';
    fileList.classList.add('hidden');
    resetarEstadoUpload();
    fileItem.classList.remove('file-item--solido');
    fileItem.classList.add('file-item');
    helpBtn.style.display = '';
});

// Funcionalidade de arrastar e soltar (Drag and Drop)
['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
    uploadContainer.addEventListener(eventName, prevenirPadrao, false);
});

// Previne o comportamento padrão do navegador para eventos de drag and drop
function prevenirPadrao(e) {
    e.preventDefault();
    e.stopPropagation();
}

// Destacar área de drop quando arrastando sobre ela
['dragenter', 'dragover'].forEach(eventName => {
    uploadContainer.addEventListener(eventName, destacar, false);
});

['dragleave', 'drop'].forEach(eventName => {
    uploadContainer.addEventListener(eventName, removerDestaque, false);
});

// Adiciona classes visuais para destacar a área de drop
function destacar() {
    uploadContainer.classList.add('border-blue-400');
    uploadContainer.classList.add('bg-opacity-25');
}

// Remove classes visuais quando não está mais sobre a área de drop
function removerDestaque() {
    uploadContainer.classList.remove('border-blue-400');
    uploadContainer.classList.remove('bg-opacity-25');
}

// Manipulador de arquivos soltos na área de drop
uploadContainer.addEventListener('drop', manipularDrop, false);

function manipularDrop(e) {
    const dt = e.dataTransfer;
    const files = dt.files;
    if (files && files[0]) {
        fileInput.files = files;
        fileName.textContent = files[0].name;
        fileList.classList.remove('hidden');
        fileItem.classList.add('file-item');
        fileItem.classList.remove('file-item--solido');
        helpBtn.style.display = 'none'; // Esconde o botão de ajuda
        simularUpload();
    }
}

// Simula o upload do arquivo com barra de progresso
function simularUpload() {
    uploadInitial.classList.add('hidden');
    uploadingState.classList.remove('hidden');
    let progresso = 0;
    const intervalo = setInterval(() => {
        progresso += Math.random() * 10;
        if (progresso >= 100) {
            progresso = 100;
            clearInterval(intervalo);
            setTimeout(() => {
                uploadingState.classList.add('hidden');
                successState.classList.remove('hidden');
                successState.classList.add('fade-in-up');
                fileItem.classList.remove('file-item');
                fileItem.classList.add('file-item--solido');
                fileItem.className = fileItem.className.split(' ').filter(c => !c.startsWith('bg-') && !c.startsWith('opacity-')).join(' ');
                fileItem.style.background = '#fff';
                fileItem.style.opacity = '1';
                fileItem.style.zIndex = '1';
                fileItem.style.position = 'relative';
                fileItem.style.boxShadow = '0 4px 24px 0 rgba(0,0,0,0.12)';
            }, 500);
        }
        progressBar.style.width = `${progresso}%`;
        progressText.textContent = `${Math.round(progresso)}%`;
    }, 300);
}

// Reseta o estado do upload para o estado inicial
function resetarEstadoUpload() {
    uploadInitial.classList.remove('hidden');
    uploadingState.classList.add('hidden');
    successState.classList.add('hidden');
    progressBar.style.width = '0%';
    progressText.textContent = '0%';
}

// Botão de continuar - Redireciona para a página do fluxograma
continueBtn.addEventListener('click', function() {
    window.location.href = '../fluxogramas/engenharia-software.html';
});

// Manipulação do modal de ajuda
helpBtn.addEventListener('click', function() {
    helpModal.classList.remove('hidden');
});

closeHelpBtn.addEventListener('click', function() {
    helpModal.classList.add('hidden');
});

closeHelpBtnBottom.addEventListener('click', function() {
    helpModal.classList.add('hidden');
});

// Fechar modal ao clicar fora dele
helpModal.addEventListener('click', function(e) {
    if (e.target === helpModal) {
        helpModal.classList.add('hidden');
    }
});

// Cria efeitos de fumaça dinâmicos para o fundo animado
function criarEfeitosFumaca() {
    const cores = ['#6B19C9', '#E63783', '#F0C419'];
    const classesAnimacao = ['smoke-1', 'smoke-2', 'smoke-3'];
    const fundoAnimado = document.querySelector('.animated-bg');
    
    for (let i = 0; i < 5; i++) {
        const fumaça = document.createElement('div');
        fumaça.classList.add('smoke-effect');
        
        // Propriedades aleatórias para cada efeito
        const tamanho = Math.floor(Math.random() * 300) + 150;
        const topo = Math.floor(Math.random() * 100);
        const esquerda = Math.floor(Math.random() * 100);
        const cor = cores[Math.floor(Math.random() * cores.length)];
        const classeAnim = classesAnimacao[Math.floor(Math.random() * classesAnimacao.length)];
        
        // Aplicar estilos
        fumaça.style.width = `${tamanho}px`;
        fumaça.style.height = `${tamanho}px`;
        fumaça.style.top = `${topo}%`;
        fumaça.style.left = `${esquerda}%`;
        fumaça.style.backgroundColor = cor;
        fumaça.classList.add(classeAnim);
        
        fundoAnimado.appendChild(fumaça);
    }
}

// Adicionar efeitos de fumaça dinâmicos ao carregar a página
criarEfeitosFumaca(); 