import 'exercise_model.dart'; 

class CustomExercise {
  final int? id;
  final BodyPart bodyPart;
  final String name;
  final String? description;

  CustomExercise({
    this.id,
    required this.bodyPart,
    required this.name,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bodyPart': bodyPart.index,
      'name': name,
      'description': description,
    };
  }

  factory CustomExercise.fromMap(Map<String, dynamic> map) {
    return CustomExercise(
      id: map['id'],
      bodyPart: BodyPart.values[map['bodyPart']],
      name: map['name'],
      description: map['description'],
    );
  }
}
