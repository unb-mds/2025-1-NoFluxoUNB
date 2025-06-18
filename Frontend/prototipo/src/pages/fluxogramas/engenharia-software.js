// Mobile menu functionality
document.addEventListener('DOMContentLoaded', function() {
    const menuBtn = document.getElementById('menu-btn');
    const mobileMenu = document.getElementById('mobile-menu');

    if (menuBtn && mobileMenu) {
        menuBtn.addEventListener('click', () => {
            menuBtn.classList.toggle('open');
            mobileMenu.classList.toggle('active');
        });
    }

    // Botões das ferramentas
    const iraCalcBtn = document.getElementById('openIraCalc');
    const progressBtn = document.getElementById('openProgress');
    const integralizationBtn = document.getElementById('openIntegralization');
    const courseChangeBtn = document.getElementById('openCourseChange');

    // Modais
    const iraModal = document.getElementById('iraModal');
    const progressModal = document.getElementById('progressModal');
    const integralizationModal = document.getElementById('integralizationModal');
    const courseChangeModal = document.getElementById('courseChangeModal');

    // Botões de fechar
    const closeButtons = document.querySelectorAll('.closeModal');

    // Event Listeners para abrir modais
    if (iraCalcBtn && iraModal) {
        iraCalcBtn.addEventListener('click', () => {
            iraModal.classList.remove('hidden');
        });
    }

    if (progressBtn && progressModal) {
        progressBtn.addEventListener('click', () => {
            progressModal.classList.remove('hidden');
        });
    }

    if (integralizationBtn && integralizationModal) {
        integralizationBtn.addEventListener('click', () => {
            integralizationModal.classList.remove('hidden');
        });
    }

    if (courseChangeBtn && courseChangeModal) {
        courseChangeBtn.addEventListener('click', () => {
            courseChangeModal.classList.remove('hidden');
        });
    }

    // Event Listeners para fechar modais
    closeButtons.forEach(button => {
        button.addEventListener('click', () => {
            [iraModal, progressModal, integralizationModal, courseChangeModal].forEach(modal => {
                if (modal) modal.classList.add('hidden');
            });
        });
    });

    // Calculadora de IRA
    const addDisciplineBtn = document.getElementById('addDiscipline');
    const calculateIraBtn = document.getElementById('calculateIra');

    if (addDisciplineBtn) {
        addDisciplineBtn.addEventListener('click', () => {
            const form = document.getElementById('iraCalculatorForm');
            if (form) {
                const newRow = document.createElement('div');
                newRow.className = 'flex items-center space-x-2';
                newRow.innerHTML = `
                    <input type="text" placeholder="Disciplina" class="flex-grow border border-gray-700 rounded-lg px-3 py-2 text-sm bg-black bg-opacity-40 text-white">
                    <input type="number" min="0" max="10" step="0.1" placeholder="Nota" class="w-20 border border-gray-700 rounded-lg px-3 py-2 text-sm bg-black bg-opacity-40 text-white">
                    <input type="number" min="1" max="10" placeholder="Créditos" class="w-20 border border-gray-700 rounded-lg px-3 py-2 text-sm bg-black bg-opacity-40 text-white">
                `;
                form.appendChild(newRow);
            }
        });
    }

    if (calculateIraBtn) {
        calculateIraBtn.addEventListener('click', () => {
            const simulatedIra = document.getElementById('simulatedIra');
            if (simulatedIra) {
                const randomIra = (Math.random() * 1.5 + 7.5).toFixed(1);
                simulatedIra.textContent = randomIra;
            }
        });
    }

    // Simulação de mudança de curso
    const simulateCourseChangeBtn = document.getElementById('simulateCourseChange');
    if (simulateCourseChangeBtn) {
        simulateCourseChangeBtn.addEventListener('click', () => {
            const courseSelect = document.getElementById('targetCourse');
            const results = document.getElementById('courseComparisonResults');
            if (courseSelect && courseSelect.value && results) {
                results.classList.remove('hidden');
            }
        });
    }

    // Zoom functionality
    const zoomIn = document.getElementById('zoom-in');
    const zoomOut = document.getElementById('zoom-out');
    const zoomLevel = document.getElementById('zoom-level');
    const fluxogram = document.getElementById('fluxogram');

    let currentZoom = 100;

    if (zoomIn && zoomOut && zoomLevel && fluxogram) {
        zoomIn.addEventListener('click', () => {
            if (currentZoom < 200) {
                currentZoom += 10;
                fluxogram.style.transform = `scale(${currentZoom / 100})`;
                zoomLevel.textContent = `${currentZoom}%`;
            }
        });

        zoomOut.addEventListener('click', () => {
            if (currentZoom > 50) {
                currentZoom -= 10;
                fluxogram.style.transform = `scale(${currentZoom / 100})`;
                zoomLevel.textContent = `${currentZoom}%`;
            }
        });
    }

    // Save functionality
    const saveBtn = document.getElementById('save-btn');
    if (saveBtn) {
        saveBtn.addEventListener('click', function() {
            const fluxogram = document.getElementById('fluxogram');
            if (!fluxogram) {
                alert('Fluxograma não encontrado!');
                return;
            }

            // Desabilitar o botão e mostrar loading
            this.disabled = true;
            this.innerHTML = `
                <svg class="animate-spin h-5 w-5 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                GERANDO PDF...
            `;

            // Capturar a imagem
            html2canvas(fluxogram, {
                scale: 2,
                backgroundColor: '#1a1a1a',
                logging: false,
                useCORS: true,
                allowTaint: true
            }).then(function(canvas) {
                const imgData = canvas.toDataURL('image/png');
                // Tamanho da página A4 em mm
                const pdfWidth = 297;
                const pdfHeight = 210;
                // Tamanho da imagem em px
                const imgWidth = canvas.width;
                const imgHeight = canvas.height;
                // Proporção para caber na página
                const ratio = Math.min(pdfWidth / imgWidth, pdfHeight / imgHeight);
                const imgPDFWidth = imgWidth * ratio;
                const imgPDFHeight = imgHeight * ratio;
                const marginX = (pdfWidth - imgPDFWidth) / 2;
                const marginY = (pdfHeight - imgPDFHeight) / 2;

                const pdf = new jsPDF('l', 'mm', 'a4');
                pdf.addImage(imgData, 'PNG', marginX, marginY, imgPDFWidth, imgPDFHeight);
                pdf.save('fluxograma-engenharia-software.pdf');

                // Restaurar botão
                saveBtn.disabled = false;
                saveBtn.innerHTML = `
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
                    </svg>
                    SALVAR FLUXOGRAMA
                `;
            }).catch(function(error) {
                console.error('Erro ao gerar PDF:', error);
                alert('Erro ao gerar o PDF. Por favor, tente novamente.');
                // Restaurar botão em caso de erro
                saveBtn.disabled = false;
                saveBtn.innerHTML = `
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
                    </svg>
                    SALVAR FLUXOGRAMA
                `;
            });
        });
    }

    // Course modal functionality
    const courseModal = document.getElementById('course-modal');
    const closeCourseModal = document.getElementById('close-course-modal');

    if (closeCourseModal && courseModal) {
        closeCourseModal.addEventListener('click', () => {
            courseModal.classList.add('hidden');
            document.body.classList.remove('modal-open');
        });
    }

    // Fechar modal ao clicar fora dele
    window.addEventListener('click', (event) => {
        if (event.target === courseModal) {
            courseModal.classList.add('hidden');
            document.body.classList.remove('modal-open');
        }
    });

    // Adicionar eventos de clique nas disciplinas
    function setRequiredBoxClickHandlers() {
        document.querySelectorAll('.course-box').forEach(box => {
            if (box.getAttribute('data-course-type') === 'optative') return;
            
            box.onclick = (e) => {
                e.stopPropagation();
                const code = box.getAttribute('data-course-id');
                const name = box.querySelector('p')?.innerText || '';
                const creditsText = box.querySelector('span')?.innerText || '';
                const credits = parseInt(creditsText) || 4;
                const course = { code, name, credits, type: 'Obrigatória' };
                openCourseModal(course);
            };
        });
    }

    // Adicionar eventos de clique nas optativas
    function setOptativeBoxClickHandlers() {
        document.querySelectorAll('.course-box[data-course-type="optative"]').forEach(box => {
            box.onclick = (e) => {
                e.stopPropagation();
                document.querySelectorAll('.course-box.optative-editing').forEach(b => 
                    b.classList.remove('optative-editing', 'optative-selected-for-edit')
                );
                box.classList.add('optative-selected-for-edit', 'optative-editing');
                openOptativeModal();
            };
        });
    }

    // Inicializar handlers
    setRequiredBoxClickHandlers();
    setOptativeBoxClickHandlers();

    // Função para popular a tabela de matérias obrigatórias no modal de adicionar matéria
    function populateCourseTable() {
        if (!courseTable) return;
        courseTable.innerHTML = '';
        // Seleciona todas as matérias obrigatórias do fluxograma
        document.querySelectorAll('.course-box:not([data-course-type="optative"])').forEach(box => {
            const code = box.getAttribute('data-course-id');
            const name = box.querySelector('p')?.innerText || '';
            const creditsText = box.querySelector('span')?.innerText || '';
            const credits = parseInt(creditsText) || 4;
            const isSelected = box.classList.contains('course-selected');
            const row = document.createElement('tr');
            row.className = 'border-b border-gray-800';
            row.innerHTML = `
                <td class="py-3 px-4 text-white">${code}</td>
                <td class="py-3 px-4 text-white">${name}</td>
                <td class="py-3 px-4 text-white">${credits}</td>
                <td class="py-3 px-4 text-white">-</td>
                <td class="py-3 px-4">
                    <button class="${isSelected ? 'bg-red-600 text-white' : 'bg-gradient-to-r from-green-600 to-green-500 text-white'} py-1 px-3 rounded hover:bg-red-700 transition-all duration-300">
                        ${isSelected ? 'Remover' : 'Adicionar'}
                    </button>
                </td>
            `;
            courseTable.appendChild(row);
        });
    }

    // Open add course modal
    addCourseBtn.addEventListener('click', () => {
        populateCourseTable();
        addCourseModal.classList.remove('hidden');
    });
});

