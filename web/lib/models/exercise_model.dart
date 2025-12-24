enum BodyPart {
  chest,
  back,
  legs,
  shoulders,
  arms,
  core,
  cardio,
  fullBody,
  other
}

class Exercise {
  final String name;
  final BodyPart bodyPart;

  Exercise({required this.name, required this.bodyPart});
}
