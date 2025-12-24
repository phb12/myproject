// 定義「使用者」的資料結構

// lib/models/user_model.dart

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
  final String? trainingDays; // 【新增】儲存練習日 

  final String? nickname;
  final String? hometown;
  final String? photoUrl; // 【新增】大頭貼 Base64

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
    this.trainingDays, 
    this.nickname, 
    this.hometown,
    this.photoUrl,
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
      'trainingDays': trainingDays, 
      'nickname': nickname, 
      'hometown': hometown,
      'photoUrl': photoUrl,
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
      trainingDays: map['trainingDays'], 
      nickname: map['nickname'], 
      hometown: map['hometown'],
      photoUrl: map['photoUrl'],
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
    String? trainingDays, 
    String? nickname, 
    String? hometown,
    String? photoUrl,
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
      trainingDays: trainingDays ?? this.trainingDays,
      nickname: nickname ?? this.nickname, 
      hometown: hometown ?? this.hometown,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}