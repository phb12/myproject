enum FitnessLevel { light, medium, heavy }

class User {
  final String? id; // Firestore Doc ID
  final String account;
  final String? password; // Firestore Auth handles this, but keeping for compatibility if needed
  final String height;
  final String weight;
  final String age;
  final String bmi;
  final String? fat;
  final String? gender;
  final String? bmr;
  final String? goalWeight;
  final String? fitnessLevel;
  final String? trainingDays; 

  final String? nickname;
  final String? hometown;

  User({
    this.id,
    required this.account,
    this.password,
    required this.height,
    required this.weight,
    required this.age,
    required this.bmi,
    this.fat,
    this.gender,
    this.bmr,
    this.goalWeight,
    this.fitnessLevel,
    this.trainingDays, 
    this.nickname, 
    this.hometown,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account': account,
      // 'password': password, // Usually don't save password in Firestore user doc
      'height': height,
      'weight': weight,
      'age': age,
      'bmi': bmi,
      'fat': fat,
      'gender': gender,
      'bmr': bmr,
      'goalWeight': goalWeight,
      'fitnessLevel': fitnessLevel,
      'trainingDays': trainingDays, 
      'nickname': nickname, 
      'hometown': hometown,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      account: map['account'] ?? '',
      password: map['password'],
      height: map['height'] ?? '0',
      weight: map['weight'] ?? '0',
      age: map['age'] ?? '0',
      bmi: map['bmi'] ?? '0',
      fat: map['fat'],
      gender: map['gender'],
      bmr: map['bmr'],
      goalWeight: map['goalWeight'],
      fitnessLevel: map['fitnessLevel'],
      trainingDays: map['trainingDays'], 
      nickname: map['nickname'], 
      hometown: map['hometown'],
    );
  }
}
