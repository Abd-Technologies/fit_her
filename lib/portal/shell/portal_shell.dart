import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../pages/login_page.dart';
import '../portal_session.dart';
import '../portal_theme.dart';
import 'portal_menu.dart';
import 'portal_nav.dart';
import 'portal_pages.dart';

/// Side menu (by role) + top bar + page area.
class PortalShell extends StatefulWidget {
  const PortalShell({super.key});

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  final session = Get.find<PortalSession>();
  late final List<PortalMenuItem> _menu = portalMenuFor(session.role!);
  late PortalMenuItem _current = _menu.first;

  @override
  void initState() {
    super.initState();
    portalGoTo.addListener(_onGoTo);
  }

  @override
  void dispose() {
    portalGoTo.removeListener(_onGoTo);
    super.dispose();
  }

  void _onGoTo() {
    final k = portalGoTo.value;
    if (k == null) return;
    final item = _menu.where((m) => m.key == k).firstOrNull;
    if (item != null && mounted) _go(item);
  }

  void _go(PortalMenuItem item) {
    session.touch();
    setState(() => _current = item);
  }

  void _logout() {
    session.logout();
    Get.offAll(() => const PortalLoginPage(), transition: Transition.fadeIn);
  }

  Widget _menuTile(PortalMenuItem item) {
    final sel = item.key == _current.key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: sel ? const Color(0xFFEAF7E4) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _go(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              Icon(item.icon, size: 18, color: sel ? PT.greenDark : PT.sage),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.label,
                    overflow: TextOverflow.ellipsis,
                    style: PT.t(13, w: sel ? FontWeight.w600 : FontWeight.w400, c: sel ? PT.ink : const Color(0xFF3E5442))),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _menuItems() {
    final out = <Widget>[];
    String? group;
    for (final item in _menu) {
      if (item.group != null && item.group != group) {
        group = item.group;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 16, 6),
          child: Text(group!.toUpperCase(), style: PT.t(10.5, w: FontWeight.w700, c: PT.sage)),
        ));
      }
      out.add(_menuTile(item));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final sidebar = Container(
      width: 248,
      color: Colors.white,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: PT.wash, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.spa_outlined, color: PT.green, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Fit Her', style: PT.t(16, w: FontWeight.w700)),
            const SizedBox(width: 6),
            Text(session.roleLabel, style: PT.t(12, c: PT.sage)),
          ]),
        ),
        const Divider(height: 1, color: PT.line),
        Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 16), children: _menuItems())),
      ]),
    );
    return Scaffold(
      drawer: wide ? null : Drawer(child: sidebar),
      body: Row(children: [
        if (wide) sidebar,
        if (wide) const VerticalDivider(width: 1, color: PT.line),
        Expanded(
          child: Column(children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: PT.line))),
              child: Row(children: [
                if (!wide)
                  Builder(
                    builder: (c) => IconButton(onPressed: () => Scaffold.of(c).openDrawer(), icon: const Icon(Icons.menu)),
                  ),
                Text(_current.label, style: PT.t(17, w: FontWeight.w700)),
                const Spacer(),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: PT.wash,
                  child: Text(session.name.isEmpty ? '?' : session.name[0].toUpperCase(),
                      style: PT.t(13, w: FontWeight.w700, c: PT.greenDark)),
                ),
                const SizedBox(width: 8),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(session.name, style: PT.t(13, w: FontWeight.w600)),
                  Text(session.roleLabel, style: PT.t(11, c: PT.sage)),
                ]),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, size: 18, color: PT.sage),
                  label: Text('Log out', style: PT.t(13, c: PT.sage)),
                ),
              ]),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: KeyedSubtree(key: ValueKey(_current.key), child: portalPageFor(_current)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
