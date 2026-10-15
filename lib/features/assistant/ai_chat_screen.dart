import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/cx_theme.dart';

class AiChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestions;

  AiChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions = const [],
  });
}

class CodexaAiScreen extends ConsumerStatefulWidget {
  const CodexaAiScreen({super.key});

  @override
  ConsumerState<CodexaAiScreen> createState() => _CodexaAiScreenState();
}

class _CodexaAiScreenState extends ConsumerState<CodexaAiScreen> {
  final List<AiChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<String> _quickPrompts = [
    'What class do I have today?',
    'What topics are scheduled for tomorrow?',
    'Show my internship details & mentor',
    'How do I apply for leave?',
    'What are my assigned projects?',
    'Review my attendance status',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      AiChatMessage(
        text: 'Hello! I am **CodeXa AI**, your daily workspace assistant.\n\nI have authorized access to your internship domain, scheduled classes, daily curriculum topics, project tasks, and leave policies. How can I assist your workflow today?',
        isUser: false,
        timestamp: DateTime.now(),
        suggestions: _quickPrompts,
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendQuery(String queryText) async {
    final query = queryText.trim();
    if (query.isEmpty) return;

    _inputController.clear();
    setState(() {
      _messages.add(
        AiChatMessage(text: query, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final api = CxApiClient();
      final res = await api.dio.post(
        '/api/mobile/ai/chat',
        data: {'message': query},
      );

      if (res.data != null && res.data['ok'] == true) {
        final rawReply =
            res.data['reply']?.toString() ??
            'I could not generate a response. Please try again.';
        // Clean any leftover asterisks formatting
        final cleanReply = _cleanFormatting(rawReply);
        final suggestions =
            (res.data['suggestions'] as List<dynamic>?)
                ?.map((s) => s.toString())
                .toList() ??
            [];

        setState(() {
          _messages.add(
            AiChatMessage(
              text: cleanReply,
              isUser: false,
              timestamp: DateTime.now(),
              suggestions: suggestions,
            ),
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _messages.add(
            AiChatMessage(
              text:
                  res.data?['error']?['message']?.toString() ??
                  'Unable to complete request.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          AiChatMessage(
            text: 'Connection issue connecting to CodeXa AI. Please check your network and try again.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  String _cleanFormatting(String text) {
    var cleaned = text;
    // Remove triple asterisks or replace with bold
    cleaned = cleaned.replaceAll(RegExp(r'\*{3,}'), '**');
    return cleaned;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: AppBar(
        backgroundColor: CxColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: CxColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CxColors.crimson.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CxColors.crimson.withAlpha(100)),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: CxColors.crimson,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CODEXA AI',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: CxColors.textPrimary,
                  ),
                ),
                Text(
                  'AGENCY WORKSPACE COPILOT',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    color: CxColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CxColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CxColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'ONLINE',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.greenAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageItem(msg);
                },
              ),
            ),
            if (_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CxColors.crimson,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'CodeXa AI is synthesizing answer...',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: CxColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(AiChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: CxColors.crimson.withAlpha(220),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(2),
            ),
          ),
          child: Text(
            msg.text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: CxColors.crimson,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  'CodeXa AI',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: CxColors.textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: CxColors.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied response to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CxColors.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border.all(color: CxColors.borderSubtle),
              ),
              child: _buildRichMessageBody(msg.text),
            ),
            if (msg.suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: msg.suggestions.map((s) {
                  return InkWell(
                    onTap: () => _sendQuery(s),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: CxColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: CxColors.crimson.withAlpha(80),
                        ),
                      ),
                      child: Text(
                        s,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: CxColors.accent,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds a rich structured text widget handling markdown bold, bullets, and headings cleanly
  Widget _buildRichMessageBody(String rawText) {
    final lines = rawText.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Check for markdown headers
      if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              line.substring(4),
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              line.substring(3),
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              line.substring(2),
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        // Bullet list item
        final bulletContent = line.substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 3, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    color: CxColors.brightRed,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(child: _buildInlineFormattedText(bulletContent)),
              ],
            ),
          ),
        );
      } else {
        // Regular line
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildInlineFormattedText(line),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Parses inline bold (**bold**) and inline code (`code`)
  Widget _buildInlineFormattedText(String text) {
    final spans = <TextSpan>[];
    final regExp = RegExp(r'(\*\*(.*?)\*\*|`(.*?)`)');
    int lastEnd = 0;

    for (final match in regExp.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: CxColors.textPrimary,
              height: 1.45,
            ),
          ),
        );
      }

      final boldGroup = match.group(2);
      final codeGroup = match.group(3);

      if (boldGroup != null) {
        spans.add(
          TextSpan(
            text: boldGroup,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.45,
            ),
          ),
        );
      } else if (codeGroup != null) {
        spans.add(
          TextSpan(
            text: ' $codeGroup ',
            style: GoogleFonts.firaCode(
              fontSize: 12,
              color: CxColors.accent,
              backgroundColor: CxColors.secondaryDark,
              height: 1.45,
            ),
          ),
        );
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: CxColors.textPrimary,
            height: 1.45,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: CxColors.card,
        border: Border(top: BorderSide(color: CxColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: CxColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CxColors.borderSubtle),
              ),
              child: TextField(
                controller: _inputController,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: CxColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask CodeXa AI about classes, topics, tasks...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: CxColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (val) => _sendQuery(val),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _sendQuery(_inputController.text),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: CxColors.crimson,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
