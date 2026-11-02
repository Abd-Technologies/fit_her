/// Shared greeting-name sanitizer (Wave 0 D-04).
///
/// Rejects empty values and known placeholder fragments like `last` /
/// `first` that used to render as "Hi last" when the wrong name field
/// was stored or the API returned a template token.
String friendlyDisplayName({
  String? firstName,
  String? lastName,
  String? username,
  String fallback = 'there',
}) {
  String? pick(String? raw) {
    if (raw == null) return null;
    final n = raw.trim();
    if (n.isEmpty) return null;
    final lower = n.toLowerCase();
    const banned = {
      'last',
      'first',
      'lastname',
      'firstname',
      'null',
      'undefined',
      'name',
      'user',
      'n/a',
      'na',
    };
    if (banned.contains(lower)) return null;
    return n;
  }

  return pick(firstName) ?? pick(username) ?? pick(lastName) ?? fallback;
}
