import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaivart/core/converters/document_converter.dart';

void main() {
  group('DocumentConverter PDF <-> MD Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vaivart_doc_test_');
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('mdToPdf and pdfToMd roundtrip converts text accurately without error fallback', () async {
      final mdFile = File('${tempDir.path}/test_assignment.md');
      await mdFile.writeAsString('''
# Department of Computer Engineering
## Assignment 1

1. Describe Functions of Operating System
2. Explain Multi-Programmed Operating System

| Process | Arrival Time | Burst Time |
| --- | --- | --- |
| P1 | 0 | 8 |
| P2 | 1 | 4 |
''');

      // 1. Convert Markdown to PDF
      final pdfPath = await DocumentConverter.mdToPdf(
        sourcePath: mdFile.path,
        outputDir: tempDir.path,
      );
      final pdfFile = File(pdfPath);
      expect(await pdfFile.exists(), isTrue);
      expect(await pdfFile.length(), greaterThan(100));

      // 2. Convert PDF to Markdown
      final extractedMdPath = await DocumentConverter.pdfToMd(
        sourcePath: pdfPath,
        outputDir: tempDir.path,
      );
      final extractedMdFile = File(extractedMdPath);
      expect(await extractedMdFile.exists(), isTrue);

      final extractedContent = await extractedMdFile.readAsString();

      // Must NOT return the fallback failure string
      expect(
        extractedContent,
        isNot(contains('Could not extract text from this PDF.')),
      );

      // Must contain our original content
      expect(extractedContent, contains('Department of Computer Engineering'));
      expect(extractedContent, contains('Functions of Operating System'));
    });
  });
}