// Course modal functionality
const courseModal = document.getElementById('course-modal');
const closeCourseModal = document.getElementById('close-course-modal');

// Add course modal functionality
const addCourseModal = document.getElementById('add-course-modal');
const closeAddModal = document.getElementById('close-add-modal');
const addCourseBtn = document.getElementById('add-course-btn');
const cancelAdd = document.getElementById('cancel-add');
const confirmAdd = document.getElementById('confirm-add');
const courseTable = document.querySelector('#add-course-modal table tbody');
const selectedCourses = new Set();

// Function to update selected courses count
function updateSelectedCoursesCount() {
    const countElement = document.querySelector('#add-course-modal .bg-black.bg-opacity-50 h3');
    const creditsElement = document.querySelector('#add-course-modal .bg-black.bg-opacity-50 .text-white span:first-child');
    const hoursElement = document.querySelector('#add-course-modal .bg-black.bg-opacity-50 .text-white span:last-child');
    
    countElement.textContent = `Matérias Selecionadas: ${selectedCourses.size}`;
    creditsElement.textContent = `Total de Créditos: ${selectedCourses.size * 4}`;
    hoursElement.textContent = `Carga Horária: ${selectedCourses.size * 4} horas/semana`;
}

// Function to update course box appearance
function updateCourseBoxAppearance(courseId, isSelected) {
    const courseBox = document.querySelector(`.course-box[data-course-id="${courseId}"]`);
    if (!courseBox) return;

    // Remove all possible states
    courseBox.classList.remove('course-future', 'course-selected', 'course-current', 'course-completed');

    if (isSelected) {
        courseBox.classList.add('course-selected');
    } else {
        courseBox.classList.add('course-future');
    }
}

// Function to toggle course selection
function toggleCourseSelection(courseId, button) {
    const courseBox = document.querySelector(`.course-box[data-course-id="${courseId}"]`);
    if (courseBox && courseBox.classList.contains('course-completed')) {
        alert('Não é possível adicionar uma matéria já cursada!');
        return;
    }
    if (selectedCourses.has(courseId)) {
        selectedCourses.delete(courseId);
        button.textContent = 'Adicionar';
        button.className = 'bg-gradient-to-r from-green-600 to-green-500 text-white py-1 px-3 rounded hover:from-green-700 hover:to-green-600 transition-all duration-300';
        button.closest('tr').classList.remove('bg-purple-900', 'bg-opacity-20');
    } else {
        selectedCourses.add(courseId);
        button.textContent = 'Remover';
        button.className = 'bg-red-600 text-white py-1 px-3 rounded hover:bg-red-700 transition-all duration-300';
        button.closest('tr').classList.add('bg-purple-900', 'bg-opacity-20');
    }
    updateSelectedCoursesCount();
}

// Add event listeners to course buttons
courseTable.addEventListener('click', (e) => {
    const button = e.target.closest('button');
    if (!button) return;
    
    const row = button.closest('tr');
    const courseId = row.querySelector('td:first-child').textContent;
    toggleCourseSelection(courseId, button);
});

// Função para popular a tabela de matérias obrigatórias no modal de adicionar matéria
function populateCourseTable() {
    if (!courseTable) return;
    courseTable.innerHTML = '';
    // Seleciona todas as matérias obrigatórias do fluxograma
    document.querySelectorAll('.course-box:not([data-course-type="optative"])').forEach(box => {
        const code = box.getAttribute('data-course-id');
        const name = box.querySelector('p')?.innerText || '';
        const creditsText = box.querySelector('span')?.innerText || '';
        const credits = parseInt(creditsText) || 4;
        const isSelected = box.classList.contains('course-selected');
        const row = document.createElement('tr');
        row.className = 'border-b border-gray-800';
        row.innerHTML = `
            <td class="py-3 px-4 text-white">${code}</td>
            <td class="py-3 px-4 text-white">${name}</td>
            <td class="py-3 px-4 text-white">${credits}</td>
            <td class="py-3 px-4 text-white">-</td>
            <td class="py-3 px-4">
                <button class="${isSelected ? 'bg-red-600 text-white' : 'bg-gradient-to-r from-green-600 to-green-500 text-white'} py-1 px-3 rounded hover:bg-red-700 transition-all duration-300">
                    ${isSelected ? 'Remover' : 'Adicionar'}
                </button>
            </td>
        `;
        courseTable.appendChild(row);
    });
}

// Open add course modal
addCourseBtn.addEventListener('click', () => {
    populateCourseTable();
    addCourseModal.classList.remove('hidden');
});

// Close add course modal
closeAddModal.addEventListener('click', () => {
    addCourseModal.classList.add('hidden');
    selectedCourses.clear();
    updateSelectedCoursesCount();
});

// Cancel adding courses
cancelAdd.addEventListener('click', () => {
    addCourseModal.classList.add('hidden');
    selectedCourses.clear();
    updateSelectedCoursesCount();
});

// Confirm adding courses
confirmAdd.addEventListener('click', () => {
    // Verifica se há duplicatas entre as matérias já presentes no fluxograma
    let hasDuplicate = false;
    selectedCourses.forEach(courseId => {
        // Verifica se já existe uma course-box com esse courseId marcada como selecionada
        const alreadySelected = document.querySelectorAll(`.course-box.course-selected[data-course-id="${courseId}"]`).length > 0;
        if (alreadySelected) {
            hasDuplicate = true;
        }
    });
    if (hasDuplicate) {
        alert('Não é possível adicionar duas matérias iguais no fluxograma!');
        return;
    }
    // Apply changes to all selected courses
    selectedCourses.forEach(courseId => {
        updateCourseBoxAppearance(courseId, true);
    });
    alert('Alterações salvas com sucesso!');
    addCourseModal.classList.add('hidden');
    selectedCourses.clear();
    updateSelectedCoursesCount();
});

