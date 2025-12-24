# 專題開發日誌 - 2025/07/16

**1. 核心導覽架構升級**

為了提升 App 的易用性和擴充性，我們廢除了舊有的頁面跳轉模式，引入了現代 App 主流的 BottomNavigationBar (底部導覽列) 作為新的核心導覽框架。

    建立 MainAppShell 框架：在 main.dart 中建立了一個全新的 StatefulWidget (MainAppShell)，作為使用者登入後的主活動框架，負責管理和切換所有主要頁面。

    定義五大核心分頁：

        首頁 (Dashboard)：建立了一個新的 dashboard_home_page.dart，為未來的個人化儀表板（如體重趨勢、運動摘要）預留了空間。

        開始訓練 (Start Training)：將現有的訓練流程 (select_part_page.dart) 無縫接入導覽列。

        日曆 (Calendar)：將 workout_history_page.dart 作為獨立的訓練紀錄查詢入口。

        建議課程 (Recommendations)：建立了 recommendations_page.dart 空白頁面，為後續的演算法推薦功能佈局。

        設定 (Settings)：整合了所有設定相關功能。

**2. BMR (基礎代謝率) 功能模組開發 (BMR Feature Module Development)**

為實現個人化建議的基礎，我們成功開發並整合了 BMR 的自動計算功能。

    演算法實作：基於 Mifflin-St Jeor 公式，建立了能根據性別、身高、體重、年齡自動計算 BMR 和 BMI 的核心邏輯。

    多場景整合：

        註冊頁面 (login_page.dart)：讓新使用者在註冊時即可建立完整的生理數據。

        個人資料頁 (profile_page.dart)：讓現有使用者可以隨時更新數據並查看結果。

    模型擴充：更新了 user_model.dart，加入了 gender 和 bmr 欄位，以支援新功能的資料持久化。

**3. 設定中心功能重構與強化 (Settings Hub Refactoring & Enhancement)**

將原有的單一設定頁面，重構為一個功能齊全、佈局清晰的「設定中心」。

    功能聚合：將「個人資料修改」、「連結裝置」、「匯出訓練紀錄」、「清除所有紀錄」以及「登出」等功能，全部整合到 settings_page.dart 中，並以群組化列表呈現。

    UI/UX 優化：採用了 Column + Spacer 佈局，將「登出」按鈕固定於頁面底部，並使用紅色字體以示區別，大幅提升了操作的直覺性和安全性。

    對話框整合：完整移植了原有的「登出確認」、「匯出選項」、「清除確認」等客製化對話框，確保了 App 風格的一致性。

4. 依賴管理與 API 修正 (Dependency Management & API Correction)

    share_plus 套件問題修復：為了解決「匯出紀錄」的功能，我們對 share_plus 套件進行了深入的除錯。最終透過版本降級 (11.0.0 -> 7.2.1) 和使用版本對應的正確 API (Share.shareXFiles)，成功修復了先前因版本不相容而導致的編譯錯誤。