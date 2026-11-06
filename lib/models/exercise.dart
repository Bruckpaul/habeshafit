/// Base URL for images of the bundled free-exercise-db dataset (The Unlicense).
const String kExerciseImageBase =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';

/// An exercise from the bundled library or created by the user.
class Exercise {
  final String id;
  final String name;
  final String equipment;
  final String category;
  final String? level;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;

  /// Relative image paths (library) or absolute URLs (custom).
  final List<String> images;
  final bool isCustom;

  const Exercise({
    required this.id,
    required this.name,
    this.equipment = 'other',
    this.category = 'strength',
    this.level,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.instructions = const [],
    this.images = const [],
    this.isCustom = false,
  });

  String get primaryMuscle =>
      primaryMuscles.isEmpty ? 'other' : primaryMuscles.first;

  List<String> get imageUrls => images
      .map((p) => p.startsWith('http') ? p : '$kExerciseImageBase$p')
      .toList();

  factory Exercise.fromJson(Map<String, Object?> json) {
    List<String> list(Object? v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      equipment: (json['equipment'] as String?) ?? 'other',
      category: (json['category'] as String?) ?? 'strength',
      level: json['level'] as String?,
      primaryMuscles: list(json['primary']),
      secondaryMuscles: list(json['secondary']),
      instructions: list(json['instructions']),
      images: list(json['images']),
      isCustom: (json['custom'] as bool?) ?? false,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'equipment': equipment,
        'category': category,
        'level': level,
        'primary': primaryMuscles,
        'secondary': secondaryMuscles,
        'instructions': instructions,
        'images': images,
        'custom': isCustom,
      };
}