// Lista de optativas
const optatives = [
    { code: "CIC0201", name: "Introdução à Computação Gráfica", credits: 4 },
    { code: "CIC0202", name: "Processamento de Imagens", credits: 4 },
    { code: "CIC0203", name: "Realidade Virtual", credits: 4 },
    { code: "CIC0204", name: "Jogos Digitais", credits: 4 },
    { code: "CIC0205", name: "Inteligência Artificial", credits: 4 },
    { code: "CIC0206", name: "Aprendizado de Máquina", credits: 4 },
    { code: "CIC0207", name: "Mineração de Dados", credits: 4 },
    { code: "CIC0208", name: "Computação em Nuvem", credits: 4 },
    { code: "CIC0209", name: "Segurança da Informação", credits: 4 },
    { code: "CIC0210", name: "Redes de Computadores", credits: 4 },
    { code: "CIC0211", name: "Sistemas Distribuídos", credits: 4 },
    { code: "CIC0212", name: "Engenharia de Software para Web", credits: 4 },
    { code: "CIC0213", name: "Desenvolvimento Mobile", credits: 4 },
    { code: "CIC0214", name: "Testes de Software", credits: 4 },
    { code: "CIC0215", name: "Qualidade de Software", credits: 4 },
    { code: "CIC0216", name: "Arquitetura de Software", credits: 4 },
    { code: "CIC0217", name: "Padrões de Projeto", credits: 4 },
    { code: "CIC0218", name: "Engenharia de Requisitos", credits: 4 },
    { code: "CIC0219", name: "Gestão de Projetos", credits: 4 },
    { code: "CIC0220", name: "Empreendedorismo em TI", credits: 4 }
];

// Elementos do modal de optativas
const optativeModal = document.getElementById('optative-modal');
const addOptativeBtn = document.getElementById('add-optative-btn');
const closeOptativeModal = document.getElementById('close-optative-modal');
const optativeTableBody = document.getElementById('optative-table-body');
const confirmOptativeBtn = document.getElementById('confirm-optative');
const cancelOptativeBtn = document.getElementById('cancel-optative');
const optativeSemesterSelect = document.getElementById('optative-semester-select');
const selectedOptativeCount = document.getElementById('selected-optative-count');
const selectedOptativeCredits = document.getElementById('selected-optative-credits');
const selectedOptativeHours = document.getElementById('selected-optative-hours');

// Variável para armazenar a optativa selecionada
let selectedOptative = null;

// Função para abrir o modal de optativas
function openOptativeModal() {
    if (optativeModal) {
        optativeModal.classList.remove('hidden');
        populateOptativeTable();
    }
}

// Função para fechar o modal de optativas
function closeOptativeModalFunc() {
    if (optativeModal) {
        optativeModal.classList.add('hidden');
        selectedOptative = null;
        updateSelectedOptativeSummary();
        removeOptativeEditingHighlight();
    }
}

// Função para popular a tabela de optativas
function populateOptativeTable() {
    if (!optativeTableBody) return;
    
    optativeTableBody.innerHTML = '';
    optatives.forEach(optative => {
        const row = document.createElement('tr');
        row.className = 'border-b border-gray-800';
        row.innerHTML = `
            <td class="py-3 px-4 text-white">${optative.code}</td>
            <td class="py-3 px-4 text-white">${optative.name}</td>
            <td class="py-3 px-4 text-white">${optative.credits}</td>
            <td class="py-3 px-4 text-white">-</td>
            <td class="py-3 px-4">
                <button class="select-optative bg-gradient-to-r from-green-600 to-green-500 text-white py-1 px-3 rounded hover:from-green-700 hover:to-green-600 transition-all duration-300">
                    Selecionar
                </button>
            </td>
        `;
        
        const selectBtn = row.querySelector('.select-optative');
        if (selectBtn) {
            selectBtn.addEventListener('click', () => {
                selectOptative(optative, row);
            });
        }
        
        optativeTableBody.appendChild(row);
    });
}

// Função para selecionar uma optativa
function selectOptative(optative, row) {
    // Remover seleção anterior
    document.querySelectorAll('.select-optative').forEach(btn => {
        btn.textContent = 'Selecionar';
        btn.className = 'select-optative bg-gradient-to-r from-green-600 to-green-500 text-white py-1 px-3 rounded hover:from-green-700 hover:to-green-600 transition-all duration-300';
        btn.closest('tr').classList.remove('bg-purple-900', 'bg-opacity-20');
    });
    
    // Selecionar nova optativa
    selectedOptative = optative;
    row.classList.add('bg-purple-900', 'bg-opacity-20');
    const selectBtn = row.querySelector('.select-optative');
    if (selectBtn) {
        selectBtn.textContent = 'Selecionado';
        selectBtn.className = 'select-optative bg-red-600 text-white py-1 px-3 rounded hover:bg-red-700 transition-all duration-300';
    }
    
    updateSelectedOptativeSummary();
}

// Função para atualizar o resumo da optativa selecionada
function updateSelectedOptativeSummary() {
    if (selectedOptativeCount) {
        selectedOptativeCount.textContent = selectedOptative ? '1' : '0';
    }
    if (selectedOptativeCredits) {
        selectedOptativeCredits.textContent = selectedOptative ? selectedOptative.credits : '0';
    }
    if (selectedOptativeHours) {
        selectedOptativeHours.textContent = selectedOptative ? selectedOptative.credits : '0';
    }
}

// Função para adicionar o evento de clique correto aos quadrados de optativa
function setOptativeBoxClickHandlers() {
    document.querySelectorAll('.course-box[data-course-type="optative"]').forEach(box => {
        box.onclick = (e) => {
            e.stopPropagation();
            // Remove destaque de todos os quadrados
            document.querySelectorAll('.course-box.optative-editing').forEach(b => 
                b.classList.remove('optative-editing', 'optative-selected-for-edit')
            );
            // Sempre abre o modal de adicionar optativa, mesmo se já estiver preenchido
            box.classList.add('optative-selected-for-edit', 'optative-editing');
            openOptativeModal();
        };
    });
}

// Ao fechar qualquer modal, remover destaque de edição
function removeOptativeEditingHighlight() {
    document.querySelectorAll('.course-box.optative-editing').forEach(b => 
        b.classList.remove('optative-editing', 'optative-selected-for-edit')
    );
}

// Event Listeners para o modal de optativas
if (addOptativeBtn) {
    addOptativeBtn.addEventListener('click', openOptativeModal);
}

if (closeOptativeModal) {
    closeOptativeModal.addEventListener('click', closeOptativeModalFunc);
}

if (cancelOptativeBtn) {
    cancelOptativeBtn.addEventListener('click', closeOptativeModalFunc);
}

if (confirmOptativeBtn) {
    confirmOptativeBtn.addEventListener('click', addOptativeToFlowchart);
}

// Função para adicionar a optativa ao fluxograma
function addOptativeToFlowchart() {
    if (!selectedOptative) {
        alert('Por favor, selecione uma optativa.');
        return;
    }
    // Verifica se já existe uma optativa com o mesmo código no fluxograma
    const alreadyExists = document.querySelector(`.course-box[data-course-id="${selectedOptative.code}"]`);
    if (alreadyExists) {
        alert('Não é possível adicionar duas matérias optativas iguais no fluxograma!');
        return;
    }
    const semester = parseInt(optativeSemesterSelect?.value);
    if (!semester) {
        alert('Por favor, selecione um semestre.');
        return;
    }
    const semesterElement = document.querySelector(`.semester-col:nth-child(${semester})`);
    if (!semesterElement) {
        alert('Semestre não encontrado.');
        return;
    }
    // Verifica se há um quadrado marcado para edição
    let optativeBox = semesterElement.querySelector('.course-box.optative-selected-for-edit');
    // Se não, procura por um quadrado de optativa vazio
    if (!optativeBox) {
        optativeBox = Array.from(semesterElement.querySelectorAll('.course-box[data-course-type="optative"]')).find(box => {
            return box.innerText.includes('Clique para adicionar');
        });
    }
    // Se ainda não houver, cria um novo quadrado
    if (!optativeBox) {
        optativeBox = document.createElement('div');
        optativeBox.className = 'course-box course-optative rounded-lg p-3 shadow-lg mb-4 w-48';
        optativeBox.setAttribute('data-course-type', 'optative');
        semesterElement.appendChild(optativeBox);
    }
    // Substituir o conteúdo do quadrado de optativa
    optativeBox.innerHTML = `
        <h4 class="text-white font-bold text-sm">${selectedOptative.code}</h4>
        <p class="text-white text-xs mt-1">${selectedOptative.name}</p>
        <div class="flex items-center mt-2">
            <span class="text-xs bg-black bg-opacity-20 px-2 py-0.5 rounded">${selectedOptative.credits} créditos</span>
        </div>
    `;
    optativeBox.setAttribute('data-course-id', selectedOptative.code);
    optativeBox.setAttribute('data-course-type', 'optative');
    optativeBox.classList.add('course-future');
    optativeBox.classList.remove('course-optative');
    optativeBox.classList.remove('optative-selected-for-edit', 'optative-editing');
    // Garante que o quadrado continue abrindo o modal de optativa ao ser clicado
    optativeBox.onclick = (e) => {
        e.stopPropagation();
        optativeBox.classList.add('optative-selected-for-edit', 'optative-editing');
        openOptativeModal();
    };
    setOptativeBoxClickHandlers(); // Garante que todos os quadrados mantenham o comportamento
    console.log(`Optativa ${selectedOptative.code} adicionada ao semestre ${semester}`);
    closeOptativeModalFunc();
}

