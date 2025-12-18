import 'package:flutter/material.dart';
import 'screens/test_pdf_parser_screen.dart';

/// Ponto de entrada para testar o parser de PDF com interface
void main() {
  runApp(const TestPdfParserApp());
}

class TestPdfParserApp extends StatelessWidget {
  const TestPdfParserApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teste: Parser PDF - NoFluxoUNB',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const TestPdfParserScreen(),
    );
  }
}
