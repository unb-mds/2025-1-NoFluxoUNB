// Dados das disciplinas
const coursesData = {
    'CIC0097': {
        code: 'CIC0097',
        name: 'Bancos de Dados',
        department: 'Departamento de Ciência da Computação',
        description: 'Modelagem de dados, SQL, normalização e design de bancos de dados relacionais.',
        credits: 4,
        type: 'Optativa',
        prerequisites: [],
        professors: ['Prof. Dr. João Silva', 'Prof. Dra. Maria Santos'],
        schedule: [
            { class: 'A', time: 'Segunda e Quarta, 14:00 - 15:50' },
            { class: 'B', time: 'Terça e Quinta, 10:00 - 11:50' }
        ]
    },
    'EST0023': {
        code: 'EST0023',
        name: 'Probabilidade e Estatística',
        department: 'Departamento de Estatística',
        description: 'Fundamentos de probabilidade, estatística descritiva e inferencial para análise de dados.',
        credits: 4,
        type: 'Optativa',
        prerequisites: [],
        professors: ['Prof. Dr. Carlos Oliveira', 'Prof. Dra. Ana Lima'],
        schedule: [
            { class: 'A', time: 'Segunda e Quarta, 10:00 - 11:50' },
            { class: 'B', time: 'Terça e Quinta, 14:00 - 15:50' }
        ]
    },
    'CIC0199': {
        code: 'CIC0199',
        name: 'Tópicos em IA: Machine Learning',
        department: 'Departamento de Ciência da Computação',
        description: 'Algoritmos de aprendizado de máquina, redes neurais e aplicações práticas.',
        credits: 4,
        type: 'Módulo Livre',
        prerequisites: [],
        professors: ['Prof. Dr. Pedro Costa', 'Prof. Dra. Juliana Almeida'],
        schedule: [
            { class: 'A', time: 'Segunda e Quarta, 16:00 - 17:50' },
            { class: 'B', time: 'Terça e Quinta, 08:00 - 09:50' }
        ]
    },
    'CIC0135': {
        code: 'CIC0135',
        name: 'Introdução à Ciência de Dados',
        department: 'Departamento de Ciência da Computação',
        description: 'Fundamentos de ciência de dados, visualização e análise exploratória.',
        credits: 4,
        type: 'Optativa',
        prerequisites: [],
        professors: ['Prof. Dr. Lucas Ferreira', 'Prof. Dra. Beatriz Santos'],
        schedule: [
            { class: 'A', time: 'Terça e Quinta, 16:00 - 17:50' },
            { class: 'B', time: 'Segunda e Quarta, 08:00 - 09:50' }
        ]
    },
    'CIC0202': {
        code: 'CIC0202',
        name: 'Programação Competitiva',
        department: 'Departamento de Ciência da Computação',
        description: 'Técnicas avançadas de programação e resolução de problemas algorítmicos.',
        credits: 4,
        type: 'Módulo Livre',
        prerequisites: [],
        professors: ['Prof. Dr. Rafael Oliveira', 'Prof. Dra. Camila Lima'],
        schedule: [
            { class: 'A', time: 'Sexta, 14:00 - 17:50' },
            { class: 'B', time: 'Sábado, 08:00 - 11:50' }
        ]
    }
};

// Dados das equivalências
const equivalencesData = {
    'CIC0097': [
        {
            code: 'CIC0180',
            name: 'Banco de Dados 1',
            department: 'Departamento de Ciência da Computação',
            credits: 4,
            equivalence: 100
        },
        {
            code: 'ENE0334',
            name: 'Bancos de Dados para Engenharia',
            department: 'Departamento de Engenharia Elétrica',
            credits: 4,
            equivalence: 90
        }
    ]
};

// Áreas de interesse e suas disciplinas relacionadas
const interestAreas = {
    'Programação': ['CIC0202', 'CIC0199'],
    'Dados': ['CIC0097', 'EST0023', 'CIC0135', 'CIC0199'],
    'Design': ['CIC0135'],
    'Gestão': ['CIC0097'],
    'Pesquisa': ['CIC0199', 'EST0023'],
    'Inovação': ['CIC0202', 'CIC0199']
};

export { coursesData, equivalencesData, interestAreas }; 