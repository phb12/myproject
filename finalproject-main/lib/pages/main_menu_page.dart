// 登入後主選單與底部導航，用於核心頁面跳轉。

import 'package:flutter/material.dart';
import './select_part_page.dart';
import './workout_history_page.dart';
import './settings_page.dart';
import './profile_page.dart';
import './login_page.dart';
import './device_connection_page.dart';

class MainMenuPage extends StatelessWidget {
  final String account;
  const MainMenuPage({super.key, required this.account});
  
  @override
  Widget build(BuildContext context) {
    // 【還原】我們將 body 從 ListView 改回 Padding + Column 的佈局
    // 這樣我們才能使用 Spacer 將登出按鈕推到最底下
    return Scaffold(
      appBar: AppBar(title: const Text('主選單')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          children: [
            // --- 第一個群組 ---
            _buildMenuGroup(
              children: [
                _buildMenuItem(
                  context: context,
                  imagePath: 'image/page_icon/開始訓練.png',
                  title: '開始訓練',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SelectPartPage()));
                  },
                ),
                _buildMenuItem(
                  context: context,
                  imagePath: 'image/page_icon/紀錄.png',
                  title: '訓練紀錄',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => WorkoutHistoryPage(account: account)));
  
                  },
                ),
                 _buildMenuItem(
                  context: context,
                  imagePath: 'image/page_icon/藍牙.png',
                  title: '連接裝置',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DeviceConnectionPage()));
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- 第二個群組 ---
            _buildMenuGroup(
              children: [
                _buildMenuItem(
                  context: context,
                  imagePath: 'image/page_icon/個人資料.png',
                  title: '個人資料修改',
                  onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage(account: account)));
                  },
                ),
                _buildMenuItem(
                  context: context,
                  imagePath: 'image/page_icon/設定.png',
                  title: '詳細設定',
                  onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage(account: account)));
                  },
                ),
              ],
            ),
            
            // Spacer 會佔用所有剩餘的空間，把登出按鈕推到畫面最底下
            const Spacer(), 
            
            // --- 【還原】獨立的登出按鈕 ---
            const Divider(),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: () {
                // 【不變】我們保留這個最專業的對話框樣式
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      titlePadding: EdgeInsets.zero,
                      contentPadding: EdgeInsets.zero,
                      actionsPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      content: SizedBox(
                        width: 270,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Text(
                                '是否確認登出？',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Divider(height: 1, color: Colors.grey.shade700),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: TextButton(
                                child: Text(
                                  '登出',
                                  style: TextStyle(
                                    color: Colors.red.shade400,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (context) => const LoginPage()),
                                    (Route<dynamic> route) => false,
                                  );
                                },
                              ),
                            ),
                            Divider(height: 1, color: Colors.grey.shade700),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: TextButton(
                                child: Text(
                                  '稍後再說',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 17,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  '登出',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Helper 方法：用來建立一個帶有圓角背景的「選項群組」
  Widget _buildMenuGroup({required List<Widget> children}) {
    return Card(
      // 我們只在這裡，為選項群組的 Card 設定你指定的背景顏色
      color: const Color(0xFF2C2C2E), // 使用一個比主背景亮的深灰色
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  // Helper 方法：用來建立一個「圖示 + 文字 + 箭頭」的列表項目
  Widget _buildMenuItem({
    required BuildContext context,
    required String imagePath,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Image.asset(
        imagePath,
        width: 28,
        height: 28,
        // 我們讓圖示本身是白色的，這樣在深色背景上才看得清楚
        color: Colors.white,
      ),
      title: Text(
        title,
        // 【顏色修正】將文字顏色設為白色
        style: const TextStyle(color: Colors.white),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
      onTap: onTap,
    );
  }
}
