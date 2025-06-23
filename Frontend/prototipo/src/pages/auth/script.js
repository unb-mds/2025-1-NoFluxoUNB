document.addEventListener('DOMContentLoaded', function() {
    // Elementos do DOM
    const loginForm = document.getElementById('loginForm');
    const signupForm = document.getElementById('signupForm');
    const forgotPasswordForm = document.getElementById('forgotPasswordForm');
    const anonymousLoginForm = document.getElementById('anonymousLoginForm');
    const showSignupBtn = document.getElementById('showSignupBtn');
    const showLoginBtn = document.getElementById('showLoginBtn');
    const menuBtn = document.getElementById('menu-btn');
    const mobileMenu = document.getElementById('mobile-menu');
    const successModal = document.getElementById('successModal');
    const successOkBtn = document.getElementById('successOkBtn');

    // Toggle de visibilidade da senha
    const togglePassword = document.getElementById('togglePassword');
    const toggleNewPassword = document.getElementById('toggleNewPassword');
    const toggleConfirmPassword = document.getElementById('toggleConfirmPassword');
    const passwordInput = document.getElementById('password');
    const newPasswordInput = document.getElementById('newPassword');
    const confirmPasswordInput = document.getElementById('confirmPassword');

    // Função para mostrar/esconder formulários
    function showForm(formToShow) {
        // Esconder todos os formulários primeiro
        [loginForm, signupForm, forgotPasswordForm, anonymousLoginForm].forEach(form => {
            form.classList.add('hidden');
            form.classList.remove('slide-in');
        });
        
        // Mostrar o formulário solicitado
        formToShow.classList.remove('hidden');
        formToShow.classList.add('slide-in');
    }

    // Event listeners para alternar entre formulários
    showSignupBtn.addEventListener('click', () => showForm(signupForm));
    showLoginBtn.addEventListener('click', () => showForm(loginForm));

    // Event listeners para recuperação de senha
    document.getElementById('forgotPasswordLink').addEventListener('click', (e) => {
        e.preventDefault();
        showForm(forgotPasswordForm);
    });

    document.getElementById('backToLoginFromForgot').addEventListener('click', (e) => {
        e.preventDefault();
        showForm(loginForm);
    });

    // Event listeners para login anônimo
    document.getElementById('anonymousLoginBtn').addEventListener('click', (e) => {
        e.preventDefault();
        showForm(anonymousLoginForm);
    });

    document.getElementById('backToLoginFromAnonymous').addEventListener('click', (e) => {
        e.preventDefault();
        showForm(loginForm);
    });

    // Menu mobile
    menuBtn.addEventListener('click', function() {
        menuBtn.classList.toggle('open');
        mobileMenu.classList.toggle('active');
    });

    // Toggle de visibilidade da senha
    togglePassword.addEventListener('click', function() {
        const type = passwordInput.getAttribute('type') === 'password' ? 'text' : 'password';
        passwordInput.setAttribute('type', type);
    });

    toggleNewPassword.addEventListener('click', function() {
        const type = newPasswordInput.getAttribute('type') === 'password' ? 'text' : 'password';
        newPasswordInput.setAttribute('type', type);
    });

    toggleConfirmPassword.addEventListener('click', function() {
        const type = confirmPasswordInput.getAttribute('type') === 'password' ? 'text' : 'password';
        confirmPasswordInput.setAttribute('type', type);
    });

    // Função para mostrar modal de sucesso
    function showSuccessModal(title, message) {
        document.getElementById('successTitle').textContent = title;
        document.getElementById('successMessage').textContent = message;
        successModal.classList.remove('hidden');
    }

    // Fechar modal de sucesso
    successOkBtn.addEventListener('click', function() {
        successModal.classList.add('hidden');
    });

    // Login com Google
    document.getElementById('googleLoginBtn').addEventListener('click', function() {
        showSuccessModal('Login com Google', 'Você foi autenticado com Google com sucesso.');
        setTimeout(() => {
            window.location.href = '../historico/index.html';
        }, 1500);
    });

    // Login com Google (Cadastro)
    document.getElementById('googleSignUpBtn').addEventListener('click', function() {
        showSuccessModal('Cadastro com Google', 'Conta criada com sucesso!');
        setTimeout(() => {
            window.location.href = '../historico/index.html';
        }, 1500);
    });

    // Login anônimo
    document.getElementById('confirmAnonymousBtn').addEventListener('click', function() {
        showSuccessModal('Login anônimo', 'Você entrou como usuário anônimo.');
        setTimeout(() => {
            window.location.href = '../fluxogramas/index.html';
        }, 1500);
    });

    // Submissão do formulário de login
    loginForm.querySelector('form').addEventListener('submit', function(e) {
        e.preventDefault();
        const email = document.getElementById('email').value;
        const password = document.getElementById('password').value;
        const rememberMe = document.getElementById('rememberMe').checked;

        // Implementar lógica de login
        console.log('Login:', { email, password, rememberMe });
        showSuccessModal('Login realizado com sucesso!', 'Bem-vindo de volta!');
        setTimeout(() => {
            window.location.href = '../historico/index.html';
        }, 1500);
    });

    // Validação de senha no cadastro
    function validatePassword(password) {
        return password.length >= 8;
    }

    // Event listeners para Termos e Política
    document.getElementById('termsLink').addEventListener('click', function(e) {
        e.preventDefault();
        // Aqui você pode implementar a lógica para mostrar os termos de serviço
        // Por exemplo, abrir um modal ou redirecionar para uma página
        alert('Termos de Serviço serão implementados em breve.');
    });

    document.getElementById('privacyLink').addEventListener('click', function(e) {
        e.preventDefault();
        // Aqui você pode implementar a lógica para mostrar a política de privacidade
        // Por exemplo, abrir um modal ou redirecionar para uma página
        alert('Política de Privacidade será implementada em breve.');
    });

    // Submissão do formulário de cadastro com validação de senha
    signupForm.querySelector('form').addEventListener('submit', function(e) {
        e.preventDefault();
        const name = document.getElementById('newName').value;
        const email = document.getElementById('newEmail').value;
        const password = document.getElementById('newPassword').value;
        const confirmPassword = document.getElementById('confirmPassword').value;
        const termsAccepted = document.getElementById('termsCheck').checked;

        // Validações
        if (!validatePassword(password)) {
            alert('A senha deve ter pelo menos 8 caracteres!');
            return;
        }

        if (password !== confirmPassword) {
            alert('As senhas não coincidem!');
            return;
        }

        if (!termsAccepted) {
            alert('Você precisa aceitar os termos de serviço!');
            return;
        }

        // Implementar lógica de cadastro
        console.log('Cadastro:', { name, email, password, termsAccepted });
        showSuccessModal('Cadastro realizado com sucesso!', 'Bem-vindo ao NoFluxo UNB!');
        setTimeout(() => {
            window.location.href = '../historico/index.html';
        }, 1500);
    });

    // Submissão do formulário de recuperação de senha
    forgotPasswordForm.querySelector('form').addEventListener('submit', function(e) {
        e.preventDefault();
        const email = document.getElementById('recoveryEmail').value;
        showSuccessModal('Email enviado!', `Um link de recuperação foi enviado para ${email}.`);
        setTimeout(() => {
            showForm(loginForm);
        }, 2000);
    });

    // Fechar modal ao clicar fora
    window.addEventListener('click', function(e) {
        if (e.target === successModal) {
            successModal.classList.add('hidden');
        }
    });

    // Fechar menu mobile ao clicar fora
    document.addEventListener('click', function(e) {
        if (!menuBtn.contains(e.target) && !mobileMenu.contains(e.target) && mobileMenu.classList.contains('active')) {
            menuBtn.classList.remove('open');
            mobileMenu.classList.remove('active');
        }
    });
}); 