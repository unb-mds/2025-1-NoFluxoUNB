// Elementos do DOM
const menuBtn = document.getElementById('menu-btn');
const mobileMenu = document.getElementById('mobile-menu');

// Toggle do menu hamburguer
menuBtn.addEventListener('click', function() {
    menuBtn.classList.toggle('open');
    mobileMenu.classList.toggle('active');
});

// Fechar menu mobile ao clicar fora
document.addEventListener('click', function(e) {
    if (!menuBtn.contains(e.target) && !mobileMenu.contains(e.target) && mobileMenu.classList.contains('active')) {
        menuBtn.classList.remove('open');
        mobileMenu.classList.remove('active');
    }
});

// Adicionar mais elementos de graffiti dinâmicos
function createMoreGraffitiElements() {
    const graffitiContainer = document.querySelector('.graffiti-elements');
    const colors = ['#4A1D96', '#E11D48', '#EA580C', '#CA8A04', '#FF5CA0', '#4ade80', '#a78bfa'];
    
    // Criar pingos de graffiti aleatórios
    for (let i = 0; i < 8; i++) {
        const drip = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        drip.setAttribute('width', '50');
        drip.setAttribute('height', '100');
        drip.setAttribute('viewBox', '0 0 50 100');
        drip.style.position = 'absolute';
        drip.style.top = Math.random() * 80 + '%';
        drip.style.left = Math.random() * 90 + '%';
        drip.style.opacity = (Math.random() * 0.3 + 0.2).toString();
        
        const color = colors[Math.floor(Math.random() * colors.length)];
        const height = Math.random() * 50 + 30;
        
        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', `M25,0 Q20,${height/2} 25,${height} Q30,${height/2} 25,0 Z`);
        path.setAttribute('fill', color);
        
        drip.appendChild(path);
        graffitiContainer.appendChild(drip);
    }
    
    // Criar pontos de graffiti aleatórios
    for (let i = 0; i < 30; i++) {
        const dot = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        dot.setAttribute('width', '10');
        dot.setAttribute('height', '10');
        dot.setAttribute('viewBox', '0 0 10 10');
        dot.style.position = 'absolute';
        dot.style.top = Math.random() * 100 + '%';
        dot.style.left = Math.random() * 100 + '%';
        dot.style.opacity = (Math.random() * 0.5 + 0.2).toString();
        
        const color = colors[Math.floor(Math.random() * colors.length)];
        
        const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        circle.setAttribute('cx', '5');
        circle.setAttribute('cy', '5');
        circle.setAttribute('r', (Math.random() * 3 + 2).toString());
        circle.setAttribute('fill', color);
        
        dot.appendChild(circle);
        graffitiContainer.appendChild(dot);
    }
}

// Criar mais elementos de graffiti ao carregar
window.addEventListener('load', createMoreGraffitiElements); 