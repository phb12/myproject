// 定義訓練動作資料類別，包含名稱、說明、圖片路徑等屬性。


enum BodyPart {
  chest,
  legs,
  abs,
  shoulders,
  biceps,
  triceps,
  back,
}

// BodyPart 的擴充方法，用來取得顯示名稱和圖片路徑
extension BodyPartExtension on BodyPart {
  String get displayName {
    switch (this) {
      case BodyPart.chest: return '胸';
      case BodyPart.legs: return '腿';
      case BodyPart.abs: return '腹';
      case BodyPart.shoulders: return '肩';
      case BodyPart.biceps: return '二頭肌';
      case BodyPart.triceps: return '三頭肌';
      case BodyPart.back: return '背';
    }
  }

  String get imagePath {
    switch (this) {
      case BodyPart.chest: return 'image/icon/胸.png';
      case BodyPart.legs: return 'image/icon/腿.png';
      case BodyPart.abs: return 'image/icon/腹.png';
      case BodyPart.shoulders: return 'image/icon/肩.png';
      case BodyPart.biceps: return 'image/icon/二頭.png';
      case BodyPart.triceps: return 'image/icon/三頭.png';
      case BodyPart.back: return 'image/icon/背.png';
    }
  }
}


class Exercise {
  final String name;
  final String? description;
  final String? imagePath;

  const Exercise({
    required this.name,
    this.description,
    this.imagePath,
  });
}
