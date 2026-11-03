import '../../portal_api.dart';

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

/// Loaders shared by the Plans screens. Each returns null when it fails.
class PlansData {
  PlansData._();

  static Future<List<Map<String, dynamic>>?> countries() async {
    final b = await PortalApi.get('/country');
    return PortalApi.ok(b) && b['data'] is Map ? _list(b['data']['countries']) : null;
  }

  static Future<List<Map<String, dynamic>>?> durations() async {
    final b = await PortalApi.get('/duration/create');
    if (!(PortalApi.ok(b) && b['data'] is Map)) return null;
    final l = _list(b['data']['durations']);
    l.sort((a, c) => daysOf(a['duration']).compareTo(daysOf(c['duration'])));
    return l;
  }

  static Future<List<Map<String, dynamic>>?> plans() async {
    final b = await PortalApi.get('/admin/get_plans');
    return PortalApi.ok(b) && b['data'] is Map ? _list(b['data']['plans']) : null;
  }

  static Future<List<Map<String, dynamic>>?> categories() async {
    final b = await PortalApi.get('/admin/all_categories');
    return PortalApi.ok(b) && b['data'] is Map ? _list(b['data']['categories']) : null;
  }

  static Future<List<Map<String, dynamic>>> subCategories(dynamic catId) async {
    final b = await PortalApi.get('/admin/get_subcategories/$catId');
    return PortalApi.ok(b) && b['data'] is Map ? _list(b['data']['data']) : <Map<String, dynamic>>[];
  }

  static Future<List<Map<String, dynamic>>> dietitians() async {
    final b = await PortalApi.get('/admin/get_users_based_on_types/Dietition');
    return PortalApi.ok(b) && b['data'] is Map ? _list(b['data']['users']) : <Map<String, dynamic>>[];
  }

  /// "90 days" → 90 (for sorting). Unknown text sorts last.
  static int daysOf(dynamic duration) =>
      int.tryParse(RegExp(r'\d+').firstMatch('${duration ?? ''}')?.group(0) ?? '') ?? 99999;

  static String money(dynamic amount, [dynamic currency]) {
    final a = '${amount ?? ''}'.trim();
    if (a.isEmpty) return '—';
    final c = '${currency ?? ''}'.trim();
    return c.isEmpty ? a : '$c $a';
  }
}
