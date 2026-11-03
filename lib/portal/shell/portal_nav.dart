import 'package:flutter/foundation.dart';

/// Ask the shell to open another menu item, e.g. portalGo('d_clients').
/// Unknown keys (not in this role's menu) are ignored.
final ValueNotifier<String?> portalGoTo = ValueNotifier<String?>(null);

void portalGo(String key) {
  portalGoTo.value = null;
  portalGoTo.value = key;
}
