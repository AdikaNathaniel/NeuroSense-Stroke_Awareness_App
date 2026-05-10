import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_button.dart';

class _Message {
  final String role;    // 'user' | 'assistant'
  final String content;
  const _Message({required this.role, required this.content});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl   = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final List<_Message> _messages = [];
  bool _loading = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    _inputCtrl.clear();
    setState(() {
      _messages.add(_Message(role: 'user', content: trimmed));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      final reply = await ApiService.chat(history);
      if (!mounted) return;
      setState(() => _messages.add(_Message(role: 'assistant', content: reply)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.add(const _Message(
          role: 'assistant',
          content: 'Sorry, I could not connect to the server. Please check your connection.')));
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NeuroSense AI'),
        centerTitle: true,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear chat',
              onPressed: () => setState(() => _messages.clear()),
            ),
          const ProfileIconButton(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? _emptyState() : _messageList(),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('NeuroSense AI',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Ask me anything about stroke awareness, risk factors, symptoms, and prevention.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) return _typingIndicator();
        final msg = _messages[i];
        return _MessageBubble(message: msg);
      },
    );
  }

  Widget _typingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18).copyWith(bottomLeft: Radius.zero),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DotPulse(delay: 0),
            SizedBox(width: 4),
            _DotPulse(delay: 150),
            SizedBox(width: 4),
            _DotPulse(delay: 300),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: 'Ask about stroke, risk factors…',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _send(_inputCtrl.text),
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _loading ? AppColors.divider : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _loading ? Icons.hourglass_bottom_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  bool get _isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left:  _isUser ? 64 : 0,
          right: _isUser ? 0 : 64,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: _isUser  ? Radius.zero : const Radius.circular(18),
            bottomLeft:  !_isUser ? Radius.zero  : const Radius.circular(18),
          ),
          border: _isUser ? null : Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: (_isUser ? AppColors.primary : Colors.black).withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: _isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _DotPulse extends StatefulWidget {
  final int delay;
  const _DotPulse({required this.delay});
  @override
  State<_DotPulse> createState() => _DotPulseState();
}

class _DotPulseState extends State<_DotPulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      ),
    );
  }
}
