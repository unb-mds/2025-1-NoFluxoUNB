# 🧪 GUIA DE TESTES - PDF Parser

## 🚀 3 Formas de Testar

### **Opção 1: Teste Manual no App (MAIS FÁCIL)** ⭐

1. **Instale dependências:**
```bash
cd no_fluxo_frontend
flutter pub get
```

2. **Execute o app de teste:**
```bash
flutter run -t lib/main_test_pdf.dart
```

3. **Teste no navegador/emulador:**
   - App abrirá com tela de upload
   - Clique em "Selecionar PDF"
   - Escolha seu histórico: `historico_232014010 (8).pdf`
   - Veja os resultados na tela!

---

### **Opção 2: Teste Automatizado (Widget Test)**

1. **Coloque PDF de teste:**
```bash
# Copie seu PDF para:
no_fluxo_frontend/test/fixtures/historico_teste.pdf
```

2. **Execute testes:**
```bash
cd no_fluxo_frontend
flutter test test/pdf_parser_test.dart
```

3. **Veja output no console:**
```
📊 Resultados do Teste:
   Curso: CIÊNCIA DA COMPUTAÇÃO
   IRA: 4.1171
   Disciplinas: 12
   Equivalências: 0

📚 Primeira disciplina:
   CIC0004 - ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES
   Status: APR | Menção: SS

✅ All tests passed!
```

---

### **Opção 3: Teste Quick & Dirty (Debug Console)**

Adicione no seu `main.dart` existente:

```dart
import 'dart:io';
import 'utils/pdf_parser.dart';

void main() async {
  // Testa parser
  final file = File('caminho/para/seu/historico.pdf');
  final bytes = await file.readAsBytes();
  
  final resultado = await PdfHistoricoParser.parsePdf(bytes);
  
  print('Curso: ${resultado.curso}');
  print('IRA: ${resultado.ira}');
  print('Disciplinas: ${resultado.disciplinas.length}');
  
  resultado.disciplinas.forEach((d) {
    print('${d.codigo} - ${d.nome} (${d.status})');
  });
  
  // Depois roda seu app normal
  runApp(MyApp());
}
```

---

## 📋 Checklist de Teste

Execute na ordem:

### **1. Preparação:**
- [ ] `flutter pub get` executado
- [ ] PDF de teste disponível
- [ ] Sem erros de compilação

### **2. Teste Básico:**
```bash
flutter run -t lib/main_test_pdf.dart
```
- [ ] App abre sem erros
- [ ] Botão de upload aparece
- [ ] File picker abre ao clicar

### **3. Teste de Extração:**
- [ ] Seleciona PDF do histórico
- [ ] Loading aparece durante processamento
- [ ] Disciplinas são exibidas na tela
- [ ] IRA/MP estão corretos
- [ ] Sem erros no console

### **4. Validação de Dados:**
- [ ] Número de disciplinas está correto (compare com PDF)
- [ ] Códigos das disciplinas estão corretos
- [ ] Status (APR, REP) estão corretos
- [ ] Menções (SS, MS, MM) estão corretas

### **5. Casos Especiais:**
- [ ] Disciplinas com # (optativas) são processadas
- [ ] Disciplinas com menção MI/II são ignoradas
- [ ] Linhas de ENADE são puladas
- [ ] Equivalências aparecem (se houver)

---

## 🐛 Troubleshooting

### **Erro: "syncfusion_flutter_pdf not found"**
```bash
flutter pub get
flutter clean
flutter pub get
```

### **Erro: "Cannot read file bytes"**
No `file_picker`, use:
```dart
withData: true  // Importante!
```

### **Nenhuma disciplina extraída:**
1. Verifique o console para logs
2. Use ferramenta de debug: `pdf_debug_text_extraction.html`
3. Veja o texto extraído:
```dart
print('Texto completo (500 chars):');
print(resultado.fullText.substring(0, 500));
```

### **App não compila:**
Verifique versão do Flutter:
```bash
flutter --version  # Deve ser >= 3.3.0
flutter doctor     # Verifica problemas
```

---

## 📊 Output Esperado

### **Console (flutter run):**
```
[DEBUG] Processando 856 linhas para extrair disciplinas...
  ✓ CIC0004 - ALGORITMOS E PROGRAMAÇÃO DE COMPUTAD... (APR/SS)
  ✓ MAT0025 - CÁLCULO 1 (APR/MS)
  [IGNORADO] FGA0161 - ENGENHARIA E AMBIENTE (Menção: MI)
  ✓ EST0023 - PROBABILIDADE E ESTATÍSTICA (APR/MS)
[RESULTADO] 12 disciplinas extraídas, 3 ignoradas
```

### **Tela do App:**
```
📊 Dados Acadêmicos
├─ Curso: CIÊNCIA DA COMPUTAÇÃO
├─ Matriz: 1856/3 - 2025.1
├─ IRA: 4.1171
└─ MP: 4.0157

📚 Disciplinas (12)
├─ CIC0004 - ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES
│  90h | Turma 09 | APR | SS
├─ MAT0025 - CÁLCULO 1
│  90h | Turma 24 | APR | MS
└─ ...
```

---

## 🎯 Comandos Rápidos

### **Teste Manual:**
```bash
cd no_fluxo_frontend
flutter pub get
flutter run -t lib/main_test_pdf.dart
```

### **Teste Automatizado:**
```bash
cd no_fluxo_frontend
flutter test test/pdf_parser_test.dart -r expanded
```

### **Teste Web:**
```bash
flutter run -d chrome -t lib/main_test_pdf.dart
```

### **Teste Android:**
```bash
flutter run -d android -t lib/main_test_pdf.dart
```

---

## ✅ Sucesso Confirmado Quando:

1. ✅ App roda sem crashes
2. ✅ PDF é carregado e processado
3. ✅ Disciplinas aparecem na tela (quantidade correta)
4. ✅ IRA/MP batem com o PDF
5. ✅ Console mostra logs de debug
6. ✅ Sem erros vermelhos no terminal

**Se todos os checks passarem:** 🎉 **Parser funcionando perfeitamente!**

---

## 📞 Precisa de Ajuda?

1. **Verifique logs:** `flutter logs` em outro terminal
2. **Debug console:** Abra DevTools (`flutter pub global run devtools`)
3. **Compare output:** Use ferramenta web `pdf_debug_text_extraction.html`

**Pronto para testar!** Execute o primeiro comando e me mostre o resultado! 🚀
