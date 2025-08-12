import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() => runApp(const EmoReaderApp());

class EmoReaderApp extends StatelessWidget {
  const EmoReaderApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Emo PDF Reader',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterTts tts = FlutterTts();
  String fullText = "";
  List<String> sentences = [];
  int idx = 0;
  bool speaking = false;
  String? selectedLang;
  List<String> langs = ["en-US"];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      final l = await tts.getLanguages;
      if (l is List) {
        langs = l.map((e) => e.toString()).where((s) => s.contains('-')).cast<String>().toList()..sort();
      }
    } catch (_) {}
    selectedLang = langs.contains("en-US") ? "en-US" : (langs.isNotEmpty ? langs.first : null);
    setState(() {});
  }

  Future<void> _openPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: const ['pdf'], withData: true);
    if (res == null || res.files.single.bytes == null) return;
    final Uint8List bytes = res.files.single.bytes!;
    fullText = await _parsePdfBytesToCleanText(bytes);
    sentences = _splitIntoSentences(fullText);
    idx = 0;
    setState(() {});
  }

  Future<void> _applyEmotion(String s) async {
    double rate = 0.9, pitch = 1.0;
    final lower = s.toLowerCase();
    if (s.trim().endsWith("!")) { rate = 1.05; pitch = 1.1; }
    else if (s.trim().endsWith("?")) { rate = 1.0; pitch = 1.08; }
    final sad = ["grief","sad","tears","lonely","loss","death","dark","silence"];
    final joy = ["joy","happy","smile","light","bright","laughter","freedom","love"];
    final fear = ["fear","tremble","shiver","whispered","panic","nightmare"];
    final anger = ["anger","furious","rage","shout","slam","stormed"];
    if (sad.any(lower.contains)) { rate = 0.82; pitch = 0.9; }
    else if (joy.any(lower.contains)) { rate = 1.03; pitch = 1.1; }
    else if (fear.any(lower.contains)) { rate = 0.95; pitch = 1.05; }
    else if (anger.any(lower.contains)) { rate = 1.02; pitch = 0.92; }
    await tts.setSpeechRate(rate);
    await tts.setPitch(pitch);
  }

  Future<void> _speak() async {
    if (sentences.isEmpty) return;
    speaking = true; setState(() {});
    await tts.setVolume(1.0);
    if (selectedLang != null) { try { await tts.setLanguage(selectedLang!); } catch (_) {} }
    await tts.setSpeechRate(0.9); await tts.setPitch(1.0);
    try { await tts.awaitSpeakCompletion(true); } catch (_) {}
    while (speaking && idx < sentences.length) {
      final s = sentences[idx];
      await _applyEmotion(s);
      await tts.speak(s);
      idx++; setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));
    }
    speaking = false; setState(() {});
  }

  Future<void> _pause() async { await tts.pause(); speaking = false; setState(() {}); }
  Future<void> _stop() async  { await tts.stop();  speaking = false; setState(() {}); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emo PDF Reader'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedLang,
              items: langs.take(50).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => selectedLang = v),
              icon: const Icon(Icons.language),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton.icon(onPressed: _openPdf, icon: const Icon(Icons.file_open), label: const Text('Open PDF')),
            const SizedBox(width: 12),
            ElevatedButton.icon(onPressed: speaking ? null : _speak, icon: const Icon(Icons.play_arrow), label: const Text('Speak')),
            const SizedBox	width: 12),
            ElevatedButton.icon(onPressed: speaking ? _pause : null, icon: const Icon(Icons.pause), label: const Text('Pause')),
            const SizedBox(width: 12),
            ElevatedButton.icon(onPressed: _stop, icon: const Icon(Icons.stop), label: const Text('Stop')),
          ]),
          const Divider(),
          Expanded(
            child: sentences.isEmpty
              ? const Center(child: Text("Open a PDF to begin."))
              : ListView.builder(
                  itemCount: sentences.length,
                  itemBuilder: (c, i) {
                    final isCur = i == idx;
                    return ListTile(
                      dense: true,
                      selected: isCur,
                      title: Text(sentences[i], style: TextStyle(fontWeight: isCur ? FontWeight.bold : FontWeight.normal)),
                      onTap: () => setState(() => idx = i),
                    );
                  }),
          ),
        ],
      ),
    );
  }
}

/// --------- PDF utils (pure Dart via Syncfusion) ----------
Future<String> _parsePdfBytesToCleanText(Uint8List bytes) async {
  final doc = PdfDocument(inputBytes: bytes);
  final ext = PdfTextExtractor(doc);
  final buf = StringBuffer();
  for (int i = 0; i < doc.pages.count; i++) {
    buf.write(ext.extractText(startPageIndex: i, endPageIndex: i));
    buf.write(' ');
  }
  doc.dispose();
  return _cleanup(buf.toString());
}
String _cleanup(String raw) => raw.replaceAll(RegExp(r'\\s+'), ' ').trim();
List<String> _splitIntoSentences(String text) {
  final re = RegExp(r'(?<=[.!?])\\s+(?=[A-Z0-9\\"])');
  return text.split(re).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}
