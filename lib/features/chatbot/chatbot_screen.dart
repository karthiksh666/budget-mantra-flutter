import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _Msg {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _Msg({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final List<_Msg> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String? _sessionId;
  bool _isTyping = false;
  bool _isLoadingHistory = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() { _isLoadingHistory = true; _historyError = null; });
    try {
      final history = await ApiClient.instance.getChatHistory();
      final msgs = history.cast<Map<String, dynamic>>().map((h) {
        final role = h['role'] as String? ?? 'assistant';
        final content = h['content'] as String? ?? '';
        return _Msg(text: content, isUser: role == 'user');
      }).toList();
      if (mounted) {
        setState(() {
          _messages.addAll(msgs);
          _isLoadingHistory = false;
        });
        _scrollToBottom(jump: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          // History is best-effort; don't block the chat on failure
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    final userMsg = _Msg(text: text, isUser: true);
    _inputCtrl.clear();

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await ApiClient.instance.chat(text, sessionId: _sessionId);
      final reply = response['reply'] as String? ?? '';
      final newSessionId = response['session_id'] as String?;

      if (mounted) {
        setState(() {
          if (newSessionId != null) _sessionId = newSessionId;
          _messages.add(_Msg(text: reply, isUser: false));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_Msg(
            text: "Sorry, I couldn't process your request. Please try again.",
            isUser: false,
          ));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (jump) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      } else {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _showGreeting =>
      !_isLoadingHistory && _messages.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA580C), AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Chanakya', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  'Your AI financial advisor',
                  style: AppTextStyles.label.copyWith(fontSize: 11, color: AppColors.textSub),
                ),
              ],
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _showGreeting
                    ? _GreetingView()
                    : _MessageList(
                        messages: _messages,
                        isTyping: _isTyping,
                        scrollController: _scrollCtrl,
                      ),
          ),
          _InputBar(
            controller: _inputCtrl,
            focusNode: _focusNode,
            isTyping: _isTyping,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ── Message List ──────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<_Msg> messages;
  final bool isTyping;
  final ScrollController scrollController;

  const _MessageList({
    required this.messages,
    required this.isTyping,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (isTyping ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (isTyping && index == itemCount - 1) {
          return const _TypingIndicator();
        }
        return _MessageBubble(msg: messages[index]);
      },
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _Msg msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('hh:mm a');
    final timeStr = timeFmt.format(msg.timestamp);

    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEA580C), AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(timeStr, style: AppTextStyles.label.copyWith(fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
            ),
          ],
        ),
      );
    }

    // AI message
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: AppTextStyles.body.copyWith(height: 1.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(timeStr, style: AppTextStyles.label.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing Indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _Dot(controller: _controller, index: i)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final int index;
  const _Dot({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Stagger each dot by 0.25 of the cycle
        final phase = (controller.value - index * 0.25).clamp(0.0, 1.0);
        // Map phase through a sine-like curve: up for first half, down for second half
        final t = phase < 0.5 ? phase * 2 : 2 - phase * 2;
        final offset = -6.0 * t;
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// ── Greeting View ─────────────────────────────────────────────────────────────

class _GreetingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA580C), AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Chanakya', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Namaste! I\'m Chanakya, your AI financial advisor. Ask me anything about your finances.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSub, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _SuggestionChips(),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  static const _suggestions = [
    'How can I save more?',
    'Analyze my spending',
    'Best investment options?',
    'Help me plan a budget',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _suggestions.map((s) => _SuggestionChip(text: s)).toList(),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Find the ancestor state and populate the input
        final state = context.findAncestorStateOfType<_ChatbotScreenState>();
        if (state != null) {
          state._inputCtrl.text = text;
          state._focusNode.requestFocus();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Text(
          text,
          style: AppTextStyles.body.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isTyping;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isTyping,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  maxLines: 3,
                  minLines: 1,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Ask Chanakya anything...',
                    hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              child: Material(
                color: isTyping ? AppColors.border : AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: isTyping ? null : onSend,
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: isTyping
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
