# Documentação do Banco de Dados - NoFluxoUNB

Este documento descreve o esquema atual do banco de dados utilizado na aplicação NoFluxoUNB.

## Esquema do Banco de Dados

![Esquema do Banco de Dados](/assets/supabase.png)

## Visão Geral

O banco de dados é composto por cinco tabelas principais que gerenciam informações sobre cursos, matérias, usuários e suas relações. A estrutura foi simplificada para otimizar consultas e facilitar o gerenciamento de fluxogramas curriculares.

## Tabelas

### `cursos`

Armazena informações sobre os cursos oferecidos pela universidade.

| Coluna        | Tipo       | Descrição                                         |
| :------------ | :--------- | :------------------------------------------------ |
| `id_curso`    | `bigint`   | Chave primária, identificador único do curso (IDENTITY). |
| `created_at`  | `timestamptz` | Carimbo de data/hora de criação do registro.     |
| `nome_curso`  | `text`     | Nome completo do curso.                           |

**Exemplo:**
- `id_curso: 1, nome_curso: "ADMINISTRAÇÃO"`
- `id_curso: 2, nome_curso: "CIÊNCIA DA COMPUTAÇÃO"`

### `materias`

Armazena informações detalhadas sobre cada matéria oferecida.

| Coluna        | Tipo       | Descrição                                         |
| :------------ | :--------- | :------------------------------------------------ |
| `id_materia`  | `bigint`   | Chave primária, identificador único da matéria (IDENTITY). |
| `created_at`  | `timestamptz` | Carimbo de data/hora de criação do registro.     |
| `nome_materia`| `text`     | Nome completo da matéria.                         |
| `codigo_materia` | `text`    | Código único da matéria (ex: ADM0023).           |
| `carga_horaria` | `text`    | Carga horária da matéria (ex: "60h").            |

**Exemplo:**
- `id_materia: 1, codigo_materia: "ADM0023", nome_materia: "INTRODUÇÃO À ADMINISTRAÇÃO", carga_horaria: "60h"`

### `materias_por_curso`

Tabela de relacionamento que conecta matérias aos cursos e define em qual nível/semestre cada matéria é oferecida.

| Coluna        | Tipo       | Descrição                                         |
| :------------ | :--------- | :------------------------------------------------ |
| `id_materia_curso` | `bigint` | Chave primária, identificador único da relação (IDENTITY). |
| `created_at`  | `timestamptz` | Carimbo de data/hora de criação do registro.     |
| `id_materia`  | `bigint`   | Chave estrangeira referenciando `materias.id_materia`. |
| `id_curso`    | `bigint`   | Chave estrangeira referenciando `cursos.id_curso`. |
| `nivel`       | `bigint`   | Nível/semestre em que a matéria é oferecida (0 = optativa, 1-12 = semestres). |

**Exemplo:**
- `id_materia_curso: 1, id_materia: 1, id_curso: 1, nivel: 1` (Matéria no 1º semestre)
- `id_materia_curso: 2, id_materia: 5, id_curso: 1, nivel: 0` (Matéria optativa)

### `users`

Armazena informações dos usuários do sistema.

| Coluna        | Tipo       | Descrição                                         |
| :------------ | :--------- | :------------------------------------------------ |
| `id_user`     | `bigint`   | Chave primária, identificador único do usuário (IDENTITY). |
| `created_at`  | `timestamptz` | Carimbo de data/hora de criação do registro.     |
| `email`       | `text`     | Email único do usuário.                           |
| `nome_completo` | `text`    | Nome completo do usuário.                         |
| `hash_senha`  | `text`     | Hash da senha do usuário (criptografada).        |

### `dados_users`

Armazena dados específicos de cada usuário, incluindo seu fluxograma atual.

| Coluna        | Tipo       | Descrição                                         |
| :------------ | :--------- | :------------------------------------------------ |
| `id_dado_user` | `bigint`  | Chave primária, identificador único dos dados (IDENTITY). |
| `created_at`  | `timestamptz` | Carimbo de data/hora de criação do registro.     |
| `id_user`     | `bigint`   | Chave estrangeira referenciando `users.id_user`. |
| `fluxograma_atual` | `text` | JSON com o estado atual do fluxograma do usuário (padrão: '{}'). |

## Relacionamentos

### Relacionamentos Principais

1. **`cursos` ↔ `materias_por_curso`**
   - Um curso pode ter muitas matérias (1:N)
   - Relacionamento através de `id_curso`

2. **`materias` ↔ `materias_por_curso`**
   - Uma matéria pode estar em muitos cursos (1:N)
   - Relacionamento através de `id_materia`

3. **`users` ↔ `dados_users`**
   - Um usuário tem um conjunto de dados (1:1)
   - Relacionamento através de `id_user`

### Estrutura de Níveis

O campo `nivel` na tabela `materias_por_curso` segue a seguinte convenção:

- **`nivel = 0`**: Matérias optativas
- **`nivel = 1`**: 1º semestre
- **`nivel = 2`**: 2º semestre
- **`nivel = 3`**: 3º semestre
- ...
- **`nivel = 12`**: 12º semestre (máximo)

## Vantagens da Nova Estrutura

### 1. **Simplicidade**
- Eliminação de tabelas intermediárias desnecessárias
- Consultas mais diretas e eficientes

### 2. **Flexibilidade**
- Uma matéria pode estar em múltiplos cursos
- Fácil identificação de matérias optativas (nível 0)

### 3. **Performance**
- Menos JOINs necessários para consultas comuns
- Índices mais eficientes

### 4. **Manutenibilidade**
- Estrutura mais clara e intuitiva
- Menos complexidade no código de integração

## Consultas Comuns

### Buscar todas as matérias de um curso
```sql
SELECT m.nome_materia, m.codigo_materia, mpc.nivel
FROM materias_por_curso mpc
JOIN materias m ON m.id_materia = mpc.id_materia
JOIN cursos c ON c.id_curso = mpc.id_curso
WHERE c.nome_curso = 'ADMINISTRAÇÃO'
ORDER BY mpc.nivel;
```

### Buscar matérias optativas de um curso
```sql
SELECT m.nome_materia, m.codigo_materia
FROM materias_por_curso mpc
JOIN materias m ON m.id_materia = mpc.id_materia
JOIN cursos c ON c.id_curso = mpc.id_curso
WHERE c.nome_curso = 'ADMINISTRAÇÃO' AND mpc.nivel = 0;
```

### Buscar matérias de um semestre específico
```sql
SELECT m.nome_materia, m.codigo_materia
FROM materias_por_curso mpc
JOIN materias m ON m.id_materia = mpc.id_materia
JOIN cursos c ON c.id_curso = mpc.id_curso
WHERE c.nome_curso = 'ADMINISTRAÇÃO' AND mpc.nivel = 1;
```

## Migração de Dados

A nova estrutura foi projetada para ser compatível com os dados existentes, permitindo uma migração suave sem perda de informações. O script de integração (`integracao_banco.py`) já está adaptado para trabalhar com esta nova estrutura.