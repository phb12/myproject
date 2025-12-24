# 專題開發日誌 - 2025/06/27

## 今日進度總結

今天我們將重心完全放在了**使用者介面 (UI) 與使用者體驗 (UX) 的全面美化與升級**上。我們根據 iOS 的設計風格，將 App 從原本的淺色模式，徹底改造成一個專業、有質感的**深色模式**。過程中，我們反覆地調整與迭代了多個核心頁面的視覺細節，並成功地整合了客製化的圖示資源，讓 App 的整體風格煥然一新。

---


---

## 專業的技術總結

### 1. 全域主題 (`ThemeData`) 的深度客製化

我們今天的工作，核心都圍繞在 `main.dart` 中的 `ThemeData`。

* **深色模式 (Dark Mode)**：我們透過設定 `brightness: Brightness.dark` 和提供深色的 `scaffoldBackgroundColor` 與 `colorScheme`，成功地將 App 切換為深色主題。
* **元件風格統一**：我們精細地調整了 `inputDecorationTheme` (輸入框)、`elevatedButtonTheme` (按鈕)、`cardTheme` (卡片) 等多個元件的全域樣式，確保了 App 整體視覺的一致性與專業度。
* **輸入框樣式迭代**：我們嘗試了 `floatingLabelBehavior`、`contentPadding` 等多種方式，最終為不同的頁面（登入頁 vs. 個人資料頁）選擇了最合適的標籤顯示方案，兼顧了美觀與實用性。

### 2. 靜態資源 (Assets) 的引入與使用

* **`pubspec.yaml` 設定**：我們學會了如何在 `pubspec.yaml` 中，透過 `assets:` 區塊來正確地註冊圖片資源資料夾。
* **`Image.asset`**：我們修改了 `exercise_model.dart` 和 `select_part_page.dart`，將原本使用 `Icon` 元件的地方，改為使用 `Image.asset` 來載入並顯示我們專案中的本地圖片檔案。

### 3. 進階 UI 與 UX 優化

* **對話框 (`AlertDialog`)**：為了防止使用者誤觸登出，我們使用 `showDialog` 函式和 `AlertDialog` 元件，實作了一個功能完整的「確認對話框」。
* **佈局迭代**：我們根據在模擬器上的實際視覺效果，反覆調整了 `select_part_page.dart` 的佈局，從 `GridView` -> `ListView` -> 再回到最終版的 `GridView`，並透過調整 `childAspectRatio` 來達到最理想的視覺平衡。

---

## 專案結構圖（維持不變）

今天我們主要專注在修改現有檔案的內容，並沒有新增或刪除檔案，所以專案的整體結構保持不變。


lib/
├── main.dart             # (有修改) App 總入口，定義了全新的深色主題
|
├── models/               # 【藍圖/規格表】資料夾
│   ├── exercise_model.dart     # (有修改) 將 IconData 改為圖片路徑 String
│   ├── workout_log_model.dart  #
│   └── user_model.dart         #
|
├── pages/                # 【展示廳】資料夾 (所有 UI 頁面)
│   ├── login_page.dart         # (有修改) 統一了輸入框樣式
│   ├── main_menu_page.dart     # (有修改) 改造了登出按鈕並加入確認對話框
│   ├── select_part_page.dart   # (有修改) 改造了版面佈局與圖示顯示
│   ├── profile_page.dart       # (有修改) 實作了常駐標題輸入框
│   └── settings_page.dart      # (有修改) 改造了選項樣式
│   ├── ... (其餘頁面未變動)
|
└── services/             # 【後勤部門/工具箱】資料夾
├── database_helper.dart      #
└── mock_data_service.dart    #


---

## 下一步規劃

App 的軟體部分已經非常完善且美觀了！我們的地基和裝潢都已經完成。

接下來，我們終於可以正式地來挑戰這個專案最核心、也最有趣的大魔王了：

**「開始實作藍牙連線的功能，用真實的感測器數據，來取代我們目前的假資料。」**

