import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 1P3 — FAQ/rules assistant shell (LLM later).
class SupportAssistantScreen extends StatefulWidget {
  const SupportAssistantScreen({super.key});

  @override
  State<SupportAssistantScreen> createState() => _SupportAssistantScreenState();
}

class _SupportAssistantScreenState extends State<SupportAssistantScreen> {
  final _controller = TextEditingController();
  final _messages = <(bool, String)>[
    (
      false,
      'Hi — I can help with plans, payments, freeze, and logging. Ask a short question.'
    ),
  ];

  static const _faq = <String, String>{
    'payment':
        'Upload your payment slip from Plans → Subscribe. Status updates after review. Instant activation comes next.',
    'freeze':
        'You can freeze from Profile. Your plan pause is reflected on Home with an Unfreeze button.',
    'trial':
        'Start a trial from the plans banner or unpaid home. First-week tips appear on Home.',
    'luna':
        'Luna is a Plus morning card built from your logs. Free users get a short phase message.',
    'photo':
        'Free includes a monthly meal-photo cap. Plus is unlimited. You can edit any logged meal.',
  };

  void _reply(String input) {
    final q = input.toLowerCase();
    String answer =
        'I noted that. For account-specific help, message Customer Support from Profile.';
    for (final e in _faq.entries) {
      if (q.contains(e.key)) {
        answer = e.value;
        break;
      }
    }
    setState(() {
      _messages.add((true, input));
      _messages.add((false, answer));
    });
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7E4),
      appBar: AppBar(
        title: const Text(
          'FitHer Help',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Color(0xFF163220),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF163220)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final mine = m.$1;
                return Align(
                  alignment:
                      mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: mine ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.$2,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: mine
                            ? const Color(0xFF163220)
                            : const Color(0xFF4F6B5A),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask about payment, freeze, Luna…',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) _reply(v.trim());
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final v = _controller.text.trim();
                      if (v.isNotEmpty) _reply(v);
                    },
                    icon: Icon(Icons.send, color: AppColors.primaryDeep),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
