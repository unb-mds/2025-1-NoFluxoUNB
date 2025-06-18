import { coursesData, equivalencesData, interestAreas } from './data.js';

// Elementos do DOM
const menuBtn = document.getElementById('menu-btn');
const mobileMenu = document.getElementById('mobile-menu');
const chatInput = document.getElementById('chat-input');
const sendButton = document.getElementById('send-button');
const chatMessages = document.getElementById('chat-messages');
const typingIndicator = document.getElementById('typing-indicator');
const interestTags = document.querySelectorAll('.interest-tag');
const addButtons = document.querySelectorAll('.add-button');
const equivalentModal = document.getElementById('equivalent-modal');
const closeModalBtn = document.getElementById('close-modal');
const confirmEquivalentBtn = document.getElementById('confirm-equivalent');
const selectedCoursesContainer = document.querySelector('.space-y-3');

// Estado do chat
let selectedInterests = new Set();
let selectedCourses = new Set();

// Funções auxiliares
function createMessageElement(message, isUser = false) {
    const messageDiv = document.createElement('div');
    messageDiv.className = `flex ${isUser ? 'justify-end' : 'items-start gap-3'}`;
    
    if (!isUser) {
        const avatar = document.createElement('div');
        avatar.className = 'bot-avatar';
        avatar.textContent = 'A';
        messageDiv.appendChild(avatar);
    }
    
    const content = document.createElement('div');
    content.className = `message ${isUser ? 'message-user' : 'message-bot'}`;
    content.innerHTML = `<p>${message}</p>`;
    messageDiv.appendChild(content);
    
    return messageDiv;
}

function showTypingIndicator() {
    typingIndicator.classList.remove('hidden');
}

function hideTypingIndicator() {
    typingIndicator.classList.add('hidden');
}

