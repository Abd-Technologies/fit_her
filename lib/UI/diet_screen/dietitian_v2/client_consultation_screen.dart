import '../../../values/constants.dart';
import '../../../data/api_provider/api_provider.dart';
import '../../../data/controllers/auth_controller/auth_controller.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/controllers/dietitian_dashboard_controller/dietitian_dashboard_controller.dart';
import '../../../data/models/consultation/day7_review.dart';
import '../../../data/models/consultation/pre_consultation_profile.dart';
import '../../../data/models/consultation/progress_submission.dart';
import '../../../widgets/toasts.dart';
import 'edit_client_form_screen.dart';

/// Phase 3 — dietitian-side per-client view. Three tabs:
///   1. Profile     → PreConsultationProfile, with private comments
///   2. Day 7 reviews → ordered, flagged badge for ones that tripped
///                      Decision-6 thresholds
///   3. Progress    → Day 15 / Day 30 submissions (no photos —
///                      Section 10, device-only on the client)
///
/// Navigation: opened from the existing dietitian home / clients
/// screens by passing a userId + display name.
class ClientConsultationScreen extends StatefulWidget {
  final int userId;
  final String? clientName;

  const ClientConsultationScreen({
    Key? key,
    required this.userId,
    this.clientName,
  }) : super(key: key);

  @override
  State<ClientConsultationScreen> createState() =>
      _ClientConsultationScreenState();
}

class _ClientConsultationScreenState extends State<ClientConsultationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final DietitianDashboardController _ctrl;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _ctrl = Get.find<DietitianDashboardController>();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4E0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A3A22)),
        title: Text(
          widget.clientName ?? 'Client',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A3A22),
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF1A3A22),
          unselectedLabelColor: const Color(0xFF7A8C78),
          indicatorColor: const Color(0xFF6DC55A),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Reviews'),
            Tab(text: 'Progress'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProfileTab(
              userId: widget.userId,
              clientName: widget.clientName,
              ctrl: _ctrl),
          _ReviewsTab(userId: widget.userId, ctrl: _ctrl),
          _ProgressTab(userId: widget.userId, ctrl: _ctrl),
        ],
      ),
    );
  }
}

