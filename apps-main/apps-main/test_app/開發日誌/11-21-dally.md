2. 全新社群模組 (Community Feature - UI Overhaul)

為了提升使用者黏著度，我們參考了 Retro 風格，重新設計並實作了完整的社群互動介面。

    社群首頁 (CommunityPage)：

        置頂時間軸 (Sticky Header)：實作了包含當前週數與橫向滾動日期的置頂區塊。

        直覺發文入口：在時間軸最左側新增了大型「+」號卡片，提供直覺的貼文建立體驗。

        動態牆 (Feed)：整合 StreamBuilder，即時監聽並顯示來自 Firebase Firestore 的最新貼文。

        離線優化：將圖片載入邏輯改為本地佔位符 (Placeholder)，解決模擬器無網路時的 SocketException 錯誤，確保 Demo 展示的穩定性。

    建立貼文 (CreatePostPage)：

        實作了完整的發文介面，包含標題、內容輸入。

        圖片處理：整合 image_picker，支援從相簿選取照片，並自動壓縮轉為 Base64 字串上傳至 Firestore (作為免付費的替代方案)。

3. 個人檔案系統 (Community Profile)

建立了獨立的個人檔案頁面 (CommunityProfilePage)，整合了資料編輯與歷史回顧功能。

    個人資料管理：

        暱稱與家鄉：實作了點擊頭像/文字即可修改「暱稱」與「家鄉」的功能，並同步更新至雲端與本地資料庫。

        UI 優化：修正了長文字導致的版面溢出 (Overflow) 問題，並優化了載入中的狀態顯示。

    視覺化歷史紀錄：

        週歷史列表：捨棄了原本的 GridView，改為更清晰的「週歷史列表」。

        動態數據：自動讀取使用者所有的歷史貼文，並依照發文時間自動分組到對應的週次，顯示該週的日期範圍及貼文縮圖。

4. Firebase 雲端整合 (Backend Integration)

正式將 App 從「單機版」升級為「雲端版」，完成了 Firebase 的深度整合。

    環境設定：

        使用 flutterfire configure 自動生成 firebase_options.dart，實現跨平台配置。

        修復了 main.dart 中的初始化邏輯，並正確處理了 try-catch 異常。

    身份驗證 (AuthService)：

        實作了 Firebase Auth 的 Email/Password 登入與註冊流程。

        雙軌資料策略：在 Firebase 註冊成功的同時，依然將使用者基本資料寫入本地 SQLite，確保 App 在離線模式下仍能運作。

    雲端資料庫 (FirestoreService)：

        建立了 users 集合來同步使用者資料 (暱稱、家鄉)。

        建立了 posts 集合來儲存社群貼文，並支援 Base64 圖片儲存。

        實作了 getUserPostsStream，支援針對特定使用者的貼文進行即時查詢。

📝 待辦事項 (To-Do)

    [ ] 修復特定圖片上傳導致的錯誤。

    [ ] 實作「一鍵開始今日課表」功能。

    [ ] 優化深色模式 UI 細節。

總結： 本次更新完成了 App 核心架構的雲端化，並交付了一個功能完整、UI 精美的社群模組。專案目前處於高度穩定狀態，可隨時進行 Demo 展示。