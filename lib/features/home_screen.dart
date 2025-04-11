import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_text/pdf_text.dart';
import 'package:path_provider/path_provider.dart';

class PdfSearchScreen extends StatefulWidget {
  const PdfSearchScreen({super.key});

  @override
  State<PdfSearchScreen> createState() => _PdfSearchScreenState();
}

class _PdfSearchScreenState extends State<PdfSearchScreen> {
  PDFDoc? _pdfDoc;
  List<Question> _questions = [];
  List<Question> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load PDF asset into memory
      final bytes = await rootBundle.load('assets/pdf/MGT.pdf');

      // Write to a temp file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/MGT.pdf');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      // Load PDF using pdf_text
      _pdfDoc = await PDFDoc.fromFile(file);

      final pdfText = await _pdfDoc!.text;
      _extractQuestions(pdfText);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load PDF: ${e.toString()}';
      });
      debugPrint('PDF load error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _extractQuestions(String pdfText) {
    final questions = <Question>[];
    final lines = pdfText.split('\n');

    Question? currentQuestion;

    for (final line in lines) {
      final trimmedLine = line.trim();

      // Match question lines like: | 1 | Question text |
      final questionMatch = RegExp(r'^\|\s*(\d+)\s*\|\s*(.+?)\s*\|\s*$').firstMatch(trimmedLine);
      if (questionMatch != null) {
        if (currentQuestion != null) questions.add(currentQuestion);
        currentQuestion = Question(
          number: int.parse(questionMatch.group(1)!),
          text: questionMatch.group(2)!,
          options: {},
          answer: '',
          marks: 0,
        );
        continue;
      }

      // Match option lines like: | A. | Option text |
      final optionMatch = RegExp(r'^\|\s*([A-D])\.?\s*\|\s*(.+?)\s*\|\s*$').firstMatch(trimmedLine);
      if (optionMatch != null && currentQuestion != null) {
        currentQuestion.options[optionMatch.group(1)!] = optionMatch.group(2)!;
        continue;
      }

      // Match answer lines like: | Answer | optionb |
      final answerMatch = RegExp(r'^\|\s*Answer\s*\|\s*option([a-d])\s*\|\s*$').firstMatch(trimmedLine);
      if (answerMatch != null && currentQuestion != null) {
        currentQuestion.answer = answerMatch.group(1)!.toUpperCase();
        continue;
      }

      // Match marks lines like: | Marks: | 1 |
      final marksMatch = RegExp(r'^\|\s*Marks:\s*\|\s*(\d+)\s*\|\s*$').firstMatch(trimmedLine);
      if (marksMatch != null && currentQuestion != null) {
        currentQuestion.marks = int.parse(marksMatch.group(1)!);
      }
    }

    if (currentQuestion != null) questions.add(currentQuestion);

    setState(() => _questions = questions);
  }

  void _searchQuestions(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _searchResults = _questions.where((q) =>
        q.text.toLowerCase().contains(lowerQuery) ||
        q.options.values.any((opt) => opt.toLowerCase().contains(lowerQuery))
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Question Search'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search questions',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchQuestions(_searchController.text),
                ),
              ),
              onChanged: _searchQuestions,
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_isLoading && _questions.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_isLoading && _questions.isEmpty && _errorMessage == null)
            const Expanded(child: Center(child: Text('No questions found'))),
          if (_questions.isNotEmpty)
            Expanded(
              child: _searchResults.isNotEmpty
                  ? ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final q = _searchResults[index];
                        return Card(
                          margin: const EdgeInsets.all(8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${q.number}. ${q.text}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...q.options.entries.map((e) => Text(
                                  '${e.key}. ${e.value}',
                                  style: TextStyle(
                                    color: e.key == q.answer ? Colors.green : null,
                                    fontWeight: e.key == q.answer ? FontWeight.bold : null,
                                  ),
                                )),
                                const SizedBox(height: 8),
                                Text(
                                  'Marks: ${q.marks}',
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Search for questions'
                            : 'No results for "${_searchController.text}"',
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class Question {
  final int number;
  final String text;
  final Map<String, String> options;
  String answer;
  int marks;

  Question({
    required this.number,
    required this.text,
    required this.options,
    required this.answer,
    required this.marks,
  });
}
