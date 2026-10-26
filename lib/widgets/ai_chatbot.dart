import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/incoming_share_payload.dart';
import '../services/pdf_service.dart';
import '../services/localization_service.dart';
import '../services/threat_analysis_engine.dart';

class AiChatbot extends StatefulWidget {
  const AiChatbot({super.key});

  @override
  State<AiChatbot> createState() => _AiChatbotState();
}

class _AiChatbotState extends State<AiChatbot> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  final ThreatAnalysisEngine _urlAnalysisEngine = const ThreatAnalysisEngine();
  late final GenerativeModel _model;
  late final ChatSession _chat;
  bool _isLoading = false;

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();

    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
      systemInstruction: Content.system(
        'You are "Cyber Uday AI Voice Assistant". Your goal is to help victims create a cybercrime incident report through a conversation. '
        'Step 1: Ask the user what happened. '
        'Step 2: Ask for the date and time of the incident. '
        'Step 3: Ask for any suspect details or platform used (e.g. WhatsApp, Instagram, Bank name). '
        'Step 4: Ask for any transaction IDs or links involved. '
        'Keep your responses very short and conversational. '
        'Once you have all details, say exactly: "I have gathered all the information. FINAL REPORT SUMMARY:" followed by a clean summary of everything. '
        'At the end of every response, if you are still missing info, ask one simple follow-up question.',
      ),
    );

    _chat = _model.startChat();

    _addBotMessage(
      LocalizationService.instance.translate('assistant_initial_greeting'),
    );
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add({'role': 'bot', 'text': text});
    });
    _speak(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _speak(String text) async {
    final cleanText = text
        .replaceAll('*', '')
        .replaceAll('#', '')
        .replaceFirst('FINAL REPORT SUMMARY:', '');
    await _flutterTts.speak(cleanText);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _lastWords = val.recognizedWords;
            _controller.text = _lastWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_controller.text.isNotEmpty) {
        _sendMessage();
      }
    }
  }

  Future<void> _generatePdfFromChat(String content) async {
    final cleanContent = content
        .replaceFirst('FINAL REPORT SUMMARY:', '')
        .trim();
    final reportData = {
      'id': 'VOICE-GEN-${DateTime.now().millisecondsSinceEpoch}',
      'type': 'Voice-Assisted Security Report',
      'description': cleanContent,
      'timeline': 'Interview recorded via AI',
      'evidence': 'Statement provided via Voice',
    };
    await PdfService.generateReportPdf(reportData);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final List<String> urls = IncomingSharePayload(
      id: 'assistant-url-preview',
      receivedAt: DateTime.now(),
      text: text,
      attachments: const <IncomingShareAttachment>[],
      sourceApplication: 'Cyber Uday Assistant',
    ).urls;
    if (urls.isNotEmpty) {
      await _analyzeSubmittedUrl(urls.first, text);
      return;
    }

    try {
      final response = await _chat
          .sendMessage(Content.text(text))
          .timeout(const Duration(seconds: 30));
      final botResponse =
          response.text ??
          LocalizationService.instance.translate('assistant_unavailable');

      if (mounted) {
        setState(() {
          _messages.add({'role': 'bot', 'text': botResponse});
          _isLoading = false;
        });
        _speak(botResponse);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        _addBotMessage(
          LocalizationService.instance.translate('assistant_connection_error'),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _analyzeSubmittedUrl(String url, String message) async {
    final ThreatAnalysisRun run = await _urlAnalysisEngine.analyze(
      IncomingSharePayload.fromManualUrl(url, note: message),
    );
    final String evidence = run.analysis.indicators.isEmpty
        ? 'No local warning indicators were found.'
        : run.analysis.indicators.take(3).join(' ');
    final String response =
        '${run.analysis.title}. ${run.analysis.message} '
        '$evidence Threat intelligence and redirect checks are currently unavailable, so this is not a safety guarantee.';
    if (!mounted) return;
    setState(() {
      _messages.add(<String, String>{'role': 'bot', 'text': response});
      _isLoading = false;
    });
    _speak(response);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF040B11),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Color(0xFF1E4A67), width: 2)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isBot = msg['role'] == 'bot';
                final text = msg['text']!;

                return Column(
                  crossAxisAlignment: isBot
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    _buildMessageBubble(text, !isBot),
                    if (isBot && text.contains('FINAL REPORT SUMMARY:'))
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 16),
                        child: ElevatedButton.icon(
                          onPressed: () => _generatePdfFromChat(text),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text(
                            LocalizationService.instance.translate(
                              'assistant_download_report',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3FFFD7),
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Color(0xFF3FFFD7),
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF07111A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSpeaking ? Icons.volume_up_rounded : Icons.mic,
            color: const Color(0xFF3FFFD7),
            size: 24,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocalizationService.instance.translate('assistant_voice_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                LocalizationService.instance.translate(
                  'assistant_voice_subtitle',
                ),
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              _flutterTts.stop();
              _speech.stop();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1E4A67) : const Color(0xFF10273A),
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? Radius.zero : null,
            bottomLeft: isUser ? null : Radius.zero,
          ),
          border: isUser
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _listen,
            child: CircleAvatar(
              backgroundColor: _isListening
                  ? Colors.red
                  : const Color(0xFF3FFFD7),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _isListening
                    ? LocalizationService.instance.translate(
                        'assistant_listening',
                      )
                    : LocalizationService.instance.translate(
                        'assistant_type_or_mic',
                      ),
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF10273A),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF3FFFD7),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