// Dicionário global de códigos para nomes de disciplinas
const courseNames = {
    // Obrigatórias
    'MAT0025': 'Cálculo 1',
    'MAT0026': 'Cálculo 2',
    'MAT0031': 'Álgebra Linear',
    'EST0023': 'Probabilidade e Estatística',
    'CIC0004': 'Introdução à Computação',
    'CIC0002': 'Algoritmos e Estruturas de Dados',
    'CIC0091': 'Lógica para Computação',
    'CIC0093': 'Organização e Arquitetura de Computadores',
    'CIC0090': 'Fundamentos de Sistemas de Informação',
    'CIC0003': 'Matemática Discreta',
    'CIC0104': 'Estruturas de Dados Avançadas',
    'CIC0097': 'Teoria da Computação',
    'CIC0105': 'Sistemas Operacionais',
    'CIC0202': 'Banco de Dados',
    'CIC0203': 'Redes de Computadores',
    'CIC0124': 'Engenharia de Software I',
    'CIC0182': 'Compiladores',
    'CIC0205': 'Engenharia de Software II',
    'CIC0135': 'Gestão de Projetos de Software',
    'CIC0192': 'Sistemas Distribuídos',
    'CIC0208': 'Interação Humano-Computador',
    'CIC0209': 'Qualidade de Software',
    'CIC0210': 'Empreendedorismo em TI',
    'CIC0211': 'Inteligência Artificial',
    'CIC0212': 'Aprendizado de Máquina',
    'CIC0213': 'Mineração de Dados',
    'CIC0214': 'Computação em Nuvem',
    'CIC0215': 'Segurança da Informação',
    'CIC0216': 'Arquitetura de Software',
    'CIC0217': 'Padrões de Projeto',
    'CIC0218': 'Engenharia de Requisitos',
    'CIC0219': 'Gestão de Projetos',
    'CIC0220': 'Empreendedorismo em TI',
    'CIC0221': 'Trabalho de Conclusão de Curso',
    // Optativas (exemplo)
    'CIC0201': 'Introdução à Computação Gráfica',
    'CIC0206': 'Aprendizado de Máquina',
    // ... adicione todas as optativas e equivalentes relevantes ...
    // Exemplos de equivalentes de outros departamentos
    'MAT0025C': 'Cálculo 1 (Campus Darcy Ribeiro)',
    'MAT0025D': 'Cálculo 1 (Campus Gama)',
    'MAT0026C': 'Cálculo 2 (Campus Darcy Ribeiro)',
    'MAT0026D': 'Cálculo 2 (Campus Gama)',
    'EST0023C': 'Probabilidade e Estatística (Campus Darcy Ribeiro)',
    'EST0023D': 'Probabilidade e Estatística (Campus Gama)',
    // ... adicione outros códigos equivalentes conhecidos ...
};

