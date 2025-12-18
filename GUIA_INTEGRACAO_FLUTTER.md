# 🔗 GUIA DE INTEGRAÇÃO - PDF Parser no Flutter

## 📦 Dependências Necessárias

### 1. Adicione ao `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # PDF parsing (necessário)
  syncfusion_flutter_pdf: ^24.2.3
  
  # File picker (para upload de PDF)
  file_picker: ^6.1.1
  
  # HTTP (para enviar dados ao backend - opcional)
  http: ^1.1.2
```

### 2. Instale as dependências:

```bash
flutter pub get
```

---

## 📂 Estrutura de Arquivos

```
lib/
├── utils/
│   └── pdf_parser.dart          # Parser de PDF (já criado)
│
├── screens/
│   └── pdf_upload_screen.dart   # Tela de exemplo (já criada)
│
└── main.dart                     # Adicionar rota
```

---

## 🚀 Integração Rápida

### **Opção 1: Uso Direto (Simples)**

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../utils/pdf_parser.dart';

Future<void> processarPdf() async {
  // 1. Seleciona PDF
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: true,
  );

  if (result == null) return;

  // 2. Obtém bytes
  final pdfBytes = result.files.first.bytes!;

  // 3. Faz parsing
  final resultado = await PdfHistoricoParser.parsePdf(pdfBytes);

  // 4. Usa dados
  print('Disciplinas: ${resultado.disciplinas.length}');
  print('IRA: ${resultado.ira}');
  print('Curso: ${resultado.curso}');
}
```

### **Opção 2: Widget Completo (Recomendado)**

Use a tela de exemplo criada:

```dart
import 'screens/pdf_upload_screen.dart';

// No seu MaterialApp:
MaterialApp(
  routes: {
    '/upload': (context) => const PdfUploadScreen(),
  },
);

// Para navegar:
Navigator.pushNamed(context, '/upload');
```

---

## 🔄 Fluxo de Dados Completo

```
┌─────────────┐
│   Usuário   │
└──────┬──────┘
       │ 1. Seleciona PDF
       ▼
┌─────────────────────┐
│  FilePicker.platform│
│   .pickFiles()      │
└──────┬──────────────┘
       │ 2. Retorna Uint8List
       ▼
┌──────────────────────────┐
│ PdfHistoricoParser       │
│  .parsePdf(bytes)        │
│                          │
│ - Carrega com syncfusion │
│ - Extrai texto           │
│ - Aplica regex           │
│ - Retorna PdfParseResult │
└──────┬───────────────────┘
       │ 3. Resultado estruturado
       ▼
┌─────────────────────────┐
│  PdfParseResult         │
│  {                      │
│    curso: String        │
│    ira: double          │
│    disciplinas: []      │
│    equivalencias: []    │
│  }                      │
└──────┬──────────────────┘
       │ 4. Envia para backend
       ▼
┌─────────────────────────┐
│  HTTP POST              │
│  /api/upload-historico  │
└─────────────────────────┘
```

---

## 📡 Integração com Backend

### **Exemplo: Enviar dados para API REST**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> enviarParaBackend(PdfParseResult resultado) async {
  final url = Uri.parse('https://api.nofluxo.com/historico/upload');
  
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Se necessário
    },
    body: jsonEncode(resultado.toJson()),
  );

  if (response.statusCode == 200) {
    print('Dados enviados com sucesso!');
  } else {
    throw Exception('Erro ao enviar: ${response.body}');
  }
}
```

### **JSON de Saída (Exemplo):**

```json
{
  "curso": "CIÊNCIA DA COMPUTAÇÃO",
  "matriz_curricular": "1856.3",
  "ira": 4.1171,
  "media_ponderada": 4.0157,
  "semestre_atual": "2025.1",
  "numero_semestre": 5,
  "disciplinas": [
    {
      "ano_periodo": "2023.2",
      "nome": "ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES",
      "codigo": "CIC0004",
      "status": "APR",
      "mencao": "SS",
      "turma": "09",
      "carga_horaria": 90,
      "frequencia": 93.0,
      "professor": "Dr. FABRICIO ATAIDES BRAZ",
      "tipo_dado": "Disciplina Regular"
    }
  ],
  "equivalencias": [],
  "suspensoes": []
}
```

---

## 🎨 Exemplo de UI Completa

### **1. Botão de Upload:**

```dart
ElevatedButton.icon(
  onPressed: () async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    
    if (result != null) {
      final bytes = result.files.first.bytes!;
      final parsed = await PdfHistoricoParser.parsePdf(bytes);
      
      // Navegar para tela de visualização
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultadoScreen(resultado: parsed),
        ),
      );
    }
  },
  icon: Icon(Icons.upload_file),
  label: Text('Upload PDF'),
);
```

### **2. Card de Disciplina:**

```dart
Card(
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor: _getMencaoColor(disciplina.mencao),
      child: Text(disciplina.mencao ?? '-'),
    ),
    title: Text(disciplina.nome),
    subtitle: Text('${disciplina.codigo} • ${disciplina.status}'),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${disciplina.cargaHoraria}h'),
        Text('Freq: ${disciplina.frequencia}%'),
      ],
    ),
  ),
);
```

### **3. Indicador de Progresso:**

```dart
if (isLoading)
  Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Processando PDF...'),
        Text('Isso pode levar alguns segundos', style: TextStyle(color: Colors.grey)),
      ],
    ),
  )
