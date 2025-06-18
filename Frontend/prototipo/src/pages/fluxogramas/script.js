// Scripts da página de Fluxogramas

// Seleção dos elementos do DOM para o menu mobile
const btn = document.getElementById('menu-btn');
const menu = document.getElementById('mobile-menu');

// Alterna a exibição do menu mobile ao clicar no botão hamburger
btn.addEventListener('click', () => {
    btn.classList.toggle('open');
    menu.classList.toggle('active');
});

// Seleção dos elementos para busca e cards de cursos
const searchInput = document.getElementById('search-input');
const courseCards = document.querySelectorAll('.course-card');

// Filtra os cards de cursos conforme o texto digitado na busca
searchInput.addEventListener('input', (e) => {
    const searchTerm = e.target.value.toLowerCase();
    
    courseCards.forEach(card => {
        const title = card.querySelector('h3').textContent.toLowerCase();
        const description = card.querySelector('p').textContent.toLowerCase();
        
        if (title.includes(searchTerm) || description.includes(searchTerm)) {
            card.style.display = 'block';
        } else {
            card.style.display = 'none';
        }
    });
});

// Seleção dos botões de filtro e controle do filtro ativo
const filterButtons = document.querySelectorAll('.filter-button');
let activeFilter = 'all';

// Adiciona evento de clique para cada botão de filtro
filterButtons.forEach(button => {
    button.addEventListener('click', () => {
        // Remove a classe ativa de todos os botões
        filterButtons.forEach(btn => btn.classList.remove('active'));
        
        // Adiciona a classe ativa ao botão clicado
        button.classList.add('active');
        
        const filter = button.getAttribute('data-filter');
        activeFilter = filter;
        
        // Filtra os cards de acordo com a categoria
        courseCards.forEach(card => {
            const category = card.getAttribute('data-category');
            
            if (filter === 'all' || category === filter) {
                card.style.display = 'block';
            } else {
                card.style.display = 'none';
            }
        });
    });
});

// Efeitos de hover nos cards de curso para mostrar o preview do fluxograma
courseCards.forEach(card => {
    card.addEventListener('mouseenter', () => {
        const preview = card.querySelector('.flowchart-preview');
        if (preview) {
            preview.style.opacity = '1';
        }
    });
    
    card.addEventListener('mouseleave', () => {
        const preview = card.querySelector('.flowchart-preview');
        if (preview) {
            preview.style.opacity = '0.8';
        }
    });
});

// Cores dinâmicas para os cards de curso conforme a categoria
const courseColors = {
    'exatas': ['#4A1D96', '#E11D48'],
    'humanas': ['#EA580C', '#CA8A04'],
    'saude': ['#059669', '#0EA5E9']
};

courseCards.forEach(card => {
    const category = card.getAttribute('data-category');
    const colors = courseColors[category] || courseColors['exatas'];
    
    card.style.setProperty('--color-start', colors[0]);
    card.style.setProperty('--color-end', colors[1]);
});

// Scroll suave para navegação por âncoras internas
// Fecha o menu mobile ao clicar em um link de navegação
// para melhorar a experiência mobile
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth'
            });
            // Fecha o menu mobile se estiver aberto
            if (menu.classList.contains('active')) {
                btn.classList.remove('open');
                menu.classList.remove('active');
            }
        }
    });
}); 