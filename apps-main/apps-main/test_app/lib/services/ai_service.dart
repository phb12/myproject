// lib/services/ai_service.dart

import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/plan_item_model.dart';

class AIService {
  // 使用您測試成功的 Key
  static const String _apiKey = 'AIzaSyA64V7FGGFEmUHGeZif_WLZMb9DN4BLR7Q';

  late final GenerativeModel _model;

  AIService() {
    _model = GenerativeModel(
      // 使用您測試成功的模型版本
      model: 'gemini-2.5-flash', // 或是您測試成功的 'gemini-2.5-flash'
      apiKey: _apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  // 【修改】接收 availableExercises 參數
  Future<List<PlanItem>> generateWorkoutPlan(User user, List<String> availableExercises) async {
    final String exercisesListString = availableExercises.join(', ');

    final prompt = '''
      你是一位專業健身教練。請根據以下使用者資料，設計一週的訓練課表。
      
      【使用者資料】
      - 性別: ${user.gender ?? '未知'}
      - 年齡: ${user.age}
      - 身高: ${user.height} cm
      - 體重: ${user.weight} kg
      - 健身強度: ${user.fitnessLevel ?? '中等'}
      - 目標: 增肌減脂
      
      【可用動作資料庫】(請嚴格遵守，只從這裡選擇動作，不可創造新名稱)
      $exercisesListString
      
      【要求】
      1. 請安排 3-5 天的訓練日。休息日請不要回傳任何資料。
      2. 動作名稱必須完全匹配【可用動作資料庫】中的名稱。
      3. 重量建議：請根據使用者的體重 (${user.weight}kg) 和性別，估算適合的起始訓練重量(kg)。例如：深蹲通常可從體重的 0.5 倍開始；如果是自重訓練(如伏地挺身)填 "0"。
      4. 回傳純粹的 JSON Array。
      
      【JSON 範例】
      [{"dayOfWeek": 1, "exerciseName": "槓鈴深蹲", "sets": "4", "weight": "30"}]
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      if (response.text == null) return [];

      // 清理 Markdown
      String jsonText = response.text!
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> jsonList = jsonDecode(jsonText);
      List<PlanItem> plans = [];
      for (var item in jsonList) {
        plans.add(PlanItem(
          dayOfWeek: item['dayOfWeek'],
          exerciseName: item['exerciseName'],
          sets: item['sets'].toString(),
          weight: item['weight'].toString(),
        ));
      }
      return plans;
    } catch (e) {
      print('AI 生成失敗: $e');
      return [];
    }
  }

  // 保留您的除錯方法
  Future<void> listAvailableModels() async {
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        print(response.body);
      }
    } catch (e) {
      print('列出模型失敗: $e');
    }
  }
}