// Função para abrir o modal de detalhes da disciplina
function openCourseModal(course) {
    const modal = document.getElementById('course-modal');
    const content = document.getElementById('course-modal-content');
    
    // Adicionar classe para travar o scroll do body
    document.body.classList.add('modal-open');
    
    // Mapeamento de pré-requisitos e equivalências
    const courseInfo = {
        // 1º Semestre
        'MAT0025': {
            prereqs: [],
            equivalences: ['MAT0025', 'MAT0025C', 'MAT0025D', 'MAT0025E', 'MAT0025F', 'MAT0025G', 'MAT0025H', 'MAT0025I', 'MAT0025J', 'MAT0025K', 'MAT0025L', 'MAT0025M', 'MAT0025N', 'MAT0025O', 'MAT0025P', 'MAT0025Q', 'MAT0025R', 'MAT0025S', 'MAT0025T', 'MAT0025U', 'MAT0025V', 'MAT0025W', 'MAT0025X', 'MAT0025Y', 'MAT0025Z']
        },
        'CIC0004': {
            prereqs: [],
            equivalences: ['CIC0004', 'CIC0004C', 'CIC0004D', 'CIC0004E', 'CIC0004F', 'CIC0004G', 'CIC0004H', 'CIC0004I', 'CIC0004J', 'CIC0004K', 'CIC0004L', 'CIC0004M', 'CIC0004N', 'CIC0004O', 'CIC0004P', 'CIC0004Q', 'CIC0004R', 'CIC0004S', 'CIC0004T', 'CIC0004U', 'CIC0004V', 'CIC0004W', 'CIC0004X', 'CIC0004Y', 'CIC0004Z']
        },
        'MAT0031': {
            prereqs: [],
            equivalences: ['MAT0031', 'MAT0031C', 'MAT0031D', 'MAT0031E', 'MAT0031F', 'MAT0031G', 'MAT0031H', 'MAT0031I', 'MAT0031J', 'MAT0031K', 'MAT0031L', 'MAT0031M', 'MAT0031N', 'MAT0031O', 'MAT0031P', 'MAT0031Q', 'MAT0031R', 'MAT0031S', 'MAT0031T', 'MAT0031U', 'MAT0031V', 'MAT0031W', 'MAT0031X', 'MAT0031Y', 'MAT0031Z']
        },
        'EST0023': {
            prereqs: [],
            equivalences: ['EST0023', 'EST0023C', 'EST0023D', 'EST0023E', 'EST0023F', 'EST0023G', 'EST0023H', 'EST0023I', 'EST0023J', 'EST0023K', 'EST0023L', 'EST0023M', 'EST0023N', 'EST0023O', 'EST0023P', 'EST0023Q', 'EST0023R', 'EST0023S', 'EST0023T', 'EST0023U', 'EST0023V', 'EST0023W', 'EST0023X', 'EST0023Y', 'EST0023Z']
        },
        
        // 2º Semestre
        'MAT0026': {
            prereqs: ['MAT0025'],
            equivalences: ['MAT0026', 'MAT0026C', 'MAT0026D', 'MAT0026E', 'MAT0026F', 'MAT0026G', 'MAT0026H', 'MAT0026I', 'MAT0026J', 'MAT0026K', 'MAT0026L', 'MAT0026M', 'MAT0026N', 'MAT0026O', 'MAT0026P', 'MAT0026Q', 'MAT0026R', 'MAT0026S', 'MAT0026T', 'MAT0026U', 'MAT0026V', 'MAT0026W', 'MAT0026X', 'MAT0026Y', 'MAT0026Z']
        },
        'CIC0002': {
            prereqs: ['CIC0004'],
            equivalences: ['CIC0002', 'CIC0002C', 'CIC0002D', 'CIC0002E', 'CIC0002F', 'CIC0002G', 'CIC0002H', 'CIC0002I', 'CIC0002J', 'CIC0002K', 'CIC0002L', 'CIC0002M', 'CIC0002N', 'CIC0002O', 'CIC0002P', 'CIC0002Q', 'CIC0002R', 'CIC0002S', 'CIC0002T', 'CIC0002U', 'CIC0002V', 'CIC0002W', 'CIC0002X', 'CIC0002Y', 'CIC0002Z']
        },
        'CIC0091': {
            prereqs: ['CIC0004', 'MAT0031'],
            equivalences: ['CIC0091', 'CIC0091C', 'CIC0091D', 'CIC0091E', 'CIC0091F', 'CIC0091G', 'CIC0091H', 'CIC0091I', 'CIC0091J', 'CIC0091K', 'CIC0091L', 'CIC0091M', 'CIC0091N', 'CIC0091O', 'CIC0091P', 'CIC0091Q', 'CIC0091R', 'CIC0091S', 'CIC0091T', 'CIC0091U', 'CIC0091V', 'CIC0091W', 'CIC0091X', 'CIC0091Y', 'CIC0091Z']
        },
        'CIC0093': {
            prereqs: ['CIC0004'],
            equivalences: ['CIC0093', 'CIC0093C', 'CIC0093D', 'CIC0093E', 'CIC0093F', 'CIC0093G', 'CIC0093H', 'CIC0093I', 'CIC0093J', 'CIC0093K', 'CIC0093L', 'CIC0093M', 'CIC0093N', 'CIC0093O', 'CIC0093P', 'CIC0093Q', 'CIC0093R', 'CIC0093S', 'CIC0093T', 'CIC0093U', 'CIC0093V', 'CIC0093W', 'CIC0093X', 'CIC0093Y', 'CIC0093Z']
        },
        'CIC0090': {
            prereqs: ['CIC0004'],
            equivalences: ['CIC0090', 'CIC0090C', 'CIC0090D', 'CIC0090E', 'CIC0090F', 'CIC0090G', 'CIC0090H', 'CIC0090I', 'CIC0090J', 'CIC0090K', 'CIC0090L', 'CIC0090M', 'CIC0090N', 'CIC0090O', 'CIC0090P', 'CIC0090Q', 'CIC0090R', 'CIC0090S', 'CIC0090T', 'CIC0090U', 'CIC0090V', 'CIC0090W', 'CIC0090X', 'CIC0090Y', 'CIC0090Z']
        },
        'CIC0003': {
            prereqs: ['CIC0004'],
            equivalences: ['CIC0003', 'CIC0003C', 'CIC0003D', 'CIC0003E', 'CIC0003F', 'CIC0003G', 'CIC0003H', 'CIC0003I', 'CIC0003J', 'CIC0003K', 'CIC0003L', 'CIC0003M', 'CIC0003N', 'CIC0003O', 'CIC0003P', 'CIC0003Q', 'CIC0003R', 'CIC0003S', 'CIC0003T', 'CIC0003U', 'CIC0003V', 'CIC0003W', 'CIC0003X', 'CIC0003Y', 'CIC0003Z']
        },
        
        // 3º Semestre
        'CIC0104': {
            prereqs: ['MAT0026', 'CIC0002'],
            equivalences: ['CIC0104', 'CIC0104C', 'CIC0104D', 'CIC0104E', 'CIC0104F', 'CIC0104G', 'CIC0104H', 'CIC0104I', 'CIC0104J', 'CIC0104K', 'CIC0104L', 'CIC0104M', 'CIC0104N', 'CIC0104O', 'CIC0104P', 'CIC0104Q', 'CIC0104R', 'CIC0104S', 'CIC0104T', 'CIC0104U', 'CIC0104V', 'CIC0104W', 'CIC0104X', 'CIC0104Y', 'CIC0104Z']
        },
        'CIC0097': {
            prereqs: ['CIC0091', 'EST0023'],
            equivalences: ['CIC0097', 'CIC0097C', 'CIC0097D', 'CIC0097E', 'CIC0097F', 'CIC0097G', 'CIC0097H', 'CIC0097I', 'CIC0097J', 'CIC0097K', 'CIC0097L', 'CIC0097M', 'CIC0097N', 'CIC0097O', 'CIC0097P', 'CIC0097Q', 'CIC0097R', 'CIC0097S', 'CIC0097T', 'CIC0097U', 'CIC0097V', 'CIC0097W', 'CIC0097X', 'CIC0097Y', 'CIC0097Z']
        },
        'CIC0105': {
            prereqs: ['CIC0093'],
            equivalences: ['CIC0105', 'CIC0105C', 'CIC0105D', 'CIC0105E', 'CIC0105F', 'CIC0105G', 'CIC0105H', 'CIC0105I', 'CIC0105J', 'CIC0105K', 'CIC0105L', 'CIC0105M', 'CIC0105N', 'CIC0105O', 'CIC0105P', 'CIC0105Q', 'CIC0105R', 'CIC0105S', 'CIC0105T', 'CIC0105U', 'CIC0105V', 'CIC0105W', 'CIC0105X', 'CIC0105Y', 'CIC0105Z']
        },
        'CIC0202': {
            prereqs: ['CIC0090'],
            equivalences: ['CIC0202', 'CIC0202C', 'CIC0202D', 'CIC0202E', 'CIC0202F', 'CIC0202G', 'CIC0202H', 'CIC0202I', 'CIC0202J', 'CIC0202K', 'CIC0202L', 'CIC0202M', 'CIC0202N', 'CIC0202O', 'CIC0202P', 'CIC0202Q', 'CIC0202R', 'CIC0202S', 'CIC0202T', 'CIC0202U', 'CIC0202V', 'CIC0202W', 'CIC0202X', 'CIC0202Y', 'CIC0202Z']
        },
        'CIC0203': {
            prereqs: ['CIC0090'],
            equivalences: ['CIC0203', 'CIC0203C', 'CIC0203D', 'CIC0203E', 'CIC0203F', 'CIC0203G', 'CIC0203H', 'CIC0203I', 'CIC0203J', 'CIC0203K', 'CIC0203L', 'CIC0203M', 'CIC0203N', 'CIC0203O', 'CIC0203P', 'CIC0203Q', 'CIC0203R', 'CIC0203S', 'CIC0203T', 'CIC0203U', 'CIC0203V', 'CIC0203W', 'CIC0203X', 'CIC0203Y', 'CIC0203Z']
        },
        
        // 4º Semestre
        'CIC0124': {
            prereqs: ['CIC0104'],
            equivalences: ['CIC0124', 'CIC0124C', 'CIC0124D', 'CIC0124E', 'CIC0124F', 'CIC0124G', 'CIC0124H', 'CIC0124I', 'CIC0124J', 'CIC0124K', 'CIC0124L', 'CIC0124M', 'CIC0124N', 'CIC0124O', 'CIC0124P', 'CIC0124Q', 'CIC0124R', 'CIC0124S', 'CIC0124T', 'CIC0124U', 'CIC0124V', 'CIC0124W', 'CIC0124X', 'CIC0124Y', 'CIC0124Z']
        },
        'CIC0182': {
            prereqs: ['CIC0097'],
            equivalences: ['CIC0182', 'CIC0182C', 'CIC0182D', 'CIC0182E', 'CIC0182F', 'CIC0182G', 'CIC0182H', 'CIC0182I', 'CIC0182J', 'CIC0182K', 'CIC0182L', 'CIC0182M', 'CIC0182N', 'CIC0182O', 'CIC0182P', 'CIC0182Q', 'CIC0182R', 'CIC0182S', 'CIC0182T', 'CIC0182U', 'CIC0182V', 'CIC0182W', 'CIC0182X', 'CIC0182Y', 'CIC0182Z']
        },
        'CIC0205': {
            prereqs: ['CIC0105', 'CIC0202', 'CIC0203'],
            equivalences: ['CIC0205', 'CIC0205C', 'CIC0205D', 'CIC0205E', 'CIC0205F', 'CIC0205G', 'CIC0205H', 'CIC0205I', 'CIC0205J', 'CIC0205K', 'CIC0205L', 'CIC0205M', 'CIC0205N', 'CIC0205O', 'CIC0205P', 'CIC0205Q', 'CIC0205R', 'CIC0205S', 'CIC0205T', 'CIC0205U', 'CIC0205V', 'CIC0205W', 'CIC0205X', 'CIC0205Y', 'CIC0205Z']
        },
        'CIC0135': {
            prereqs: [],
            equivalences: ['CIC0135', 'CIC0135C', 'CIC0135D', 'CIC0135E', 'CIC0135F', 'CIC0135G', 'CIC0135H', 'CIC0135I', 'CIC0135J', 'CIC0135K', 'CIC0135L', 'CIC0135M', 'CIC0135N', 'CIC0135O', 'CIC0135P', 'CIC0135Q', 'CIC0135R', 'CIC0135S', 'CIC0135T', 'CIC0135U', 'CIC0135V', 'CIC0135W', 'CIC0135X', 'CIC0135Y', 'CIC0135Z']
        },
        
        // 5º Semestre
        'CIC0192': {
            prereqs: ['CIC0124'],
            equivalences: ['CIC0192', 'CIC0192C', 'CIC0192D', 'CIC0192E', 'CIC0192F', 'CIC0192G', 'CIC0192H', 'CIC0192I', 'CIC0192J', 'CIC0192K', 'CIC0192L', 'CIC0192M', 'CIC0192N', 'CIC0192O', 'CIC0192P', 'CIC0192Q', 'CIC0192R', 'CIC0192S', 'CIC0192T', 'CIC0192U', 'CIC0192V', 'CIC0192W', 'CIC0192X', 'CIC0192Y', 'CIC0192Z']
        },
        'CIC0208': {
            prereqs: ['CIC0182'],
            equivalences: ['CIC0208', 'CIC0208C', 'CIC0208D', 'CIC0208E', 'CIC0208F', 'CIC0208G', 'CIC0208H', 'CIC0208I', 'CIC0208J', 'CIC0208K', 'CIC0208L', 'CIC0208M', 'CIC0208N', 'CIC0208O', 'CIC0208P', 'CIC0208Q', 'CIC0208R', 'CIC0208S', 'CIC0208T', 'CIC0208U', 'CIC0208V', 'CIC0208W', 'CIC0208X', 'CIC0208Y', 'CIC0208Z']
        },
        'CIC0209': {
            prereqs: ['CIC0205'],
            equivalences: ['CIC0209', 'CIC0209C', 'CIC0209D', 'CIC0209E', 'CIC0209F', 'CIC0209G', 'CIC0209H', 'CIC0209I', 'CIC0209J', 'CIC0209K', 'CIC0209L', 'CIC0209M', 'CIC0209N', 'CIC0209O', 'CIC0209P', 'CIC0209Q', 'CIC0209R', 'CIC0209S', 'CIC0209T', 'CIC0209U', 'CIC0209V', 'CIC0209W', 'CIC0209X', 'CIC0209Y', 'CIC0209Z']
        },
        'CIC0210': {
            prereqs: ['CIC0135'],
            equivalences: ['CIC0210', 'CIC0210C', 'CIC0210D', 'CIC0210E', 'CIC0210F', 'CIC0210G', 'CIC0210H', 'CIC0210I', 'CIC0210J', 'CIC0210K', 'CIC0210L', 'CIC0210M', 'CIC0210N', 'CIC0210O', 'CIC0210P', 'CIC0210Q', 'CIC0210R', 'CIC0210S', 'CIC0210T', 'CIC0210U', 'CIC0210V', 'CIC0210W', 'CIC0210X', 'CIC0210Y', 'CIC0210Z']
        },
        
        // 6º Semestre
        'CIC0211': {
            prereqs: ['CIC0192'],
            equivalences: ['CIC0211', 'CIC0211C', 'CIC0211D', 'CIC0211E', 'CIC0211F', 'CIC0211G', 'CIC0211H', 'CIC0211I', 'CIC0211J', 'CIC0211K', 'CIC0211L', 'CIC0211M', 'CIC0211N', 'CIC0211O', 'CIC0211P', 'CIC0211Q', 'CIC0211R', 'CIC0211S', 'CIC0211T', 'CIC0211U', 'CIC0211V', 'CIC0211W', 'CIC0211X', 'CIC0211Y', 'CIC0211Z']
        },
        'CIC0212': {
            prereqs: ['CIC0208'],
            equivalences: ['CIC0212', 'CIC0212C', 'CIC0212D', 'CIC0212E', 'CIC0212F', 'CIC0212G', 'CIC0212H', 'CIC0212I', 'CIC0212J', 'CIC0212K', 'CIC0212L', 'CIC0212M', 'CIC0212N', 'CIC0212O', 'CIC0212P', 'CIC0212Q', 'CIC0212R', 'CIC0212S', 'CIC0212T', 'CIC0212U', 'CIC0212V', 'CIC0212W', 'CIC0212X', 'CIC0212Y', 'CIC0212Z']
        },
        'CIC0213': {
            prereqs: ['CIC0209'],
            equivalences: ['CIC0213', 'CIC0213C', 'CIC0213D', 'CIC0213E', 'CIC0213F', 'CIC0213G', 'CIC0213H', 'CIC0213I', 'CIC0213J', 'CIC0213K', 'CIC0213L', 'CIC0213M', 'CIC0213N', 'CIC0213O', 'CIC0213P', 'CIC0213Q', 'CIC0213R', 'CIC0213S', 'CIC0213T', 'CIC0213U', 'CIC0213V', 'CIC0213W', 'CIC0213X', 'CIC0213Y', 'CIC0213Z']
        },
        'CIC0214': {
            prereqs: ['CIC0210'],
            equivalences: ['CIC0214', 'CIC0214C', 'CIC0214D', 'CIC0214E', 'CIC0214F', 'CIC0214G', 'CIC0214H', 'CIC0214I', 'CIC0214J', 'CIC0214K', 'CIC0214L', 'CIC0214M', 'CIC0214N', 'CIC0214O', 'CIC0214P', 'CIC0214Q', 'CIC0214R', 'CIC0214S', 'CIC0214T', 'CIC0214U', 'CIC0214V', 'CIC0214W', 'CIC0214X', 'CIC0214Y', 'CIC0214Z']
        },
        
        // 7º Semestre
        'CIC0215': {
            prereqs: ['CIC0211'],
            equivalences: ['CIC0215', 'CIC0215C', 'CIC0215D', 'CIC0215E', 'CIC0215F', 'CIC0215G', 'CIC0215H', 'CIC0215I', 'CIC0215J', 'CIC0215K', 'CIC0215L', 'CIC0215M', 'CIC0215N', 'CIC0215O', 'CIC0215P', 'CIC0215Q', 'CIC0215R', 'CIC0215S', 'CIC0215T', 'CIC0215U', 'CIC0215V', 'CIC0215W', 'CIC0215X', 'CIC0215Y', 'CIC0215Z']
        },
        'CIC0216': {
            prereqs: ['CIC0212'],
            equivalences: ['CIC0216', 'CIC0216C', 'CIC0216D', 'CIC0216E', 'CIC0216F', 'CIC0216G', 'CIC0216H', 'CIC0216I', 'CIC0216J', 'CIC0216K', 'CIC0216L', 'CIC0216M', 'CIC0216N', 'CIC0216O', 'CIC0216P', 'CIC0216Q', 'CIC0216R', 'CIC0216S', 'CIC0216T', 'CIC0216U', 'CIC0216V', 'CIC0216W', 'CIC0216X', 'CIC0216Y', 'CIC0216Z']
        },
        'CIC0217': {
            prereqs: ['CIC0213'],
            equivalences: ['CIC0217', 'CIC0217C', 'CIC0217D', 'CIC0217E', 'CIC0217F', 'CIC0217G', 'CIC0217H', 'CIC0217I', 'CIC0217J', 'CIC0217K', 'CIC0217L', 'CIC0217M', 'CIC0217N', 'CIC0217O', 'CIC0217P', 'CIC0217Q', 'CIC0217R', 'CIC0217S', 'CIC0217T', 'CIC0217U', 'CIC0217V', 'CIC0217W', 'CIC0217X', 'CIC0217Y', 'CIC0217Z']
        },
        'CIC0218': {
            prereqs: ['CIC0214'],
            equivalences: ['CIC0218', 'CIC0218C', 'CIC0218D', 'CIC0218E', 'CIC0218F', 'CIC0218G', 'CIC0218H', 'CIC0218I', 'CIC0218J', 'CIC0218K', 'CIC0218L', 'CIC0218M', 'CIC0218N', 'CIC0218O', 'CIC0218P', 'CIC0218Q', 'CIC0218R', 'CIC0218S', 'CIC0218T', 'CIC0218U', 'CIC0218V', 'CIC0218W', 'CIC0218X', 'CIC0218Y', 'CIC0218Z']
        },
        
        // 8º Semestre
        'CIC0219': {
            prereqs: ['CIC0215'],
            equivalences: ['CIC0219', 'CIC0219C', 'CIC0219D', 'CIC0219E', 'CIC0219F', 'CIC0219G', 'CIC0219H', 'CIC0219I', 'CIC0219J', 'CIC0219K', 'CIC0219L', 'CIC0219M', 'CIC0219N', 'CIC0219O', 'CIC0219P', 'CIC0219Q', 'CIC0219R', 'CIC0219S', 'CIC0219T', 'CIC0219U', 'CIC0219V', 'CIC0219W', 'CIC0219X', 'CIC0219Y', 'CIC0219Z']
        },
        'CIC0220': {
            prereqs: ['CIC0216'],
            equivalences: ['CIC0220', 'CIC0220C', 'CIC0220D', 'CIC0220E', 'CIC0220F', 'CIC0220G', 'CIC0220H', 'CIC0220I', 'CIC0220J', 'CIC0220K', 'CIC0220L', 'CIC0220M', 'CIC0220N', 'CIC0220O', 'CIC0220P', 'CIC0220Q', 'CIC0220R', 'CIC0220S', 'CIC0220T', 'CIC0220U', 'CIC0220V', 'CIC0220W', 'CIC0220X', 'CIC0220Y', 'CIC0220Z']
        },
        'CIC0221': {
            prereqs: ['CIC0217', 'CIC0218', 'CIC0219'],
            equivalences: ['CIC0221', 'CIC0221C', 'CIC0221D', 'CIC0221E', 'CIC0221F', 'CIC0221G', 'CIC0221H', 'CIC0221I', 'CIC0221J', 'CIC0221K', 'CIC0221L', 'CIC0221M', 'CIC0221N', 'CIC0221O', 'CIC0221P', 'CIC0221Q', 'CIC0221R', 'CIC0221S', 'CIC0221T', 'CIC0221U', 'CIC0221V', 'CIC0221W', 'CIC0221X', 'CIC0221Y', 'CIC0221Z']
        }
    };
    
    const info = courseInfo[course.code] || { prereqs: [], equivalences: [] };
    
    // Função para buscar o nome de uma matéria pelo código
    function getCourseName(code) {
        if (courseNames[code]) return courseNames[code];
        const courseBox = document.querySelector(`.course-box[data-course-id="${code}"]`);
        if (courseBox) {
            const nameElement = courseBox.querySelector('p');
            return nameElement ? nameElement.textContent : code;
        }
        return code;
    }
    
    content.innerHTML = `
        <h2 class="text-white text-2xl font-bold mb-2">${course.code} - ${course.name}</h2>
        <p class="text-gray-300 mb-4">Departamento de Ciência da Computação</p>
        
        <div class="flex border-b border-gray-700 mb-6">
            <button class="tab active py-2 px-4 text-white" data-tab="info">Informações</button>
            <button class="tab py-2 px-4 text-gray-400" data-tab="prereqs">Pré-requisitos</button>
            <button class="tab py-2 px-4 text-gray-400" data-tab="equivalences">Equivalências</button>
        </div>
        
        <div class="tab-content">
            <div class="space-y-4" data-tab-content="info">
                <div>
                    <h3 class="text-white font-bold mb-2">Descrição</h3>
                    <p class="text-gray-300 text-sm">${course.type === 'Obrigatória' ? 'Disciplina obrigatória' : 'Disciplina optativa'} do curso de Engenharia de Software.</p>
                </div>
                
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <h3 class="text-white font-bold mb-2">Créditos</h3>
                        <p class="text-gray-300">${course.credits} (${course.credits * 15} horas)</p>
                    </div>
                    
                    <div>
                        <h3 class="text-white font-bold mb-2">Tipo</h3>
                        <p class="text-gray-300">${course.type}</p>
                    </div>
                </div>
            </div>
            
            <div class="space-y-4 hidden" data-tab-content="prereqs">
                <h3 class="text-white font-bold mb-2">Pré-requisitos</h3>
                ${info.prereqs.length > 0 
                    ? `<ul class="list-disc list-inside text-gray-300">
                        ${info.prereqs.map(code => {
                            const prereqCourse = document.querySelector(`.course-box[data-course-id="${code}"]`);
                            const name = prereqCourse ? prereqCourse.querySelector('p').textContent : code;
                            return `<li>${code} - ${name}</li>`;
                        }).join('')}
                       </ul>`
                    : '<p class="text-gray-300">Esta disciplina não possui pré-requisitos.</p>'
                }
            </div>
            
            <div class="space-y-4 hidden" data-tab-content="equivalences">
                <h3 class="text-white font-bold mb-2">Equivalências</h3>
                ${info.equivalences.length > 0
                    ? `<ul class="list-disc list-inside text-gray-300">
                        ${info.equivalences.map(code => {
                            const name = getCourseName(code);
                            return `<li>${code} - ${name}</li>`;
                        }).join('')}
                       </ul>`
                    : '<p class="text-gray-300">Esta disciplina não possui equivalências.</p>'
                }
            </div>
        </div>
        
        <div class="mt-6 flex justify-end gap-3">
            <button class="bg-gradient-to-r from-purple-600 to-pink-600 text-white py-2 px-4 rounded-lg font-bold hover:from-purple-700 hover:to-pink-700 transition-all duration-300">
                ADICIONAR AO PRÓXIMO SEMESTRE
            </button>
        </div>
    `;
    
    // Adicionar funcionalidade de tabs
    const tabs = content.querySelectorAll('.tab');
    const tabContents = content.querySelectorAll('[data-tab-content]');
    
    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            // Remover classe active de todas as tabs
            tabs.forEach(t => t.classList.remove('active', 'text-white'));
            tabs.forEach(t => t.classList.add('text-gray-400'));
            
            // Adicionar classe active na tab clicada
            tab.classList.add('active', 'text-white');
            tab.classList.remove('text-gray-400');
            
            // Esconder todos os conteúdos
            tabContents.forEach(content => content.classList.add('hidden'));
            
            // Mostrar conteúdo da tab clicada
            const tabName = tab.getAttribute('data-tab');
            content.querySelector(`[data-tab-content="${tabName}"]`).classList.remove('hidden');
        });
    });
    
    modal.classList.remove('hidden');

    // Adicionar funcionalidade ao botão 'ADICIONAR AO PRÓXIMO SEMESTRE'
    const addNextBtn = content.querySelector('button.bg-gradient-to-r');
    if (addNextBtn) {
        addNextBtn.addEventListener('click', function() {
            // Descobrir o semestre atual da matéria
            const allSemesters = Array.from(document.querySelectorAll('.semester-col'));
            let currentSemesterIdx = -1;
            let currentBox = null;
            allSemesters.forEach((semester, idx) => {
                const box = semester.querySelector(`.course-box[data-course-id="${course.code}"]`);
                if (box) {
                    currentSemesterIdx = idx;
                    currentBox = box;
                }
            });
            if (currentSemesterIdx === -1) {
                alert('Não foi possível localizar a matéria no fluxograma.');
                return;
            }
            // Procurar próximo semestre disponível
            const nextSemesterIdx = currentSemesterIdx + 1;
            if (nextSemesterIdx >= allSemesters.length) {
                alert('Não há próximo semestre disponível para adicionar esta matéria.');
                return;
            }
            const nextSemester = allSemesters[nextSemesterIdx];
            // Verificar se já existe a matéria no próximo semestre
            if (nextSemester.querySelector(`.course-box[data-course-id="${course.code}"]`)) {
                alert('Esta matéria já está no próximo semestre!');
                return;
            }
            // Criar novo quadrado da matéria no próximo semestre
            const newBox = document.createElement('div');
            newBox.className = 'course-box course-selected rounded-lg p-3 shadow-lg mb-4 w-48';
            newBox.setAttribute('data-course-id', course.code);
            newBox.innerHTML = `
                <h4 class="text-white font-bold text-sm">${course.code}</h4>
                <p class="text-white text-xs mt-1">${course.name}</p>
                <div class="flex items-center mt-2">
                    <span class="text-xs bg-black bg-opacity-20 px-2 py-0.5 rounded">${course.credits} créditos</span>
                </div>
            `;
            nextSemester.appendChild(newBox);
            // Remover do semestre atual
            if (currentBox) {
                currentBox.remove();
            }
            setRequiredBoxClickHandlers();
            alert('Matéria movida para o próximo semestre!');
            modal.classList.add('hidden');
            document.body.classList.remove('modal-open');
        });
    }
}

