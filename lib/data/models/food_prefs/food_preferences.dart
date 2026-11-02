/// 2NH1 — diet type, hard allergies, soft dislikes.
class FoodPreferences {
  final String dietType; // omnivore|vegetarian|vegan|halal|dairy_free|custom
  final List<String> allergies; // hard blocks
  final List<String> dislikes; // soft

  const FoodPreferences({
    this.dietType = 'omnivore',
    this.allergies = const [],
    this.dislikes = const [],
  });

  static const dietTypes = [
    'omnivore',
    'vegetarian',
    'vegan',
    'halal',
    'dairy_free',
    'custom',
  ];

  static const allergyOptions = [
    'nuts',
    'dairy',
    'gluten',
    'eggs',
    'seafood',
    'soy',
    'sesame',
  ];

  Map<String, dynamic> toJson() => {
        'dietType': dietType,
        'allergies': allergies,
        'dislikes': dislikes,
      };

  factory FoodPreferences.fromJson(Map<String, dynamic> json) {
    return FoodPreferences(
      dietType: json['dietType']?.toString() ?? 'omnivore',
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dislikes: (json['dislikes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  FoodPreferences copyWith({
    String? dietType,
    List<String>? allergies,
    List<String>? dislikes,
  }) {
    return FoodPreferences(
      dietType: dietType ?? this.dietType,
      allergies: allergies ?? this.allergies,
      dislikes: dislikes ?? this.dislikes,
    );
  }

  /// Hard block if any allergy token appears in [text] (name/ingredients).
  bool isAllergyBlocked(String text) {
    final lower = text.toLowerCase();
    for (final a in allergies) {
      if (lower.contains(a.toLowerCase())) return true;
    }
    if (dietType == 'vegan' &&
        (lower.contains('chicken') ||
            lower.contains('beef') ||
            lower.contains('mutton') ||
            lower.contains('fish') ||
            lower.contains('egg') ||
            lower.contains('dairy') ||
            lower.contains('milk') ||
            lower.contains('ghee'))) {
      return true;
    }
    if (dietType == 'vegetarian' &&
        (lower.contains('chicken') ||
            lower.contains('beef') ||
            lower.contains('mutton') ||
            lower.contains('fish') ||
            lower.contains('seafood'))) {
      return true;
    }
    if (dietType == 'dairy_free' &&
        (lower.contains('dairy') ||
            lower.contains('milk') ||
            lower.contains('cheese') ||
            lower.contains('yogurt') ||
            lower.contains('ghee') ||
            lower.contains('butter'))) {
      return true;
    }
    return false;
  }

  bool isDisliked(String text) {
    final lower = text.toLowerCase();
    return dislikes.any((d) => lower.contains(d.toLowerCase()));
  }
}
