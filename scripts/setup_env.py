#!/usr/bin/env python3
"""
setup_env.py - Script de inicialização e padronização do ambiente NoFluxoUnB.
Configura ambiente virtual Python (venv), atualiza pip e instala dependências
de forma consistente em qualquer sistema operacional (Windows, Linux, macOS).

Uso:
  python scripts/setup_env.py            # Instalação completa recomendada (venv + dependências)
  python scripts/setup_env.py --dba      # Apenas dependências do DBA/database
  python scripts/setup_env.py --agent    # Apenas dependências do MCP Agent
  python scripts/setup_env.py --node     # Instala também dependências Node.js (frontend/backend)
  python scripts/setup_env.py --help     # Exibe ajuda
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

# Raiz do repositório
REPO_ROOT = Path(__file__).resolve().parent.parent
IS_WINDOWS = platform.system() == "Windows"

# Caminhos para arquivos de requirements
REQ_ROOT = REPO_ROOT / "requirements.txt"
REQ_DBA = REPO_ROOT / "DBA" / "database" / "requirements.txt"
REQ_SCRAPING = REPO_ROOT / "DBA" / "scraping" / "requirements.txt"
REQ_AGENT = REPO_ROOT / "mcp_agent" / "requirements.txt"
REQ_PDF = REPO_ROOT / "no_fluxo_backend" / "parse-pdf" / "requirements.txt"

def log(msg: str, emoji: str = "ℹ️") -> None:
    print(f"{emoji} {msg}")

def log_success(msg: str) -> None:
    print(f"✅ {msg}")

def log_warn(msg: str) -> None:
    print(f"⚠️ {msg}")

def log_error(msg: str) -> None:
    print(f"❌ {msg}")

def run_cmd(cmd: list[str], cwd: Path | None = None, check: bool = True) -> int:
    cmd_str = " ".join(str(x) for x in cmd)
    print(f"   > {cmd_str}")
    result = subprocess.run(cmd, cwd=str(cwd) if cwd else str(REPO_ROOT))
    if check and result.returncode != 0:
        raise RuntimeError(f"Comando falhou com código {result.returncode}: {cmd_str}")
    return result.returncode

def get_venv_dir() -> Path:
    # Prioriza 'venv' se já existir, senão '.venv' ou cria 'venv'
    if (REPO_ROOT / "venv").exists():
        return REPO_ROOT / "venv"
    if (REPO_ROOT / ".venv").exists():
        return REPO_ROOT / ".venv"
    return REPO_ROOT / "venv"

def get_venv_executables(venv_dir: Path) -> tuple[Path, Path]:
    if IS_WINDOWS:
        py_path = venv_dir / "Scripts" / "python.exe"
        pip_path = venv_dir / "Scripts" / "pip.exe"
    else:
        py_path = venv_dir / "bin" / "python"
        pip_path = venv_dir / "bin" / "pip"
    return py_path, pip_path

def ensure_virtualenv() -> tuple[Path, Path]:
    venv_dir = get_venv_dir()
    py_exec, pip_exec = get_venv_executables(venv_dir)

    if not py_exec.exists():
        log(f"Criando ambiente virtual em: {venv_dir} ...", "📦")
        run_cmd([sys.executable, "-m", "venv", str(venv_dir)])
        log_success("Ambiente virtual criado!")
    else:
        log_success(f"Ambiente virtual detectado em: {venv_dir}")

    log("Atualizando pip...", "🔄")
    run_cmd([str(py_exec), "-m", "pip", "install", "--upgrade", "pip"])
    return py_exec, pip_exec

def print_activation_instructions(venv_dir: Path) -> None:
    print("\n" + "=" * 65)
    print("🚀 AMBIENTE CONFIGURADO COM SUCESSO!")
    print("=" * 65)
    print("Para ativar o ambiente virtual no seu terminal antes de rodar os scripts:")
    if IS_WINDOWS:
        print("\n  No PowerShell:")
        print(f"    .\\{venv_dir.name}\\Scripts\\Activate.ps1")
        print("\n  No Prompt de Comando (CMD):")
        print(f"    .\\{venv_dir.name}\\Scripts\\activate.bat")
    else:
        print("\n  No Bash / Zsh:")
        print(f"    source {venv_dir.name}/bin/activate")

    print("\nPara executar qualquer script usando o ambiente sem precisar ativar:")
    if IS_WINDOWS:
        print(f"    .\\{venv_dir.name}\\Scripts\\python.exe <caminho_do_script.py>")
    else:
        print(f"    ./{venv_dir.name}/bin/python <caminho_do_script.py>")
    print("=" * 65 + "\n")

def install_node_deps() -> None:
    log("Verificando dependências Node.js...", "🌐")
    has_pnpm = shutil.which("pnpm") is not None
    pm = "pnpm" if has_pnpm else "npm"

    # Backend
    backend_dir = REPO_ROOT / "no_fluxo_backend"
    if backend_dir.exists():
        log(f"Instalando dependências do backend com {pm}...", "📦")
        run_cmd([pm, "install"], cwd=backend_dir)
        log_success("Backend Node.js configurado!")

    # Frontend
    frontend_dir = REPO_ROOT / "no_fluxo_frontend_svelte"
    if frontend_dir.exists():
        log(f"Instalando dependências do frontend com {pm}...", "🎨")
        run_cmd([pm, "install"], cwd=frontend_dir)
        log_success("Frontend SvelteKit configurado!")

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Configura o ambiente de desenvolvimento e padroniza dependências do NoFluxo."
    )
    parser.add_argument("--dba", action="store_true", help="Instala apenas dependências do DBA/database")
    parser.add_argument("--scraping", action="store_true", help="Instala apenas dependências do DBA/scraping")
    parser.add_argument("--agent", action="store_true", help="Instala apenas dependências do MCP Agent")
    parser.add_argument("--node", action="store_true", help="Instala também dependências de Frontend e Backend Node")
    parser.add_argument("--all", action="store_true", help="Instala todas as dependências Python (padrão)")

    args = parser.parse_args()

    # Informações de sistema e versão do Python
    py_ver = sys.version_info
    log(f"Python detectado: {py_ver.major}.{py_ver.minor}.{py_ver.micro} ({platform.system()} {platform.machine()})", "🐍")

    if py_ver < (3, 10):
        log_warn("Recomenda-se Python 3.10 ou superior para compatibilidade completa com as bibliotecas do projeto.")

    # 1. Configurar venv
    venv_dir = get_venv_dir()
    py_exec, _ = ensure_virtualenv()

    # 2. Instalar dependências Python
    targets: list[tuple[str, Path]] = []

    specific_target = args.dba or args.scraping or args.agent
    if args.dba and REQ_DBA.exists():
        targets.append(("DBA / Database", REQ_DBA))
    if args.scraping and REQ_SCRAPING.exists():
        targets.append(("DBA / Scraping", REQ_SCRAPING))
    if args.agent and REQ_AGENT.exists():
        targets.append(("MCP Agent", REQ_AGENT))

    if not specific_target or args.all:
        if REQ_ROOT.exists():
            targets.append(("Requisitos Consolidados do Projeto", REQ_ROOT))

    for name, req_file in targets:
        log(f"Instalando dependências de [{name}] ({req_file.name})...", "📥")
        run_cmd([str(py_exec), "-m", "pip", "install", "-r", str(req_file)])
        log_success(f"[{name}] instalado com sucesso!")

    # 3. Node se requisitado
    if args.node:
        install_node_deps()

    # 4. Instruções finais
    print_activation_instructions(venv_dir)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log_error(f"Erro na configuração: {e}")
        sys.exit(1)
