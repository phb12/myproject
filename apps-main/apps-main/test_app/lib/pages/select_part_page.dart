// 訓練部位選擇頁面，呈現可選肌群。

import 'package:flutter/material.dart';
import '../models/exercise_model.dart';
import './select_exercise_page.dart';

class SelectPartPage extends StatelessWidget {
  const SelectPartPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 我們可以手動定義要顯示的部位順序
    final bodyParts = [
      BodyPart.chest,
      BodyPart.back,
      BodyPart.shoulders,
      BodyPart.legs,
      BodyPart.biceps,
      BodyPart.triceps,
      BodyPart.abs,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇訓練部位'),
      ),
      // --- 【還原】我們將 GridView.builder 改回 ListView.builder ---
      body: ListView.builder(
        // 我們可以為整個列表加上一些垂直的邊距
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: bodyParts.length,
        itemBuilder: (context, index) {
          final part = bodyParts[index];
          // 直接回傳我們之前設計好的列表項目卡片樣式
          return _buildPartListItem(context, part);
        },
      ),
    );
  }

  // --- 我們使用回之前設計的「橫幅列表」Helper 方法 ---
  Widget _buildPartListItem(BuildContext context, BodyPart part) {
    return Padding(
      // 為每個列表項目卡片，加上水平方向的邊距
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Card(
        // `clipBehavior` 可以防止 InkWell 的水波紋效果超出卡片的圓角範圍
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectExercisePage(bodyPart: part),
              ),
            );
          },
          // --- 我們使用 ListTile 來輕鬆實現「左圖中文字右箭頭」的經典佈局 ---
          child: ListTile(
            // `contentPadding` 可以調整 ListTile 內部的邊距
            contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            // `leading` 是顯示在標題最左側的元件
            leading: Image.asset(
              part.imagePath,
              width: 40,
              height: 40,
            ),
            // `title` 是列表項目的主標題
            title: Text(
              part.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            // `trailing` 是顯示在項目最右側的元件
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ),
      ),
    );
  }
}
