#!/usr/bin/env bash
# Regera as fixtures grandes do exercício de teste exploratório (BVA do upload).
# Os PDFs de 10 MB exato e 10 MB+1 byte são gitignored — rode este script
# antes de executar a suíte Playwright se ainda não existirem localmente.
#
# Uso: bash docs/testes/fixtures/make-fixtures.sh
set -euo pipefail
cd "$(dirname "$0")"

{ printf '%%PDF-1.4\n'; head -c 10485751 /dev/zero | tr '\0' 'A'; } > size_10mb_exact.pdf
{ printf '%%PDF-1.4\n'; head -c 10485752 /dev/zero | tr '\0' 'A'; } > size_10mb_plus1.pdf

ls -la size_10mb_exact.pdf size_10mb_plus1.pdf
echo "ok — 10485760 e 10485761 bytes respectivamente"
