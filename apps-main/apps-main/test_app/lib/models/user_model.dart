// 定義「使用者」的資料結構

// lib/models/user_model.dart

enum FitnessLevel { light, medium, heavy }

class User {
  final int? id;
  final String account;
  final String password;
  final String height;
  final String weight;
  final String age;
  final String bmi;
  final String? fat;
  final String? gender;
  final String? bmr;
  final String? goalWeight;
  final String? fitnessLevel;
  final String? trainingDays; // 【新增】儲存練習日 

  final String? nickname;
  final String? hometown;

  User({
    this.id,
    required this.account,
    required this.password,
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
      'password': password,
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
      account: map['account'],
      password: map['password'],
      height: map['height'],
      weight: map['weight'],
      age: map['age'],
      bmi: map['bmi'],
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

  User copyWith({
    int? id,
    String? account,
    String? password,
    String? height,
    String? weight,
    String? age,
    String? bmi,
    String? fat,
    String? gender,
    String? bmr,
    String? goalWeight,
    String? fitnessLevel,
    String? trainingDays, 
    String? nickname, 
    String? hometown,
  }) {
    return User(
      id: id ?? this.id,
      account: account ?? this.account,
      password: password ?? this.password,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      age: age ?? this.age,
      bmi: bmi ?? this.bmi,
      fat: fat ?? this.fat,
      gender: gender ?? this.gender,
      bmr: bmr ?? this.bmr,
      goalWeight: goalWeight ?? this.goalWeight,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      trainingDays: trainingDays ?? this.trainingDays, // 
      nickname: nickname ?? this.nickname, 
      hometown: hometown ?? this.hometown,
    );
  }
}