```

---

## ⚙️ Configurações Importantes

### **1. Permissões (Android)**

No arquivo `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
  <uses-permission android:name="android.permission.INTERNET"/>
</manifest>
```

### **2. Licença Syncfusion (Opcional)**

Se quiser usar features premium do Syncfusion, adicione a licença no `main.dart`:

```dart
import 'package:syncfusion_flutter_core/core.dart';

void main() {
  SyncfusionLicense.registerLicense('SUA_LICENCA_AQUI');
  runApp(MyApp());
}
```

**Nota:** A versão Community do Syncfusion é **GRATUITA** para empresas com menos de $1M de receita anual.

---

## 🧪 Testes

### **Teste Manual:**

1. Execute o app: `flutter run`
2. Navegue para `/upload` ou chame `PdfUploadScreen()`
3. Selecione um PDF do histórico
4. Verifique o console para logs de debug
5. Confirme que disciplinas foram extraídas

### **Exemplo de Log Esperado:**

```
[DEBUG] Processando 856 linhas para extrair disciplinas...
  ✓ CIC0004 - ALGORITMOS E PROGRAMAÇÃO DE COMPUTAD... (APR/SS)
  ✓ FGA0161 - ENGENHARIA E AMBIENTE (REP/MI)
  [IGNORADO] FGA0163 - INTRODUÇÃO À ENGENHARIA... (Menção: MI)
  ✓ MAT0025 - CÁLCULO 1 (APR/MS)
[RESULTADO] 12 disciplinas extraídas, 3 ignoradas
```

---

## 🐛 Troubleshooting

### **Problema 1: "PdfDocument not found"**

**Solução:** Verifique que `syncfusion_flutter_pdf` está no `pubspec.yaml`:

```bash
flutter pub get
```

### **Problema 2: "Cannot read file bytes"**

**Solução:** Use `withData: true` no FilePicker:

```dart
FilePickerResult? result = await FilePicker.platform.pickFiles(
  withData: true, // IMPORTANTE!
);
```

### **Problema 3: "0 disciplinas extraídas"**

**Possíveis causas:**
1. PDF em formato antigo (antes de 2020)
2. PDF de outro sistema (não é SIGAA UnB)
3. PDF corrompido ou com OCR ruim

**Debug:**
```dart
final resultado = await PdfHistoricoParser.parsePdf(pdfBytes);
print('Texto extraído (primeiros 500 chars):');
print(resultado.fullText.substring(0, 500));
```

### **Problema 4: "Memory issues with large PDFs"**

**Solução:** Limite número de páginas processadas ou use isolates:

```dart
import 'dart:isolate';

Future<PdfParseResult> parsePdfIsolate(Uint8List bytes) async {
  return await Isolate.run(() => PdfHistoricoParser.parsePdf(bytes));
}
```

---

## 📊 Comparação: JavaScript vs Dart

| Aspecto | JavaScript (Web) | Dart (Flutter) |
|---------|------------------|----------------|
| **Performance** | Rápido no browser | Mais rápido (nativo) |
| **Compatibilidade** | Web only | iOS, Android, Web, Desktop |
| **Biblioteca PDF** | PDF.js (Mozilla) | Syncfusion PDF |
| **Extração de texto** | getTextContent() | PdfTextExtractor |
| **Upload** | input file HTML | file_picker package |
| **UI** | HTML/CSS | Flutter widgets |

**Recomendação:** Use a versão **Dart** para app Flutter (mobile/desktop) e a versão **JavaScript** apenas se tiver uma versão web standalone.

---

## ✅ Checklist de Integração

- [ ] `syncfusion_flutter_pdf` adicionado ao `pubspec.yaml`
- [ ] `file_picker` adicionado ao `pubspec.yaml`
- [ ] Arquivo `pdf_parser.dart` no projeto
- [ ] Tela de upload criada (`pdf_upload_screen.dart`)
- [ ] Rota adicionada ao `MaterialApp`
- [ ] Testado com PDF real do SIGAA
- [ ] Logs verificados (disciplinas extraídas)
- [ ] Integração com backend implementada
- [ ] UI de feedback para usuário (loading, erro, sucesso)

---

## 🚀 Próximos Passos

1. **Cache de PDFs processados** - Evitar reprocessar o mesmo arquivo
2. **Suporte offline** - Salvar dados localmente com `sqflite`
3. **Notificações** - Avisar quando processamento terminar
4. **Análise de progresso** - Gráficos de desempenho acadêmico
5. **Comparação de históricos** - Detectar mudanças entre uploads

---

## 📞 Suporte

**Problemas com a integração?**

1. Verifique os logs do Flutter: `flutter logs`
2. Teste com o PDF de exemplo fornecido
3. Compare o output com o esperado
4. Abra uma issue no repositório

**Parser funcionando?** ✅ Pronto para produção! 🎉