// Adicionar evento para fechar o modal
document.getElementById('close-course-modal').addEventListener('click', () => {
    const modal = document.getElementById('course-modal');
    modal.classList.add('hidden');
    // Remover classe para liberar o scroll do body
    document.body.classList.remove('modal-open');
});

// Fechar modal ao clicar fora dele
window.addEventListener('click', (event) => {
    if (event.target === courseModal) {
        courseModal.classList.add('hidden');
        // Remover classe para liberar o scroll do body
        document.body.classList.remove('modal-open');
    }
});

// Função para adicionar eventos de clique nas obrigatórias
function setRequiredBoxClickHandlers() {
    document.querySelectorAll('.course-box').forEach(box => {
        // Ignora optativas (já tratadas)
        if (box.getAttribute('data-course-type') === 'optative') return;
        // Remove event listeners antigos
        box.onclick = null;
        // Adiciona evento para abrir o modal da matéria correta
        box.onclick = (e) => {
            e.stopPropagation();
            const code = box.getAttribute('data-course-id');
            // Buscar dados da matéria obrigatória
            const name = box.querySelector('p')?.innerText || '';
            const creditsText = box.querySelector('span')?.innerText || '';
            const credits = parseInt(creditsText) || 4;
            // Monta objeto da matéria
            const course = { code, name, credits, type: 'Obrigatória' };
            openCourseModal(course);
        };
    });
}