// ── Profile tab ──────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final int userId;
  final String? clientName;
  final DietitianDashboardController ctrl;
  const _ProfileTab({required this.userId, required this.ctrl, this.clientName});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _loading = true;
  Map<String, dynamic>? _raw;
  PreConsultationProfile? _profile;
  bool _addingComment = false;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await widget.ctrl.loadClientProfileRaw(widget.userId);
    if (!mounted) return;
    // Parse outside setState and never let a bad field throw — that used
    // to leave this tab spinning forever.
    PreConsultationProfile? parsed;
    try {
      parsed = raw == null ? null : PreConsultationProfile.fromJson(raw);
    } catch (_) {
      parsed = null;
    }
    setState(() {
      _raw = raw;
      _profile = parsed;
      _loading = false;
    });
  }

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _addingComment = true);
    final ok =
        await widget.ctrl.addClientComment(userId: widget.userId, text: text);
    if (!mounted) return;
    setState(() => _addingComment = false);
    if (ok) {
      _commentCtrl.clear();
      await _load();
      CustomToast.successToast(msg: 'Comment added');
    }
  }

  // Opens the editable form. Saving overwrites the client's answers and
  // is what the AI uses to build the plan, so reload afterwards.
  Future<void> _openEdit() async {
    final saved = await Get.to<bool>(() => EditClientFormScreen(
          userId: widget.userId,
          clientName: widget.clientName,
          initial: _raw,
        ));
    if (saved == true && mounted) await _load();
  }

  List<dynamic> get _comments {
    final raw = _raw;
    if (raw == null) return const [];
    final c = raw['dietitianComments'];
    if (c is List) return c;
    if (c is String && c.trim().isNotEmpty) {
      try {
        final v = jsonDecode(c);
        if (v is List) return v;
      } catch (_) {}
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6DC55A)),
        ),
      );
    }
    final p = _profile;
    if (p == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "The client hasn't filled her form yet. You can fill it with her during the consultation.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xFF7A8C78),
                ),
              ),
              const SizedBox(height: 16),
              _EditFormButton(label: 'Fill form now', onTap: _openEdit),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF6DC55A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _StatusPill(complete: p.isComplete),
              const Spacer(),
              _EditFormButton(label: 'Edit form', onTap: _openEdit),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
              title: 'Goal',
              body: _bodyOrEmpty(_humanise(p.goals))),
          _Section(
              title: 'Meals per day',
              body: _bodyOrEmpty(_raw?['mealsPerDay']?.toString())),
          _Section(title: 'Allergies', body: _bodyOrEmpty(p.allergies)),
          _Section(
              title: 'Medical conditions',
              body: _bodyOrEmpty(p.medicalConditions)),
          // Symptom check results (PCOS / thyroid / … screening in the app).
          _ScreeningSection(userId: widget.userId),
          _Section(
              title: 'Cycle / reproductive',
              body: _bodyOrEmpty(_humanise(p.pregnancyMenstrualStatus))),
          _Section(
            title: 'Dietary preferences',
            body: _bodyOrEmpty(
                p.dietaryPreferences?.map((x) => _humanise(x)).join(', ')),
          ),
          if ((p.familyHistory ?? '').isNotEmpty)
            _Section(title: 'Family history', body: p.familyHistory!),
          if ((p.surgeries ?? '').isNotEmpty)
            _Section(title: 'Surgeries', body: p.surgeries!),
          if ((p.currentMedications ?? '').isNotEmpty)
            _Section(title: 'Medications', body: p.currentMedications!),
          if ((p.fastingHabits ?? '').isNotEmpty)
            _Section(title: 'Fasting habits', body: p.fastingHabits!),
          if (p.workoutSection != null) ...[
            _Section(
              title: 'Fitness level',
              body:
                  _bodyOrEmpty(_humanise(p.workoutSection?['fitnessLevel'])),
            ),
            if ((p.workoutSection?['injuries'] as String?)?.isNotEmpty ==
                true)
              _Section(
                title: 'Injuries / avoid',
                body: p.workoutSection!['injuries'] as String,
              ),
            if (p.workoutSection?['equipment'] is List)
              _Section(
                title: 'Equipment',
                body: _bodyOrEmpty(
                  (p.workoutSection!['equipment'] as List)
                      .map((x) => _humanise(x.toString()))
                      .join(', '),
                ),
              ),
          ],

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Private notes',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A3A22),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Visible to dietitian + admin only.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: Color(0xFF7A8C78),
            ),
          ),
          const SizedBox(height: 10),
          if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No notes yet.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFF9AB09A),
                ),
              ),
            )
          else
            ..._comments.map((c) => _CommentTile(comment: c)),

          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a private note…',
              hintStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Color(0xFF9AB09A),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFC8DEC4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFC8DEC4)),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF1A3A22),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addingComment ? null : _addComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6DC55A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _addingComment
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Add note',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static String _bodyOrEmpty(String? s) =>
      (s == null || s.trim().isEmpty) ? '—' : s.trim();
  static String _humanise(String? s) {
    if (s == null) return '';
    return s.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}

class _EditFormButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _EditFormButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool complete;
  const _StatusPill({required this.complete});
  @override
  Widget build(BuildContext context) {
    final bg = complete ? const Color(0xFFE4F9D7) : const Color(0xFFFDEFD0);
    final fg = complete ? const Color(0xFF2D6B26) : const Color(0xFF8A6515);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          complete ? 'Profile complete' : 'Profile in progress',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A8C78),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A3A22),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final dynamic comment;
  const _CommentTile({required this.comment});
  @override
  Widget build(BuildContext context) {
    final c = comment is Map ? comment as Map : const {};
    final author = (c['authorName'] ?? 'Staff').toString();
    final text = (c['text'] ?? '').toString();
    final ts = (c['timestamp'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                author,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3A22),
                ),
              ),
              const Spacer(),
              Text(
                _shortTs(ts),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: Color(0xFF9AB09A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Color(0xFF1A3A22),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static String _shortTs(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]}, ${dt.hour}:$mm';
    } catch (_) {
      return iso;
    }
  }
}

