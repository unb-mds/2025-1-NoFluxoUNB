# DBA/database – Integração com o banco (Supabase)

Centralização dos scripts que inserem/atualizam dados no banco a partir dos dados em `DBA/dados`.

## Convenções

### `curriculo_completo` (tabela `matrizes`)

- **Formato:** apenas `"codigo/versao - periodo"` (ex.: `"8150/-4 - 2014.1"`).
- **Não incluir** o turno no texto (nem `" - DIURNO"` nem `" - NOTURNO"`).
- Se já existir matriz com o mesmo `id_curso`, `versao` e `ano_vigor` mas com `curriculo_completo` no formato antigo (com turno), o script **01** faz **UPDATE** somente dessa coluna para o padrão sem turno.

### `tipo_natureza` (tabela `materias_por_curso`)

- **0** = Obrigatória  
- **1** = Optativa  

Valor definido a partir do campo `natureza` nos JSONs de estrutura curricular (ex.: `"Optativa"` → 1).

### `id_curso` (tabela `cursos`)

- **Valor:** código do currículo da matriz (primeira parte antes da `/`).
- Ex.: currículo `"6360/1"` → `id_curso = 6360`; `"8150/-4"` → `id_curso = 8150`.
- Não se soma nada para turno; cada curso (diurno ou noturno) já tem código próprio no currículo.
- **Normalização:** o script 01 corrige cursos que estavam no padrão antigo (id_curso = codigo_base + 100000): atualiza `matrizes` e `equivalencias` para `id_curso = codigo_base` e ajusta ou remove a linha em `cursos`, na mesma lógica do `curriculo_completo`.

### Inserção e atualização

- **Inserir** apenas quando o registro ainda não existir (evitar duplicatas em cursos, matrizes, matérias, `materias_por_curso`).
- **Única coluna** em que se faz update quando o registro já existe: **`matrizes.curriculo_completo`** (para padronizar sem turno).

---

## Scripts

### 1. `01_insert_cursos_matrizes_materias.py` (Fase 1)

- **Fonte:** `DBA/dados/estruturas-curriculares/*.json`
- **Ações:**  
  - get_or_create **cursos** (por `id_curso` legado ou por `nome_curso` + `turno` + `tipo_curso`).  
  - get_or_create **matrizes** (`curriculo_completo` sem turno; atualiza `curriculo_completo` se existir no formato antigo).  
  - get_or_create **matérias** (por `codigo_materia`; usa detalhes de `DBA/dados/materias` quando existirem).  
  - Inserção em lote de **materias_por_curso** (`id_materia`, `id_matriz`, `nivel`, `tipo_natureza` 0/1).

**Uso:**

```bash
cd DBA/database
python 01_insert_cursos_matrizes_materias.py           # execução normal
python 01_insert_cursos_matrizes_materias.py --dry-run # só simula (nenhuma escrita)
```

Requer `.env` (ou fallback em `config.py`) com `SUPABASE_URL` e `SUPABASE_KEY` (ou `SUPABASE_SERVICE_ROLE_KEY`).

### 2. `02_insert_pre_requisitos_equivalencias.py` (Fase 2)

- **Fonte:** `DBA/dados/materias/turmas_depto_*.json`
- **Ações:**  
  Inserir **pré-requisitos**, **co-requisitos** e **equivalências** (genéricas e específicas por curso/curriculo) **somente se ainda não existirem**. Preenche `expressao_original` e `expressao_logica` (JSONB) usando o parser em `expressao_parser.py` (port de `DBA/dados/expressao_logica/parse-expressao.ts`).
- **Equivalências:** genéricas com `id_curso` e `curriculo` nulos; específicas com `id_curso` = código do currículo, `curriculo` = texto (ex.: `"8150/-4 - 2014.1"`), `data_vigencia` quando houver.

**Uso:**

```bash
python 02_insert_pre_requisitos_equivalencias.py           # execução normal
python 02_insert_pre_requisitos_equivalencias.py --dry-run # só simula
```

### 3. `expressao_parser.py`

- Parser de `expressao_original` → estrutura para `expressao_logica` (JSONB).
- Formato: `string` (código único) ou `{"operador": "OU"|"E", "condicoes": [...]}`.
- Ex.: `"( ( CCA0105 ) OU ( FUP0289 ) OU ( CCA0102 ) )"` → `{"operador": "OU", "condicoes": ["CCA0105", "FUP0289", "CCA0102"]}`.

---

## Configuração

- **`config.py`:** define `PASTA_ESTRUTURAS`, `PASTA_MATERIAS`, `SUPABASE_URL`, `SUPABASE_KEY` (carrega `.env` do backend ou da raiz do repositório).

### Migration: `id_curso` em `cursos`

Para o script 01 poder usar `id_curso` = código do currículo e normalizar registros legados, a coluna **não** deve ser IDENTITY. Se a tabela foi criada com `GENERATED ALWAYS AS IDENTITY`, execute uma vez:

```sql
ALTER TABLE public.cursos ALTER COLUMN id_curso DROP IDENTITY;
```

Arquivo: `DBA/database/migrations/alter_cursos_drop_identity.sql`

---

## Referência do schema (validação)

Estrutura esperada para os scripts desta pasta. **cursos.id_curso** deve ser `bigint NOT NULL` **sem** IDENTITY.

| Tabela | PK | Observação |
|--------|-----|------------|
| **cursos** | id_curso (bigint NOT NULL, **sem IDENTITY**) | id_curso = código do currículo; nome_curso, tipo_curso, turno, campus |
| **matrizes** | id_matriz (IDENTITY) | id_curso FK → cursos; curriculo_completo UNIQUE NOT NULL; versao NOT NULL; ano_vigor; ch_* |
| **materias** | id_materia (IDENTITY) | codigo_materia UNIQUE; nome_materia, carga_horaria, ementa, departamento |
| **materias_por_curso** | id_materia_curso (IDENTITY) | id_materia FK → materias; id_matriz FK → matrizes; nivel; tipo_natureza (0 obrigatória, 1 optativa) |
| **pre_requisitos** | id_pre_requisito (IDENTITY) | id_materia, id_materia_requisito (FK → materias); expressao_original; expressao_logica (jsonb) |
| **co_requisitos** | id_co_requisito (IDENTITY) | id_materia, id_materia_corequisito (FK → materias); expressao_original; expressao_logica (jsonb) |
| **equivalencias** | id_equivalencia (IDENTITY) | id_materia FK; id_curso FK (opcional); curriculo; data_vigencia; expressao_original; expressao_logica (jsonb) |

Ordem de dependência para criação: **cursos**, **materias** → **matrizes** → **materias_por_curso**; **materias** → **pre_requisitos**, **co_requisitos**, **equivalencias**.
