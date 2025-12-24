import 'package:flutter/material.dart';
import 'dart:convert';
import 'services/firestore_service.dart';
import 'training_selection_dialog.dart'; // 確保這個檔案存在且路徑正確

// 訓練計畫項目的 Controller 類
class PlanControllers {
  TextEditingController actionCtrl;
  TextEditingController setsCtrl;

  PlanControllers({required String action, required String sets})
    : actionCtrl = TextEditingController(text: action),
      setsCtrl = TextEditingController(text: sets);

  void dispose() {
    actionCtrl.dispose();
    setsCtrl.dispose();
  }
}

class TrainingSchedulePage extends StatefulWidget {
  final String username;
  final String? currentUser; // 🚨 新增：當前操作用戶 (用於複製功能)
  final bool canEdit; // 🚨 新增：控制是否可編輯

  const TrainingSchedulePage({
    super.key,
    required this.username,
    this.currentUser,
    this.canEdit = true, // 預設為可編輯
  });

  @override
  State<TrainingSchedulePage> createState() => _TrainingSchedulePageState();
}

class _TrainingSchedulePageState extends State<TrainingSchedulePage> {
  // 保持 weekSchedule 數據結構不變 (初始值為空排程)
  List<Map<String, dynamic>> weekSchedule = [
    {"day": "週一", "title": "", "plans": <Map<String, dynamic>>[]},
    {"day": "週二", "title": "", "plans": <Map<String, dynamic>>[]},
    {"day": "週三", "title": "", "plans": <Map<String, dynamic>>[]},
    {"day": "週四", "title": "", "plans": <Map<String, dynamic>>[]},
    {"day": "週五", "title": "", "plans": <Map<String, dynamic>>[]},
    {"day": "週六", "title": "", "plans": <Map<String, dynamic>>[]},
    {"day": "週日", "title": "", "plans": <Map<String, dynamic>>[]},
  ];

  int _selectedDayIndex = 0;
  bool loading = true;
  String? error;
  bool _isEditing = false;

  // 統一管理標題和訓練計畫的 Controllers
  final List<TextEditingController> _titleCtrls = List.generate(
    7,
    (_) => TextEditingController(),
  );
  List<List<PlanControllers>> _planControllers = List.generate(7, (_) => []);

  // 🚨 修正：用於標題的 FocusNode 列表 (確保失焦時儲存)
  final List<FocusNode> _titleFocusNodes = List.generate(7, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = (DateTime.now().weekday - 1) % 7;
    fetchSchedule();

    // 監聽所有標題輸入框的焦點狀態
    for (int i = 0; i < 7; i++) {
      _titleFocusNodes[i].addListener(() {
        if (!_titleFocusNodes[i].hasFocus) {
          // 當輸入框失去焦點時，確保數據同步和儲存
          _syncTitleToSchedule(i);
          saveSchedule();
        }
      });
    }
  }

  // 輔助函數：將 Controller 的最新值寫回 weekSchedule
  void _syncTitleToSchedule(int index) {
    if (weekSchedule.length > index) {
      weekSchedule[index]['title'] = _titleCtrls[index].text.trim();
    }
  }

  @override
  void dispose() {
    for (final ctrl in _titleCtrls) {
      ctrl.dispose();
    }
    // 釋放 FocusNode
    for (final node in _titleFocusNodes) {
      node.dispose();
    }
    _disposePlanControllers();
    super.dispose();
  }

  // 輔助函式：釋放所有 PlanControllers
  void _disposePlanControllers() {
    for (final dayCtrls in _planControllers) {
      for (final ctrl in dayCtrls) {
        ctrl.dispose();
      }
    }
    _planControllers = List.generate(7, (_) => []); // 重置為空列表
  }

  // 輔助函式：重建並監聽 PlanControllers
  void _rebuildPlanControllers() {
    _disposePlanControllers(); // 先釋放舊的

    _planControllers = List.generate(weekSchedule.length, (dayIdx) {
      final plans = weekSchedule[dayIdx]['plans'] is List
          ? (weekSchedule[dayIdx]['plans'] as List)
                .whereType<Map<String, dynamic>>()
                .toList()
          : <Map<String, dynamic>>[];

      // 確保 weekSchedule 數據中的 plans 是正確的引用
      weekSchedule[dayIdx]['plans'] = plans;

      return plans.map((plan) {
        final ctrl = PlanControllers(
          action: plan['action'] ?? "",
          sets: plan['sets'] ?? "",
        );
        // 關鍵優化: 監聽器直接更新 weekSchedule 數據
        ctrl.actionCtrl.addListener(() {
          plan['action'] = ctrl.actionCtrl.text;
        });
        ctrl.setsCtrl.addListener(() {
          plan['sets'] = ctrl.setsCtrl.text;
        });
        return ctrl;
      }).toList();
    });
  }

