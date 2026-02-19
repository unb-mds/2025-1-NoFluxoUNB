# Serviço Parse PDF

Parser de PDF usado pelo backend NoFluxo (extração de texto e disciplinas).

## Versão do Python

**Use Python 3.10, 3.11 ou 3.12** para este serviço.

O PyMuPDF no Windows não possui wheel pré-compilado para Python 3.14+. Com 3.14, o `pip` tenta compilar do código-fonte e exige **Visual Studio** (Build Tools com C++). Para evitar isso, use um ambiente com Python 3.10–3.12.

### Exemplo com venv (Python 3.12)

Se você tem Python 3.12 instalado (por exemplo em `py -3.12`):

```powershell
cd no_fluxo_backend
py -3.12 -m venv .venv-pdf
.\.venv-pdf\Scripts\Activate.ps1
pip install -r parse-pdf/requirements.txt
```

Depois, para rodar o backend normalmente: use o mesmo Python (3.10–3.12) no ambiente em que você executa `npm run dev`, ou ajuste o script `dev` para usar esse venv.

### Alternativa: instalar Visual Studio Build Tools

Se quiser manter Python 3.14, instale [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) com a carga de trabalho **“Desenvolvimento para desktop com C++”**. A compilação do PyMuPDF pode levar vários minutos.
