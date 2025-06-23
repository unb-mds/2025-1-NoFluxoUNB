// Dados das disciplinas
export const coursesData = {
    'CIC0004': {
        code: 'CIC0004',
        name: 'Algoritmos e Programação de Computadores',
        department: 'Ciência da Computação',
        credits: 6,
        type: 'Obrigatória',
        description: 'Introdução à programação, algoritmos e resolução de problemas computacionais.'
    },
    'MAT0025': {
        code: 'MAT0025',
        name: 'Cálculo 1',
        department: 'Matemática',
        credits: 6,
        type: 'Obrigatória',
        description: 'Funções, limites, derivadas e integrais de funções de uma variável real.'
    },
    'ENE0026': {
        code: 'ENE0026',
        name: 'Circuitos Digitais',
        department: 'Engenharia Elétrica',
        credits: 4,
        type: 'Obrigatória',
        description: 'Sistemas digitais, portas lógicas e circuitos combinacionais.'
    },
    'CIC0197': {
        code: 'CIC0197',
        name: 'Técnicas de Programação 1',
        department: 'Ciência da Computação',
        credits: 4,
        type: 'Obrigatória',
        description: 'Programação orientada a objetos, herança e polimorfismo.'
    },
    'CIC0198': {
        code: 'CIC0198',
        name: 'Técnicas de Programação 2',
        department: 'Ciência da Computação',
        credits: 4,
        type: 'Obrigatória',
        description: 'Estruturas de dados avançadas e análise de algoritmos.'
    },
    'CIC0199': {
        code: 'CIC0199',
        name: 'Teoria e Aplicação de Grafos',
        department: 'Ciência da Computação',
        credits: 4,
        type: 'Obrigatória',
        description: 'Teoria dos grafos e suas aplicações em problemas computacionais.'
    },
    'CIC0203': {
        code: 'CIC0203',
        name: 'Engenharia de Software',
        department: 'Ciência da Computação',
        credits: 4,
        type: 'Obrigatória',
        description: 'Processo de desenvolvimento de software e metodologias ágeis.'
    },
    'CIC0182': {
        code: 'CIC0182',
        name: 'Sistemas de Banco de Dados',
        department: 'Ciência da Computação',
        credits: 4,
        type: 'Obrigatória',
        description: 'Modelagem e implementação de bancos de dados relacionais.'
    },
    'CIC0202': {
        code: 'CIC0202',
        name: 'Programação Competitiva',
        department: 'Ciência da Computação',
        credits: 4,
        type: 'Optativa',
        description: 'Técnicas avançadas de programação e resolução de problemas.'
    },
    'CIC0189': {
        code: 'CIC0189',
        name: 'Programação para Sistemas Paralelos e Distribuídos',
        department: 'Ciência da Computação',
        credits: 4,
        type: 'Optativa',
        description: 'Programação paralela e distribuída, threads e processos.'
    },
    'CIC0097': {
        code: 'CIC0097',
        name: 'Bancos de Dados',
        department: 'Ciência da Computação',
        credits: 4,
        type: 'Optativa',
        description: 'Modelagem de dados, SQL, normalização e design de bancos de dados relacionais.'
    },
    'EST0023': {
        code: 'EST0023',
        name: 'Probabilidade e Estatística',
        department: 'Estatística',
        credits: 4,
        type: 'Optativa',
        description: 'Fundamentos de probabilidade, estatística descritiva e inferencial para análise de dados.'
    },
    'CIC0135': {
        code: 'CIC0135',
        name: 'Introdução à Ciência de Dados',
        department: 'Ciência da Computação',
        credits: 4,
        type: 'Optativa',
        description: 'Fundamentos de ciência de dados, visualização e análise exploratória.'
    }
};

// Dados de equivalências entre disciplinas
export const equivalencesData = {
    'CIC0004': [
        {
            code: 'CIC0007',
            name: 'Introdução à Ciência da Computação',
            equivalence: 80
        }
    ],
    'CIC0197': [
        {
            code: 'CIC0090',
            name: 'Estruturas de Dados',
            equivalence: 90
        }
    ],
    'CIC0097': [
        {
            code: 'CIC0180',
            name: 'Banco de Dados 1',
            equivalence: 100
        },
        {
            code: 'ENE0334',
            name: 'Bancos de Dados para Engenharia',
            equivalence: 90
        }
    ]
};

// Áreas de interesse e disciplinas relacionadas
export const interestAreas = {
    'Programação': ['CIC0004', 'CIC0197', 'CIC0198', 'CIC0202'],
    'Dados': ['CIC0097', 'CIC0182', 'EST0023', 'CIC0135', 'MAT0025'],
    'Design': ['CIC0203'],
    'Gestão': ['CIC0203'],
    'Pesquisa': ['CIC0199', 'MAT0025'],
    'Inovação': ['CIC0189', 'ENE0026']
}; 