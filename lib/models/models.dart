class DiaryEntry {
  final int? id;
  final String imagePath;
  final String comment;
  final int createdAtMillis;

  DiaryEntry({
    this.id,
    required this.imagePath,
    required this.comment,
    required this.createdAtMillis,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'image_path': imagePath,
    'comment': comment,
    'created_at_millis': createdAtMillis,
  };

  static DiaryEntry fromMap(Map<String, Object?> map) => DiaryEntry(
    id: map['id'] as int?,
    imagePath: map['image_path'] as String,
    comment: map['comment'] as String? ?? '',
    createdAtMillis: map['created_at_millis'] as int,
  );
}

class UserProfile {
  final int? id;
  final String name;
  final int age;
  final double weightKg;
  final double heightCm;

  UserProfile({
    this.id,
    required this.name,
    required this.age,
    required this.weightKg,
    required this.heightCm,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'age': age,
    'weight_kg': weightKg,
    'height_cm': heightCm,
  };

  static UserProfile fromMap(Map<String, Object?> map) => UserProfile(
    id: map['id'] as int?,
    name: map['name'] as String,
    age: map['age'] as int,
    weightKg: (map['weight_kg'] as num).toDouble(),
    heightCm: (map['height_cm'] as num).toDouble(),
  );
}

class WaterLog {
  final int? id;
  final String dateIso; // yyyy-MM-dd
  final int ml;

  WaterLog({this.id, required this.dateIso, required this.ml});

  Map<String, Object?> toMap() => {
    'id': id,
    'date_iso': dateIso,
    'ml': ml,
  };

  static WaterLog fromMap(Map<String, Object?> map) => WaterLog(
    id: map['id'] as int?,
    dateIso: map['date_iso'] as String,
    ml: map['ml'] as int,
  );
}

class FoodItem {
  final int? id;
  final String name;
  final int caloriesPer100g;

  FoodItem({this.id, required this.name, required this.caloriesPer100g});

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'calories_per_100g': caloriesPer100g,
  };

  static FoodItem fromMap(Map<String, Object?> map) => FoodItem(
    id: map['id'] as int?,
    name: map['name'] as String,
    caloriesPer100g: map['calories_per_100g'] as int,
  );
}

class Recipe {
  final int? id;
  final String title;
  final String description;

  Recipe({this.id, required this.title, required this.description});

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'description': description,
  };

  static Recipe fromMap(Map<String, Object?> map) => Recipe(
    id: map['id'] as int?,
    title: map['title'] as String,
    description: map['description'] as String,
  );
}
