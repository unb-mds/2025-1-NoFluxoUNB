# 🧪 Como Testar o Parser de PDF com Interface

## 🚀 Opção 1: Aplicativo Flutter Desktop (Windows)

### Executar:

```powershell
cd no_fluxo_frontend
flutter run -d windows --target=lib/main_test_pdf_ui.dart
```

### Como usar:
1. Clique em **"Escolher PDF"**
2. Selecione um arquivo PDF de histórico escolar (formato SIGAA - UnB)
3. Aguarde o processamento (alguns segundos)
4. Veja os dados extraídos:
   - **Curso e IRA** no topo
   - **Abas**: Aprovadas, Cursando, Reprovadas, Pendentes
   - **Expandir disciplinas** para ver detalhes (professor, frequência, etc.)
   - **Equivalências** no final

### Recursos:
- ✅ Upload de PDF via seletor de arquivos
- ✅ Cards de resumo (Curso, IRA, Total, Equivalências)
- ✅ Tabs organizadas por status
- ✅ Expansão de disciplinas com detalhes completos
- ✅ Cores diferentes por categoria
- ✅ Botão "Novo PDF" para testar outro arquivo

---

## 🌐 Opção 2: Página Web HTML (Mais Rápido)

Se preferir testar no navegador (sem precisar compilar Flutter):

### Executar:

```powershell
cd no_fluxo_frontend
# Abra o arquivo no navegador:
start lib/utils/test_parser.html
```

### Como usar:
1. Clique em **"Escolher arquivo"**
2. Selecione um PDF
3. Veja o console do navegador (F12) com logs detalhados
4. Dados extraídos aparecem na página

---

## 📱 Opção 3: Aplicativo Flutter Mobile (Android/iOS)

Para testar no celular:

```powershell
# Android
flutter run -d <device-id> --target=lib/main_test_pdf_ui.dart

# iOS (precisa de macOS)
flutter run -d <device-id> --target=lib/main_test_pdf_ui.dart
```

Lista devices disponíveis:
```powershell
flutter devices
```

---

## 🧪 Testes Automatizados

Para rodar os testes unitários:

```powershell
flutter test test/pdf_parser_test.dart
```

**Resultado esperado:**
- ✅ 2 testes passando
- ✅ Extração de ~31 disciplinas cursadas
- ✅ Extração de ~25 disciplinas pendentes
- ✅ Extração de IRA, curso, equivalências

---

## 📄 PDFs de Teste

Coloque seus PDFs de histórico em:
```
test/fixtures/historico_teste.pdf
```

Formatos suportados:
- ✅ SIGAA - UnB (formato padrão)
- ✅ Históricos com disciplinas aprovadas (APR)
- ✅ Históricos com disciplinas cursando (MATR)
- ✅ Históricos com equivalências
- ✅ Históricos com suspensões

---

## 🐛 Solução de Problemas

### Erro: "Could not find package file_picker"
```powershell
flutter pub get
```

### Erro: "No device found"
```powershell
# Para Windows desktop:
flutter config --enable-windows-desktop
flutter create .

# Para Web:
flutter config --enable-web
flutter create .
```

### App não abre
Verifique se a porta não está ocupada:
```powershell
Get-Process | Where-Object {$_.ProcessName -like "*flutter*"} | Stop-Process -Force
flutter run -d windows --target=lib/main_test_pdf_ui.dart
```

---

## 📊 Exemplo de Saída

```
Curso: CIÊNCIA DA COMPUTAÇÃO
IRA: 4.1171

Disciplinas: 56
├─ Aprovadas: 18
├─ Cursando: 7
├─ Reprovadas: 0
└─ Pendentes: 25

Equivalências: 4

Primeira disciplina:
  CIC0004 - ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES
  Status: APR | Menção: SS
  Ano/Período: 2023.2
  Professor: Dr. FABRICIO ATAIDES BRAZ
  Carga Horária: 90h
  Frequência: 93.0%
```

---

## 🔄 Próximos Passos

1. **Integrar ao app principal**: Substituir backend Python pelo parser Dart
2. **Adicionar cache**: Salvar resultado do parsing em `SharedPreferences`
3. **Melhorar UI**: Adicionar gráficos de progresso (% concluído do curso)
4. **Exportar JSON**: Botão para salvar dados extraídos
5. **Comparar PDFs**: Upload de 2 históricos para ver evolução

---

## 📚 Documentação Completa

- [GUIA_INTEGRACAO_FLUTTER.md](../GUIA_INTEGRACAO_FLUTTER.md) - Como integrar ao app
- [COMO_TESTAR_PDF_PARSER.md](../COMO_TESTAR_PDF_PARSER.md) - Todas as opções de teste
- [RESUMO_FINAL_MIGRACAO.md](../RESUMO_FINAL_MIGRACAO.md) - Resultado da migração
