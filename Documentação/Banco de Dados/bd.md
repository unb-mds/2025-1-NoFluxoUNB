# Documentação do Banco de Dados

Este documento descreve o esquema do banco de dados utilizado na aplicação.

## Esquema do Banco de Dados

![Esquema do Banco de Dados](/assets/supabase-schema-lijmhbstgdinsukovyfl.png)

## Visão Geral

O banco de dados é composto por cinco tabelas principais que gerenciam informações sobre cursos, matérias e níveis de ensino, bem como a relação entre eles.

## Tabelas

### `materias`

Armazena informações detalhadas sobre cada matéria.

| Coluna        | Tipo       | Descrição                                         |
| :------------ | :--------- | :------------------------------------------------ |
| `id`          | `int4`     | Chave primária, identificador único da matéria.   |
| `codigo`      | `varchar`  | Código único da matéria.                          |
| `nome`        | `varchar`  | Nome da matéria.                                  |
| `carga_horaria` | `varchar`  | Carga horária da matéria.                         |
| `natureza`    | `varchar`  | Natureza da matéria (ex: obrigatória, optativa).  |
| `ementa`      | `text`     | Ementa ou descrição detalhada do conteúdo da matéria. |
| `created_at`  | `timestamptz` | Carimbo de data/hora de criação do registro.     |
| `updated_at`  | `timestamptz` | Carimbo de data/hora da última atualização do registro. |

### `niveis`

Contém os diferentes níveis de ensino ou organização dentro de um curso.

| Coluna        | Tipo       | Descrição                                         |
| :------------ | :--------- | :------------------------------------------------ |
| `id`          | `int4`     | Chave primária, identificador único do nível.     |
| `curso_id`    | `int4`     | Chave estrangeira referenciando `cursos.id`, indicando a qual curso o nível pertence. |
| `nome`        | `varchar`  | Nome do nível (ex: Semestre 1, Módulo 2).         |
| `ordem`       | `int4`     | Ordem ou sequência do nível dentro do curso.      |
| `created_at`  | `timestamptz` | Carimbo de data/hora de criação do registro.     |
| `updated_at`  | `timestamptz` | Carimbo de data/hora da última atualização do registro. |

### `cursos`

Armazena informações sobre os cursos oferecidos.

| Coluna        | Tipo       | Descrição                                         |
| :------------ | :--------- | :------------------------------------------------ |
| `id`          | `int4`     | Chave primária, identificador único do curso.     |
| `nome`        | `varchar`  | Nome do curso.                                    |
| `created_at`  | `timestamptz` | Carimbo de data/hora de criação do registro.     |
| `updated_at`  | `timestamptz` | Carimbo de data/hora da última atualização do registro. |

### `materias_niveis`

Tabela de junção que relaciona matérias a níveis, permitindo que uma matéria pertença a múltiplos níveis e um nível contenha múltiplas matérias.

| Coluna        | Tipo       | Descrição                                         |
| :------------ | :--------- | :------------------------------------------------ |
| `id`          | `int4`     | Chave primária, identificador único da relação.   |
| `materia_id`  | `int4`     | Chave estrangeira referenciando `materias.id`.    |
| `nivel_id`    | `int4`     | Chave estrangeira referenciando `niveis.id`.      |
| `created_at`  | `timestamptz` | Carimbo de data/hora de criação do registro.     |

## Relacionamentos

* **`niveis`** se relaciona com **`cursos`** através de `curso_id`. Um curso pode ter muitos níveis.
* **`materias_niveis`** é uma tabela de junção entre **`materias`** e **`niveis`**.
    * Uma matéria pode estar associada a muitos níveis.
    * Um nível pode conter muitas matérias.