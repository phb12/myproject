本次更新重點在於將 App 從「單機版」升級為具備完整「雲端同步」與「社群互動」能力的平台，同時大幅優化了使用者介面 (UI) 與資料結構。

1. 雲端架構整合 (Backend & Cloud)

    Firebase Auth 身份驗證：

        實作了 Email/Password 註冊與登入流程 (AuthService)。

        解決了本地 SQLite User 模型與 Firebase Auth User 類別的命名衝突 (hide User)。

        雙軌登入策略：登入成功後，自動檢查本地資料庫。若為新裝置登入，自動從雲端拉取個人資料並還原至本地 SQLite，實現無縫換機體驗。

    Cloud Firestore 資料庫：

        建立了 users 集合：同步儲存使用者個人資料 (暱稱、家鄉、生理數據)。

        建立了 posts 集合：儲存社群貼文，支援 Base64 圖片字串存儲 (作為免付費的 Storage 替代方案)。

        建立了 workout_logs / weight_logs 子集合：實作了訓練紀錄與體重紀錄的自動雲端備份。

2. 社群功能 (Community Features)

    介面重構 (Retro Style)：

        將社群首頁 (CommunityPage) 改版為黑色系 Retro 風格。

        實作了 置頂時間軸，動態顯示當前週數 (如「第 47 週」) 與本週日期卡片。

        加入了日期篩選功能：點擊上方日期，下方動態牆即時篩選該日貼文。

    發文功能：

        實作了 CreatePostPage，支援標題、內文輸入。

        圖片處理優化：整合 image_picker，並加入 maxWidth/maxHeight 強制壓縮邏輯，將圖片轉為 Base64 字串上傳，成功解決 Firestore 1MB 限制與 invalid-argument 錯誤。

    個人檔案與好友互動：

        建立了 CommunityProfilePage，整合個人資料編輯 (暱稱/家鄉) 與歷史貼文回顧。

        實作了 好友搜尋 (FriendSearchPage)：可透過 Email 或暱稱搜尋使用者。

        權限控制：點擊好友頭像可查看其個人頁面 (唯讀模式)，點擊自己頭像則可編輯資料。

3. 訓練與數據功能優化

    我的課表 (My Plan)：

        新增 「一鍵開始今日訓練」 功能：首頁卡片會自動偵測今日是否有課表，並顯示綠色開始按鈕。

        智慧排序：點擊特定動作開始訓練後，該動作會自動排至佇列首位，並過濾已完成項目。

        狀態標示：今日課表選單中，已完成的動作會顯示綠色勾勾與刪除線。

    體重追蹤：

        修正了體重圖表 (WeightTrendPage) X 軸標籤重疊問題，改為「固定時間窗口」邏輯。

        解決了單日重複紀錄問題，新增了 deleteWeightLogsForDate 邏輯確保資料唯一性。

        實作了首頁與個人資料頁的體重數據雙向同步。

4. 系統穩定性修復

    檔案鎖死問題：解決了 VS Code 在外接硬碟上開發導致的 Saving... 卡死與編譯錯誤，確認專案遷移至本地硬碟後運作正常。

    iOS 建置修復：透過修改 Podfile (加入 post_install 腳本移除 -G 旗標) 與手動連結 xcconfig，解決了 'Flutter/Flutter.h' not found 等頑固的 iOS 編譯錯誤。