function scrollToBottom() {
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function getRecommendedCourses(interests) {
    const recommendedCourses = new Set();
    
    interests.forEach(interest => {
        if (interestAreas[interest]) {
            interestAreas[interest].forEach(courseCode => {
                recommendedCourses.add(courseCode);
            });
        }
    });
    
    return Array.from(recommendedCourses).map(code => coursesData[code]);
}

function updateSelectedCoursesView() {
    if (selectedCourses.size === 0) {
        selectedCoursesContainer.innerHTML = `
            <div class="text-center py-6 text-gray-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto mb-2 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <p>Nenhuma matéria selecionada</p>
            </div>
        `;
        return;
    }

    const coursesHTML = Array.from(selectedCourses).map(courseCode => {
        const course = coursesData[courseCode];
        return `
            <div class="course-card rounded-lg p-3">
                <div class="flex justify-between items-start">
                    <div>
                        <h3 class="text-white font-bold">${course.code} - ${course.name}</h3>
                        <p class="text-gray-300 text-sm">${course.department}</p>
                        <div class="flex items-center mt-1">
                            <span class="text-xs bg-purple-700 bg-opacity-50 px-2 py-0.5 rounded mr-2">${course.credits} créditos</span>
                            <span class="text-xs bg-blue-700 bg-opacity-50 px-2 py-0.5 rounded">${course.type}</span>
                        </div>
                    </div>
                    <button class="remove-button text-white p-1 rounded-full" data-course-code="${course.code}">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                    </button>
                </div>
            </div>
        `;
    }).join('');

    selectedCoursesContainer.innerHTML = coursesHTML;

    // Adicionar event listeners para os botões de remover
    document.querySelectorAll('.remove-button').forEach(button => {
        button.addEventListener('click', () => {
            const courseCode = button.dataset.courseCode;
            selectedCourses.delete(courseCode);
            updateSelectedCoursesView();
        });
    });
}

function createCourseCard(course) {
    return `
        <div class="course-card rounded-lg p-3">
            <div class="flex justify-between items-start">
                <div>
                    <h3 class="text-white font-bold">${course.code} - ${course.name}</h3>
                    <p class="text-gray-300 text-sm">${course.department}</p>
                    <div class="flex items-center mt-1">
                        <span class="text-xs bg-purple-700 bg-opacity-50 px-2 py-0.5 rounded mr-2">${course.credits} créditos</span>
                        <span class="text-xs bg-blue-700 bg-opacity-50 px-2 py-0.5 rounded">${course.type}</span>
                    </div>
                </div>
                <div class="flex gap-2">
                    <button class="info-button text-white p-1 rounded-full hover:bg-blue-600 transition-colors duration-300" data-course-code="${course.code}">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                    </button>
                    <button class="add-button text-white p-1 rounded-full hover:bg-purple-600 transition-colors duration-300" data-course-code="${course.code}">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                        </svg>
                    </button>
                </div>
            </div>
            <p class="text-gray-300 text-sm mt-2">${course.description}</p>
        </div>
    `;
}

function showEquivalentModal(courseCode) {
    const course = coursesData[courseCode];
    const equivalents = equivalencesData[courseCode] || [];
    const prerequisites = course.prerequisites || [];
    const corequisites = course.corequisites || [];
    
    const modalContent = document.querySelector('#equivalent-modal .modal-content');
    modalContent.innerHTML = `
        <h2 class="text-white text-xl font-bold mb-4">Informações da Disciplina</h2>
        <div class="space-y-4">
            <div class="course-card rounded-lg p-4 bg-opacity-50">
                <h3 class="text-white font-bold text-lg mb-2">${course.code} - ${course.name}</h3>
                <p class="text-gray-300 mb-2">${course.description}</p>
                <div class="flex flex-wrap gap-2 mb-3">
                    <span class="text-xs bg-purple-700 bg-opacity-50 px-2 py-0.5 rounded">${course.credits} créditos</span>
                    <span class="text-xs bg-blue-700 bg-opacity-50 px-2 py-0.5 rounded">${course.type}</span>
                    <span class="text-xs bg-green-700 bg-opacity-50 px-2 py-0.5 rounded">${course.department}</span>
                </div>
            </div>

            ${prerequisites.length > 0 ? `
                <div class="mt-4">
                    <h4 class="text-white font-bold mb-2">Pré-requisitos:</h4>
                    <div class="space-y-2">
                        ${prerequisites.map(prereq => `
                            <div class="bg-gray-800 bg-opacity-50 rounded p-2">
                                <span class="text-white">${prereq.code} - ${prereq.name}</span>
                            </div>
                        `).join('')}
                    </div>
                </div>
            ` : ''}

            ${corequisites.length > 0 ? `
                <div class="mt-4">
                    <h4 class="text-white font-bold mb-2">Co-requisitos:</h4>
                    <div class="space-y-2">
                        ${corequisites.map(coreq => `
                            <div class="bg-gray-800 bg-opacity-50 rounded p-2">
                                <span class="text-white">${coreq.code} - ${coreq.name}</span>
                            </div>
                        `).join('')}
                    </div>
                </div>
            ` : ''}

            ${equivalents.length > 0 ? `
                <div class="mt-4">
                    <h4 class="text-white font-bold mb-2">Disciplinas Equivalentes:</h4>
                    <div class="space-y-2">
                        ${equivalents.map(equivalent => `
                            <div class="bg-gray-800 bg-opacity-50 rounded p-2 flex justify-between items-center">
                                <span class="text-white">${equivalent.code} - ${equivalent.name}</span>
                                <span class="text-xs bg-blue-700 bg-opacity-50 px-2 py-0.5 rounded">
                                    ${equivalent.equivalence}% equivalente
                                </span>
                            </div>
                        `).join('')}
                    </div>
                </div>
            ` : ''}
        </div>
    `;
    
    equivalentModal.classList.remove('hidden');
}

// Inicializa os event listeners
function initializeEventListeners() {
    // Menu mobile
    menuBtn.addEventListener('click', () => {
        menuBtn.classList.toggle('open');
        mobileMenu.classList.toggle('active');
    });

    // Botões de interesse
    interestTags.forEach(tag => {
        tag.addEventListener('click', () => {
            const interest = tag.textContent.trim();
        
            if (selectedInterests.has(interest)) {
                selectedInterests.delete(interest);
                tag.classList.remove('selected');
            } else {
            selectedInterests.add(interest);
                tag.classList.add('selected');
            }

            // Mostra o indicador de digitação
            showTypingIndicator();

            // Simula o tempo de processamento
            setTimeout(() => {
                hideTypingIndicator();
                
                // Obtém e mostra os cursos recomendados
                const recommendedCourses = getRecommendedCourses(Array.from(selectedInterests));
                
                if (recommendedCourses.length > 0) {
                    const coursesHTML = recommendedCourses.map(course => createCourseCard(course)).join('');
                    const message = `
                        <p>Baseado nos seus interesses, aqui estão algumas disciplinas que você pode gostar:</p>
                        <div class="recommended-courses mt-4 space-y-4">
                    ${coursesHTML}
                </div>
            `;
            
                    const messageElement = createMessageElement(message);
                    chatMessages.appendChild(messageElement);
                } else {
                    const messageElement = createMessageElement('Não encontrei disciplinas específicas para esses interesses. Tente selecionar outras áreas!');
            chatMessages.appendChild(messageElement);
                }
                
            scrollToBottom();
            }, 1000);
        });
    });

    // Chat input
    chatInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            sendMessage();
        }
    });

    sendButton.addEventListener('click', sendMessage);

    // Botões de adicionar curso
    document.addEventListener('click', (e) => {
        if (e.target.closest('.add-button')) {
            const courseCode = e.target.closest('.add-button').dataset.courseCode;
            if (courseCode && !selectedCourses.has(courseCode)) {
                selectedCourses.add(courseCode);
                updateSelectedCoursesView();
            }
        } else if (e.target.closest('.info-button')) {
            const courseCode = e.target.closest('.info-button').dataset.courseCode;
            if (courseCode) {
                showEquivalentModal(courseCode);
            }
        }
    });

    // Modal de equivalências
    if (closeModalBtn) {
        closeModalBtn.addEventListener('click', () => {
            equivalentModal.classList.add('hidden');
        });
    }

    if (confirmEquivalentBtn) {
        confirmEquivalentBtn.addEventListener('click', () => {
            equivalentModal.classList.add('hidden');
    });
    }
}

