import 'package:flutter/material.dart';

import '../../../values/constants.dart';
import '../../portal_api.dart';
import '../../portal_theme.dart';
import '../../widgets/portal_ui.dart';

/// Meal plan tracker tile in the app: sends the "package expiry" reminder
/// (GET /admin/syncrhonize) to every woman whose plan ends within 5 days.
class MealTrackerPage extends StatefulWidget {
  const MealTrackerPage({super.key});

  @override
  State<MealTrackerPage> createState() => _MealTrackerPageState();
}

class _MealTrackerPageState extends State<MealTrackerPage> {
  bool _sending = false;
  DateTime? _lastSent;

  Future<void> _send() async {
    final sure = await portalConfirm(
      context,
      title: 'Send the expiry reminder?',
      body: 'Every woman whose package ends in the next 5 days gets a phone notification: '
          '"Plan expiring soon. Your plan is about to expire."',
      yes: 'Send reminder',
    );
    if (!sure) return;
    setState(() => _sending = true);
    final b = await PortalApi.get(Constants.synchronization);
    if (!mounted) return;
    setState(() => _sending = false);
    if (PortalApi.ok(b)) {
      setState(() => _lastSent = DateTime.now());
      portalToast('Reminder sent', sub: 'Women with a package ending soon were notified.');
    } else {
      portalToast("Couldn't send the reminder", sub: PortalApi.msg(b), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(
        title: 'Meal plan tracker',
        sub: 'Remind women whose package is about to end, so they can renew in time.',
      ),
      Expanded(
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: PT.card(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.notifications_active_outlined, color: PT.green),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Package expiry reminder', style: PT.t(18, w: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    'This is a friendly reminder about packages that are about to expire. '
                    'Sending it in time helps women renew without a break in their plan.',
                    style: PT.t(13.5, h: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: PT.wash, borderRadius: BorderRadius.circular(12), border: Border.all(color: PT.line)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Who gets it', style: PT.t(13, w: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Women whose package ends between today and 5 days from now.', style: PT.t(12.5, c: PT.sage)),
                      const SizedBox(height: 8),
                      Text('What they see', style: PT.t(13, w: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('A phone notification: "Plan expiring soon. Your plan is about to expire."',
                          style: PT.t(12.5, c: PT.sage)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    _sending
                        ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2.4))
                        : ElevatedButton.icon(
                            style: portalPrimary(),
                            onPressed: _send,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('Send reminder'),
                          ),
                    const SizedBox(width: 14),
                    if (_lastSent != null)
                      Expanded(
                        child: Text(
                          'Sent at ${_lastSent!.hour}:${_lastSent!.minute.toString().padLeft(2, '0')}',
                          style: PT.t(12.5, c: PT.sage),
                        ),
                      ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
