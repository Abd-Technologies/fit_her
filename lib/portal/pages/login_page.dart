import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../portal_session.dart';
import '../portal_theme.dart';
import '../shell/portal_shell.dart';

/// Staff login: email + password. The server finds her role and refuses
/// client accounts ("Please use the Fit Her mobile app").
class PortalLoginPage extends StatefulWidget {
  const PortalLoginPage({super.key});

  @override
  State<PortalLoginPage> createState() => _PortalLoginPageState();
}

class _PortalLoginPageState extends State<PortalLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await Get.find<PortalSession>().login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Get.offAll(() => const PortalShell(), transition: Transition.fadeIn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              decoration: PT.card(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.spa_outlined, color: PT.green),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Fit Her', style: PT.t(18, w: FontWeight.w700)),
                    Text('Team portal', style: PT.t(12.5, c: PT.sage)),
                  ]),
                ]),
                const SizedBox(height: 28),
                Text('Log in', style: PT.t(22, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('For admins, trainers and dietitians.', style: PT.t(13, c: PT.sage)),
                const SizedBox(height: 20),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hide = !_hide),
                      icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: PT.sage),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFDEEEE), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: PT.t(12.5, c: PT.red)),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PT.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Log in', style: PT.t(15, w: FontWeight.w600, c: Colors.white)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