  // 選擇動作對話框
  void _showExerciseSelector(int dayIdx) {
    showDialog(
      context: context,
      builder: (ctx) => TrainingSelectionDialog(
        currentDay: weekSchedule[dayIdx]['day'],
        onAddPlan: (actionName, sets) {
          addItem(dayIdx, actionName, sets);
        },
      ),
    );
  }

  // --- CRUD 操作與 API 連動 ---

  Future<void> fetchSchedule() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final decodedData = await FirestoreService.instance.getTrainingTemplate(widget.username);
      
      List rawSchedule = [];

      // 🚨 修正：FirestoreService 回傳 Map<String, dynamic>
      if (decodedData.containsKey('schedule') && decodedData['schedule'] is List) {
        rawSchedule = decodedData['schedule'];
      }

      // 1. 載入數據到 weekSchedule
      for (
        int i = 0;
        i < rawSchedule.length.clamp(0, weekSchedule.length);
        i++
      ) {
        weekSchedule[i] = Map<String, dynamic>.from(rawSchedule[i] as Map);

        // 確保 plans 是 List<Map> 且非 null
        if (weekSchedule[i]['plans'] == null ||
            weekSchedule[i]['plans'] is! List) {
          weekSchedule[i]['plans'] = <Map<String, dynamic>>[];
        } else {
          weekSchedule[i]['plans'] = (weekSchedule[i]['plans'] as List)
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p))
              .toList();
        }
        // 2. 更新標題控制器
        _titleCtrls[i].text = weekSchedule[i]['title'] ?? '';
      }

      // 3. 重建 Plan Controllers (關鍵優化點)
      _rebuildPlanControllers();

      setState(() {}); // 更新 UI
    } catch (e) {
      setState(() {
        error = "連線錯誤或資料解析失敗: $e";
        _rebuildPlanControllers();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> saveSchedule() async {
    // 🚨 關鍵優化：在儲存前，手動將當前選中日的標題同步 (如果用戶正在編輯但未失焦)
    // 這裡我們依賴 FocusNode Listener 或 onSubmitted 來處理同步，但為安全起見，這裡強制全部同步一次
    for (int i = 0; i < weekSchedule.length; i++) {
      weekSchedule[i]['title'] = _titleCtrls[i].text.trim();
    }

    try {
      await FirestoreService.instance.saveTrainingTemplate(widget.username, {
        "schedule": weekSchedule,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("儲存成功！")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("儲存失敗: $e")));
      }
    }
  }

  // 動作：新增項目
  void addItem(int dayIdx, String action, String sets) {
    setState(() {
      final newPlan = {'action': action, 'sets': sets};
      (weekSchedule[dayIdx]['plans'] as List).add(newPlan);

      // 僅新增該項目的 Controller，並設置監聽器
      final ctrl = PlanControllers(action: action, sets: sets);
      ctrl.actionCtrl.addListener(() {
        newPlan['action'] = ctrl.actionCtrl.text;
      });
      ctrl.setsCtrl.addListener(() {
        newPlan['sets'] = ctrl.setsCtrl.text;
      });
      _planControllers[dayIdx].add(ctrl);
    });
    saveSchedule();
  }

  // 動作：刪除項目
  void removeItem(int dayIdx, int planIdx) {
    setState(() {
      // 1. 釋放並移除 Controller
      if (planIdx >= 0 && planIdx < _planControllers[dayIdx].length) {
        _planControllers[dayIdx].removeAt(planIdx).dispose();
      }
      // 2. 移除數據
      (weekSchedule[dayIdx]['plans'] as List).removeAt(planIdx);
    });
    saveSchedule();
  }

  // 動作：拖曳排序
  void reorderItem(int dayIdx, int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;

      // 1. 排序數據
      final movedPlan = (weekSchedule[dayIdx]['plans'] as List).removeAt(
        oldIdx,
      );
      (weekSchedule[dayIdx]['plans'] as List).insert(newIdx, movedPlan);

      // 2. 排序 Controller
      final movedCtrl = _planControllers[dayIdx].removeAt(oldIdx);
      _planControllers[dayIdx].insert(newIdx, movedCtrl);
    });
    saveSchedule();
  }

  // 動作：複製到其他天
  void copyTo(int from, int to) {
    setState(() {
      // 1. 複製數據 (確保是深度複製)
      weekSchedule[to]['plans'] = List<Map<String, dynamic>>.from(
        (weekSchedule[from]['plans'] as List).map(
          (plan) => Map<String, dynamic>.from(plan),
        ),
      );
      weekSchedule[to]['title'] = _titleCtrls[from].text; // 複製標題
      _titleCtrls[to].text = weekSchedule[to]['title'] ?? '';

      // 2. 重建目標天的 Controller，以便監聽新的數據
      _rebuildPlanControllers();
    });
    saveSchedule();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("已複製到${weekSchedule[to]['day']}")));
  }

  // 動作：分享給好友
  void shareToFriend() async {
    final userCtrl = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("分享給好友", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: userCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "好友帳號",
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white38),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyanAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("送出", style: TextStyle(color: Colors.cyanAccent)),
            onPressed: () => Navigator.pop(context, userCtrl.text.trim()),
          ),
        ],
      ),
    );
    if (confirmed != null && confirmed.isNotEmpty) {
      try {
        await FirestoreService.instance.shareSchedule(widget.username, confirmed);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("已分享給 $confirmed")));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("分享失敗: $e")));
      }
    }
  }

  // --- 訓練內容顯示區 (UI 優化) ---

  Widget _buildDayDetail(int i) {
    final currentDay = weekSchedule[i];
    final planList = currentDay['plans'] as List;
    final todayIdx = (DateTime.now().weekday - 1) % 7;

    // 輔助函式：顯示刪除確認對話框
    Future<void> confirmDelete(
      BuildContext context,
      int dayIdx,
      int planIdx,
      String actionName,
    ) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("確認刪除", style: TextStyle(color: Colors.white)),
          content: Text(
            "確定要刪除「$actionName」這個動作嗎？",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("取消", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text("刪除", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        removeItem(dayIdx, planIdx);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("已刪除 $actionName")));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 標題顯示與編輯
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentDay['day'] + (i == todayIdx ? " (今日)" : ""),
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.content_copy, color: Colors.white70),
                  tooltip: "複製此天課表",
                  onPressed: () async {
                    final copyToIdx = await showDialog<int>(
                      context: context,
                      builder: (ctx2) => SimpleDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text(
                          '複製到哪一天？',
                          style: TextStyle(color: Colors.white),
                        ),
                        children: [
                          for (int d = 0; d < 7; d++)
                            if (d != i)
                              SimpleDialogOption(
                                child: Text(
                                  weekSchedule[d]['day'],
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                onPressed: () => Navigator.pop(ctx2, d),
                              ),
                        ],
                      ),
                    );
                    if (copyToIdx != null) copyTo(i, copyToIdx);
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. 標題編輯 TextField
          TextField(
            controller: _titleCtrls[i],
            // 🚨 綁定 FocusNode
            focusNode: _titleFocusNodes[i],
            enabled: _isEditing,
            decoration: InputDecoration(
              hintText: "點擊編輯本日標題 / 訓練部位",
              filled: true,
              fillColor: _isEditing
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              border: _isEditing
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    )
                  : InputBorder.none,
              hintStyle: const TextStyle(color: Colors.white38),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            onSubmitted: (txt) {
              // 🚨 onSubmitted 時，強制同步並儲存 (確保 Enter 鍵生效)
              _syncTitleToSchedule(i);
              saveSchedule();
            },
            onChanged: (txt) {
              // 實時更新 Controller 值
            },
          ),

          const SizedBox(height: 24),

          // 3. 動作拖曳列表
          Text(
            '訓練項目 (${planList.length})',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: planList.length,
            onReorder: _isEditing
                ? (oldIdx, newIdx) => reorderItem(i, oldIdx, newIdx)
                : (oldIdx, newIdx) {
                    /* 靜默處理，不允許非編輯模式下拖曳 */
                  },

            itemBuilder: (context, planIdx) {
              final planCtrlSet = _planControllers[i][planIdx];
              final actionName = planCtrlSet.actionCtrl.text;

              return Container(
                key: ValueKey('day${i}item$planIdx'),
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: _isEditing
                      ? Border.all(color: Colors.white.withValues(alpha: 0.2))
                      : Border.all(color: Colors.transparent),
                ),
                child: ListTile(
                  // 💡 UX優化：拖曳手柄只在編輯模式下顯示
                  leading: _isEditing
                      ? ReorderableDragStartListener(
                          index: planIdx,
                          child: const Icon(
                            Icons.drag_indicator,
                            color: Colors.white38,
                          ),
                        )
                      : const Icon(
                          Icons.fitness_center,
                          color: Colors.cyanAccent,
                        ),

                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),

                  title: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: planCtrlSet.actionCtrl,
                          enabled: _isEditing,
                          decoration: const InputDecoration(
                            labelText: "動作",
                            border: InputBorder.none,
                            isDense: true,
                            labelStyle: TextStyle(color: Colors.white38),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                          onSubmitted: (val) => saveSchedule(), // 提交儲存
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: planCtrlSet.setsCtrl,
                          enabled: _isEditing,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "組數",
                            border: InputBorder.none,
                            isDense: true,
                            labelStyle: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          onSubmitted: (val) => saveSchedule(), // 提交儲存
                        ),
                      ),
                    ],
                  ),

                  trailing: _isEditing
                      ? IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 24,
                          ),
                          onPressed: () =>
                              confirmDelete(context, i, planIdx, actionName),
                          tooltip: "刪除動作",
                        )
                      : null,
                ),
              );
            },
          ),

          // 4. 新增動作按鈕 (動作選擇器)
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 40),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.cyanAccent,
                  ),
                  label: const Text(
                    '從動作清單新增動作',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.cyanAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showExerciseSelector(i),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🚨 新增：複製到我的課表
  Future<void> copyToMySchedule(int dayIdx) async {
    if (widget.currentUser == null) return;

    final targetDayIdx = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('複製到我的哪一天？', style: TextStyle(color: Colors.white)),
        children: [
          for (int d = 0; d < 7; d++)
            SimpleDialogOption(
              child: Text(
                weekSchedule[d]['day'], // 這裡顯示的是來源的 day 名稱，通常是一樣的
                style: const TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.pop(ctx, d),
            ),
        ],
      ),
    );

    if (targetDayIdx != null) {
      try {
        await FirestoreService.instance.copyScheduleDay(
          widget.username,
          widget.currentUser!,
          dayIdx,
          targetDayIdx,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("已複製到你的課表！")));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("錯誤: $e")));
      }
    }
  }

  // --- UI 主體結構 ---
  @override
  Widget build(BuildContext context) {
    DateTime today = DateTime.now();
    int todayIdx = (today.weekday - 1) % 7;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.canEdit ? '我的一週訓練課表' : '${widget.username} 的課表',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchSchedule,
            tooltip: "重新載入",
            color: Colors.cyanAccent,
          ),
          // 🚨 如果是檢視模式 (看別人課表)，顯示複製按鈕
          if (!widget.canEdit && widget.currentUser != null)
            IconButton(
              icon: const Icon(Icons.download), // 使用下載圖標表示匯入/複製
              onPressed: () => copyToMySchedule(_selectedDayIndex),
              tooltip: "複製此日課表給我",
              color: Colors.cyanAccent,
            ),
          if (widget.canEdit) ...[
            IconButton(
              icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
              color: _isEditing ? Colors.redAccent : Colors.cyanAccent,
              tooltip: _isEditing ? "切換至檢視模式" : "切換至編輯模式",
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                  // 💡 優化：在切換到檢視模式時，觸發一次儲存，確保所有輸入欄位的值都同步到後端
                  if (!_isEditing) {
                    saveSchedule();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: shareToFriend,
              tooltip: "分享課表",
              color: Colors.cyanAccent,
            ),
          ],
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            )
          : error != null
          ? Center(
              child: Text(
                "❌ 載入錯誤：$error",
                style: const TextStyle(color: Colors.redAccent, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            )
          : Row(
              children: [
                // A. 左側：固定導航欄 (天數選擇)
                Container(
                  width: 120,
                  color: Colors.black, // Transparent/Black background
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    itemCount: weekSchedule.length,
                    itemBuilder: (context, i) {
                      final isSelected = i == _selectedDayIndex;
                      final isToday = i == todayIdx;
                      return GestureDetector(
                        onTap: () {
                          // 🚨 修正：切換天數前，強制儲存當前天的標題
                          _syncTitleToSchedule(_selectedDayIndex);
                          saveSchedule();

                          setState(() {
                            _selectedDayIndex = i;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.cyanAccent.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? Border.all(color: Colors.cyanAccent, width: 1)
                                : null,
                          ),
                          child: Column(
                            children: [
                              Text(
                                weekSchedule[i]['day'],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.cyanAccent
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (isToday)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(
                                    Icons.circle,
                                    color: Colors.cyanAccent,
                                    size: 8,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // B. 右側：訓練內容顯示區
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(
                      top: 10,
                      right: 10,
                      bottom: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SingleChildScrollView(
                        child: _buildDayDetail(_selectedDayIndex),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
