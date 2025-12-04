1. 生理數據監控 (Health Monitoring)

為了提供更全面的健康數據整合，我們串接了 iOS 的 HealthKit 框架：

    HealthKit 整合：

        實作了 HealthService，負責處理權限請求與數據讀取。

        在 Info.plist 與 Xcode Capability 中正確設定了隱私權限。

    即時心率監控：

        將原本的「藍牙連線頁面」改造為「健康數據中心」。

        實作了即時心率讀取功能，支援與 Apple Watch 同步，並在介面上動態顯示 BPM (每分鐘心跳數)。

2. 訓練流程擴充 (Training Workflow Expansion)

為未來的 AI 功能鋪路，我們重新設計了訓練前的選擇流程：

    訓練模式選擇頁 (TrainingModeSelectionPage)：

        在選擇動作後，新增了一個中間頁面，讓使用者選擇訓練方式：

            即時動作辨識 (OpenPose 預留入口)。

            影片錄製分析 (影像上傳預留入口)。

            直接開始訓練 (原本的手動紀錄流程)。

        優化了 SelectExercisePage 的導航邏輯，確保流程順暢。

3. 專案結構優化 (Refactoring)

為了保持專案的整潔與可維護性，我們進行了大規模的檔案清理：

    移除冗餘檔案：

        刪除了已棄用的 post_page.dart (舊發文頁) 與 recommendations_page.dart (舊建議頁)。

        確認了 main_menu_page.dart 等舊有檔案不再被引用，確保專案結構清晰。

4. 系統穩定性提升

    資料一致性：

        修正了「體重紀錄」的重複問題，透過在 DatabaseHelper 中新增 deleteWeightLogsForDate 方法，確保同一天只會保留最後一筆更新的體重數據。

        解決了首頁與設定頁之間的資料同步問題，確保使用者修改資料後，所有頁面都能即時反映最新狀態。

🚀 下一步計畫：熱量追蹤 (Calories Tracking)

目前的 App 已經能很好地管理「輸出」(訓練)，接下來我們要補上「輸入」(飲食) 的部分，達成完整的健康閉環。

預計開發功能：

    TDEE/BMR 計算升級：根據使用者資料，更精確地計算每日建議熱量攝取。

    飲食紀錄功能：讓使用者能簡單記錄早、午、晚餐的熱量。

    熱量儀表板：在首頁或新分頁顯示「攝取 vs. 消耗」的對比圖表。