// Chamar ao carregar a página e sempre que atualizar boxes
setRequiredBoxClickHandlers();
setOptativeBoxClickHandlers();

// --- INÍCIO: Filtro de Cadeias de Pré-requisito ---

// Coloração manual por grupo de pré-requisito
const manualChainColors = {
    // Grupo Cálculo
    'MAT0025': '#e6194b', // Cálculo 1
    'MAT0026': '#e6194b', // Cálculo 2
    // Grupo Algoritmos
    'CIC0004': '#4363d8', // Algoritmos
    'CIC0002': '#4363d8', // Estruturas de Dados
    'CIC0104': '#4363d8', // Projeto e Análise de Algoritmos
    // Grupo Lógica/OO
    'CIC0091': '#3cb44b', // Orientação a Objetos
    'CIC0097': '#3cb44b', // Bancos de Dados
    'CIC0105': '#3cb44b', // Engenharia de Produto de Software
    // Grupo Engenharia de Requisitos
    'CIC0093': '#ffe119', // Engenharia de Requisitos
    'CIC0202': '#ffe119', // Métodos de Desenvolvimento de Software
    // Grupo Probabilidade
    'EST0023': '#f58231', // Probabilidade e Estatística
    // Grupo Álgebra
    'MAT0031': '#911eb4', // Álgebra Linear
    // Grupo Redes
    'CIC0124': '#46f0f0', // Redes de Computadores
    'CIC0192': '#46f0f0', // Téc. de Prog. em Plataf. Emergentes
    'CIC0211': '#46f0f0', // Inteligência Artificial
    // Grupo Compiladores
    'CIC0182': '#f032e6', // Compiladores
    'CIC0208': '#f032e6', // Paradigmas de Programação
    'CIC0212': '#f032e6', // Qualidade de Software 1
    // Grupo Engenharia de Software
    'CIC0205': '#bcf60c', // Engenharia de Testes de Software
    'CIC0209': '#bcf60c', // Fund. de Sist. Operacionais
    'CIC0213': '#bcf60c', // Gerência de Projetos
    // Grupo Gestão
    'CIC0135': '#fabebe', // Introdução à Ciência de Dados
    'CIC0210': '#fabebe', // Gestão de Config. e Evol. de Software
    // Grupo Projeto Integrador
    'CIC0217': '#008080', // Projeto Integrador de Engenharia 1
    'CIC0220': '#008080', // Projeto Integrador de Engenharia 2
    'CIC0221': '#008080', // Estágio Supervisionado
    // Grupo Empreendedorismo
    'CIC0218': '#e6beff', // Empreendimentos em Software
    'CIC0219': '#e6beff', // Qualidade de Software 2
    // Grupo Optativas (exemplo)
    'CIC0199': '#9a6324', // Tópicos em IA: Machine Learning
    // Adicione outros grupos conforme desejar
};