// Inicializa os event listeners quando o DOM estiver carregado
document.addEventListener('DOMContentLoaded', initializeEventListeners);

function sendMessage() {
    const message = chatInput.value.trim();
    if (message === '') return;
    
    // Add user message to chat
    const userMessageElement = createMessageElement(message, true);
    chatMessages.appendChild(userMessageElement);
    
    // Clear input
    chatInput.value = '';
    
    // Show typing indicator
    showTypingIndicator();
    scrollToBottom();
    
    // Simulate bot response after delay
    setTimeout(() => {
        hideTypingIndicator();
        
        const botResponse = `
            <p>Obrigado por compartilhar seus interesses! Baseado no que você mencionou, aqui estão mais algumas matérias que podem te interessar:</p>
            <div class="mt-4 space-y-3">
                ${getRecommendedCourses(Array.from(selectedInterests))
                    .map(createCourseCard)
                    .join('')}
            </div>
            <p class="mt-4">Você tem algum semestre específico em mente para adicionar essas matérias?</p>
        `;
        
        const botMessageElement = createMessageElement(botResponse);
        chatMessages.appendChild(botMessageElement);
        scrollToBottom();
        
        // Adicionar event listeners para os novos botões
        addAddButtonListeners();
    }, 1500);
}

// Atualizar o event listener para os botões de adicionar e informações
function addAddButtonListeners() {
    // Event listener para botões de adicionar
    document.querySelectorAll('.add-button').forEach(button => {
        button.addEventListener('click', () => {
            const courseCode = button.dataset.courseCode;
            if (!selectedCourses.has(courseCode)) {
                selectedCourses.add(courseCode);
                updateSelectedCoursesView();
                
                // Feedback visual
                button.classList.add('bg-green-500');
                setTimeout(() => {
                    button.classList.remove('bg-green-500');
                }, 500);
            }
        });
    });

    // Event listener para botões de informação
    document.querySelectorAll('.info-button').forEach(button => {
        button.addEventListener('click', () => {
            const courseCode = button.dataset.courseCode;
            showEquivalentModal(courseCode);
        });
    });
}

// Auto-scroll chat to bottom on load
window.addEventListener('load', scrollToBottom);

// Adicionar evento ao botão de adicionar fluxograma
document.getElementById('add-fluxogram-btn').addEventListener('click', function() {
    document.getElementById('fluxogram-file-input').click();
}); 