// ── Reviews tab ──────────────────────────────────────────────────────

class _ReviewsTab extends StatefulWidget {
  final int userId;
  final DietitianDashboardController ctrl;
  const _ReviewsTab({required this.userId, required this.ctrl});

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  bool _loading = true;
  List<Day7Review> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await widget.ctrl.loadReviews(userId: widget.userId);
    if (!mounted) return;
    setState(() {
      _reviews = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6DC55A)),
        ),
      );
    }
    if (_reviews.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No reviews submitted yet.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF7A8C78),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF6DC55A),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reviews.length,
        itemBuilder: (_, i) => Day7ReviewTile(review: _reviews[i]),
      ),
    );
  }
}

class Day7ReviewTile extends StatelessWidget {
  final Day7Review review;
  const Day7ReviewTile({Key? key, required this.review}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: review.flagged
            ? Border.all(color: const Color(0xFFE24B4A), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cycle ${review.cycle ?? '?'}'
                  ' · ${(review.planType ?? 'plan').toUpperCase()}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A8C78),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (review.flagged)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE24B4A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'FLAGGED',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (review.adherencePct != null)
            _Field(label: 'Adherence', value: '${review.adherencePct}%'),
          if (review.hungerLevel != null)
            _Field(label: 'Hunger', value: _humanise(review.hungerLevel!)),
          if (review.difficultyLevel != null)
            _Field(
                label: 'Difficulty',
                value: _humanise(review.difficultyLevel!)),
          if (review.satisfaction != null)
            _Field(label: 'Satisfaction', value: '${review.satisfaction}/5'),
          if (review.painReported)
            _Field(
              label: 'Pain reported',
              value: review.painLocation == null
                  ? 'Yes'
                  : 'Yes — ${review.painLocation}',
              tone: _Tone.warn,
            ),
          if (review.severeSideEffectsReported)
            const _Field(
              label: 'Severe side effects',
              value: 'Yes',
              tone: _Tone.warn,
            ),
          if (review.flagged && review.flagReasons != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: review.flagReasons!
                  .map((r) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1EE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFFFCDB8), width: 1),
                        ),
                        child: Text(
                          r.toString(),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE24B4A),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (review.createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              _shortTs(review.createdAt!),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Color(0xFF9AB09A),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _humanise(String s) =>
      s.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');

  static String _shortTs(DateTime dt) {
    final local = dt.toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

enum _Tone { neutral, warn }

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final _Tone tone;
  const _Field({
    required this.label,
    required this.value,
    this.tone = _Tone.neutral,
  });
  @override
  Widget build(BuildContext context) {
    final color = tone == _Tone.warn
        ? const Color(0xFFE24B4A)
        : const Color(0xFF1A3A22);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF7A8C78),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress tab ─────────────────────────────────────────────────────

class _ProgressTab extends StatefulWidget {
  final int userId;
  final DietitianDashboardController ctrl;
  const _ProgressTab({required this.userId, required this.ctrl});

  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<_ProgressTab> {
  bool _loading = true;
  List<ProgressSubmission> _subs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await widget.ctrl.loadClientProgress(widget.userId);
    if (!mounted) return;
    setState(() {
      _subs = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6DC55A)),
        ),
      );
    }
    if (_subs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No progress submissions yet.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF7A8C78),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF6DC55A),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _subs.length,
        itemBuilder: (_, i) => _ProgressCard(submission: _subs[i]),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final ProgressSubmission submission;
  const _ProgressCard({required this.submission});
  @override
  Widget build(BuildContext context) {
    final s = submission;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Day ${s.cycle ?? '?'}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (s.submittedAt != null)
                Text(
                  _shortTs(s.submittedAt!),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: Color(0xFF9AB09A),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (s.weightKg != null)
            _Field(label: 'Weight', value: '${s.weightKg!.toStringAsFixed(1)} kg'),
          if (s.waistCm != null)
            _Field(label: 'Waist', value: '${s.waistCm!.toStringAsFixed(1)} cm'),
          if (s.hipsCm != null)
            _Field(label: 'Hips', value: '${s.hipsCm!.toStringAsFixed(1)} cm'),
          if (s.chestCm != null)
            _Field(label: 'Chest', value: '${s.chestCm!.toStringAsFixed(1)} cm'),
          if (s.armsCm != null)
            _Field(label: 'Arms', value: '${s.armsCm!.toStringAsFixed(1)} cm'),
          if (s.thighsCm != null)
            _Field(
                label: 'Thighs', value: '${s.thighsCm!.toStringAsFixed(1)} cm'),
          if (s.clothesFit != null)
            _Field(label: 'Clothes', value: _humanise(s.clothesFit!)),
          if (s.sleepQuality != null)
            _Field(label: 'Sleep', value: '${s.sleepQuality}/5'),
          if (s.satisfaction != null)
            _Field(label: 'Satisfaction', value: '${s.satisfaction}/5'),
          if ((s.strengthNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Strength notes',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A8C78),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.strengthNotes!,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Color(0xFF1A3A22),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _humanise(String s) =>
      s.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');

  static String _shortTs(DateTime dt) {
    final local = dt.toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}


/// Dietitian view of her in-app symptom checks (latest per condition,
/// highest risk first). Data: GET /admin/healthScreening/:userId.
class _ScreeningSection extends StatefulWidget {
  final int userId;
  const _ScreeningSection({required this.userId});
  @override
  State<_ScreeningSection> createState() => _ScreeningSectionState();
}

class _ScreeningSectionState extends State<_ScreeningSection> {
  List<Map<String, dynamic>> _rows = [];
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = Get.find<AuthController>().sharedPreferences.getString(Constants.accessToken) ?? '';
      final r = await Get.find<ApiProvider>()
          .getData('/admin/healthScreening/${widget.userId}', headers: {'accessToken': token});
      final body = r.body;
      if (body is Map && body['status'] == '1' && body['data'] is Map && body['data']['results'] is List) {
        final list = (body['data']['results'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (mounted) setState(() => _rows = list);
      }
    } catch (_) {}
  }

  String _date(dynamic iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'SYMPTOM CHECK (IN APP)',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A8C78),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        ..._rows.map((r) {
          final risk = '${r['riskLevel'] ?? 'low'}';
          final color = risk == 'high'
              ? const Color(0xFFC2412D)
              : risk == 'moderate'
                  ? const Color(0xFFB7791F)
                  : const Color(0xFF4C6A4B);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(
                child: Text('${r['conditionType']}',
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A3A22))),
              ),
              Text(risk[0].toUpperCase() + risk.substring(1),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 8),
              Text(_date(r['takenAt']),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF7A8C78))),
            ]),
          );
        }),
        TextButton(
          onPressed: () => setState(() => _open = !_open),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
          child: Text(_open ? 'Hide her answers' : 'Show her answers',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF4C6A4B))),
        ),
        if (_open)
          ..._rows.where((r) => r['answers'] is Map).map((r) {
            final a = Map<String, dynamic>.from(r['answers'] as Map);
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['conditionType']}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1A3A22))),
                ...a.entries.map((e) => Text('Q${(int.tryParse(e.key) ?? 0) + 1}: ${e.value}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF5A6B58), height: 1.4))),
              ]),
            );
          }),
      ]),
    );
  }
}
