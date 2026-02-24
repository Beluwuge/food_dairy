class DishEntry {
  final int? id;
  final String imagePath;
  final String name;
  final String description;
  final int calories;
  final String cuisine;
  final String createdAt; // ISO string

  DishEntry({
    this.id,
    required this.imagePath,
    required this.name,
    required this.description,
    required this.calories,
    required this.cuisine,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'image_path': imagePath,
    'name': name,
    'description': description,
    'calories': calories,
    'cuisine': cuisine,
    'created_at': createdAt,
  };

  static DishEntry fromMap(Map<String, Object?> map) => DishEntry(
    id: map['id'] as int?,
    imagePath: map['image_path'] as String,
    name: map['name'] as String,
    description: map['description'] as String,
    calories: (map['calories'] as num).toInt(),
    cuisine: map['cuisine'] as String,
    createdAt: map['created_at'] as String,
  );
}