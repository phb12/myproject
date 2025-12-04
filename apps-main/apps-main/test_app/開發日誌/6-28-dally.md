# 專題開發日誌 - 2025/06/28

## 今日進度總結

今天我們完成了兩項重大的里程碑。我們不僅將 App 的**使用者介面 (UI) 徹底改造成專業的深色模式**，還為專案的最終目標——硬體整合，打下了最重要的基礎：我們成功地**建立了藍牙功能的軟體架構，並實作了模擬掃描與連線的介面**。


---

## 專業的技術總結

### 1. 全域主題 (`ThemeData`) 的深度客製化
（內容與之前相同，總結了深色模式、元件風格統一、UI 迭代的成果）

### 2. 靜態資源 (Assets) 的引入與使用
（內容與之前相同，總結了 `pubspec.yaml` 設定和 `Image.asset` 的使用）

### 3. 進階 UI 與 UX 優化
（內容與之前相同，總結了 `AlertDialog` 和環境除錯的經驗）

### 4. 藍牙功能模擬 (Bluetooth Mocking)

為了在沒有真實硬體的情況下，也能順利開發藍牙連線的介面，我們採用了「模擬開發」的策略。

* **建立藍牙服務 (`BluetoothService`)**：我們在 `services` 資料夾中，建立了一個 `bluetooth_service.dart` 檔案。這個類別未來將封裝所有與 `flutter_blue_plus` 套件的互動，讓 UI 層與底層藍牙邏輯徹底解耦。
* **使用 `StreamController`**：我們利用 `StreamController` 來建立事件廣播。`BluetoothService` 可以將「掃描狀態」或「掃描到的裝置列表」等即時變化的資料，透過 `Stream` 傳送出去。
* **響應式 UI (`StreamBuilder`)**：在 `device_connection_page.dart` 中，我們使用 `StreamBuilder` 來「訂閱」`BluetoothService` 提供的 `Stream`。這讓我們的 UI 介面可以自動地、響應式地根據藍牙掃描的狀態（例如：從「掃描中」變成「掃描完成」）來更新畫面，而不需要手動管理。
* **模擬資料 (`MockBluetoothDevice`)**：我們建立了一個 `MockBluetoothDevice` 類別，並在 `BluetoothService` 中實作了產生假裝置列表的邏輯，這讓我們可以在沒有硬體的情況下，也能完整地測試 UI 的顯示與互動。

---

## 更新後的專案結構

我們今天新增了藍牙相關的服務與頁面。


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
│   ├── main_menu_page.dart     # (有修改) 改造了版面佈局與登出按鈕
│   ├── select_part_page.dart   # (有修改) 改造了版面佈局與圖示顯示
│   ├── profile_page.dart       # (有修改) 統一了輸入框樣式
│   └── settings_page.dart      # (有修改) 改造了選項樣式
│   ├── device_connection_page.dart # ⭐ (新) 藍牙裝置連線頁面
│   └── ... (其餘頁面未變動)
|
└── services/             # 【後勤部門/工具箱】資料夾
├── database_helper.dart      #
├── mock_data_service.dart    #
└── bluetooth_service.dart    # ⭐ (新) 處理所有藍牙邏輯的服務


---

## 下一步規劃

App 的軟體部分已經非常完善且美觀了！我們的地基和裝潢都已經完成。

接下來，我們終於可以正式地來挑戰這個專案最核心、也最有趣的大魔王了：

**「將藍牙服務從模擬模式切換為真實模式，並嘗試用 App 掃描到真實世界中的藍牙裝置。」**