function colorPrereqChains() {
    const allBoxes = Array.from(document.querySelectorAll('.course-box'));
    allBoxes.forEach((box) => {
        if (!box.dataset.originalClass) {
            box.dataset.originalClass = box.className;
        }
        box.classList.remove('course-completed', 'course-current', 'course-selected', 'course-future', 'course-optative');
        const code = box.getAttribute('data-course-id');
        const color = manualChainColors[code] || '#cccccc';
        box.style.background = color;
        box.style.color = '#fff';
    });
}

// Adicionar evento ao checkbox
const toggleChains = document.getElementById('toggle-prereq-chains');
if (toggleChains) {
    toggleChains.addEventListener('change', function() {
        if (this.checked) {
            colorPrereqChains();
        } else {
            clearPrereqChainsColors();
        }
    });
}
// --- FIM: Filtro de Cadeias de Pré-requisito ---

// Ferramentas de Progresso - JS

// Adicionar eventos para abrir modais das ferramentas de progresso
const iraCalcBtn = document.getElementById('openIraCalc');
const progressBtn = document.getElementById('openProgress');
const integralizationBtn = document.getElementById('openIntegralization');
const courseChangeBtn = document.getElementById('openCourseChange');

if (iraCalcBtn) {
    iraCalcBtn.addEventListener('click', () => {
        document.getElementById('iraModal').classList.remove('hidden');
    });
}
if (progressBtn) {
    progressBtn.addEventListener('click', () => {
        document.getElementById('progressModal').classList.remove('hidden');
    });
}
if (integralizationBtn) {
    integralizationBtn.addEventListener('click', () => {
        document.getElementById('integralizationModal').classList.remove('hidden');
    });
}
if (courseChangeBtn) {
    courseChangeBtn.addEventListener('click', () => {
        document.getElementById('courseChangeModal').classList.remove('hidden');
    });
}

// Fechar todos os modais das ferramentas de progresso
const closeModalButtons = document.querySelectorAll('.closeModal');
if (closeModalButtons) {
    closeModalButtons.forEach(button => {
        button.addEventListener('click', () => {
            document.querySelectorAll('#iraModal, #progressModal, #integralizationModal, #courseChangeModal').forEach(modal => {
                modal.classList.add('hidden');
            });
        });
    });
}

// Adicionar disciplina na calculadora de IRA
const addDisciplineBtn = document.getElementById('addDiscipline');
if (addDisciplineBtn) {
    addDisciplineBtn.addEventListener('click', () => {
        const form = document.getElementById('iraCalculatorForm');
        const newRow = document.createElement('div');
        newRow.className = 'flex items-center space-x-2';
        newRow.innerHTML = `
            <input type="text" placeholder="Disciplina" class="flex-grow border border-gray-700 rounded-lg px-3 py-2 text-sm bg-black bg-opacity-40 text-white">
            <input type="number" min="0" max="10" step="0.1" placeholder="Nota" class="w-20 border border-gray-700 rounded-lg px-3 py-2 text-sm bg-black bg-opacity-40 text-white">
            <input type="number" min="1" max="10" placeholder="Créditos" class="w-20 border border-gray-700 rounded-lg px-3 py-2 text-sm bg-black bg-opacity-40 text-white">
        `;
        form.appendChild(newRow);
    });
}

// Calcular IRA simulado
const calculateIraBtn = document.getElementById('calculateIra');
if (calculateIraBtn) {
    calculateIraBtn.addEventListener('click', () => {
        // Simulação simples - em um caso real, seria calculado com base nos inputs
        const randomIra = (Math.random() * 1.5 + 7.5).toFixed(1);
        document.getElementById('simulatedIra').textContent = randomIra;
    });
}

// Simular mudança de curso
const simulateCourseChangeBtn = document.getElementById('simulateCourseChange');
if (simulateCourseChangeBtn) {
    simulateCourseChangeBtn.addEventListener('click', () => {
        const courseSelect = document.getElementById('targetCourse');
        if (courseSelect.value) {
            document.getElementById('courseComparisonResults').classList.remove('hidden');
        }
    }); 
}

function clearPrereqChainsColors() {
    const allBoxes = Array.from(document.querySelectorAll('.course-box'));
    allBoxes.forEach((box) => {
        // Remove o background color customizado
        box.style.background = '';
        box.style.color = '';
        // Restaura as classes padrão de status
        if (box.dataset.originalClass) {
            box.className = box.dataset.originalClass;
        }
    });
}