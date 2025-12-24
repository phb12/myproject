// lib/pages/plan_editor_page.dart

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/database_helper.dart';
import '../models/plan_item_model.dart';
import '../models/exercise_model.dart';
import '../models/custom_exercise.dart';
import '../services/mock_data_service.dart';


class PlanEditorPage extends StatefulWidget {
  final String account;
  const PlanEditorPage({super.key, required this.account});

  @override
  State<PlanEditorPage> createState() => _PlanEditorPageState();
}

class _PlanEditorPageState extends State<PlanEditorPage> {
  User? _currentUser;
  final Map<int, bool> _daysSelected = { 1: false, 2: false, 3: false, 4: false, 5: false, 6: false, 7: false };
  final Map<int, List<PlanItem>> _planItems = {};
  
  final List<String> _dayNames = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final user = await DatabaseHelper.instance.getUserByAccount(widget.account);
    if (!mounted) return;

    setState(() {
      _currentUser = user;
      // 重置所有勾選狀態
      for(int i=1; i<=7; i++) _daysSelected[i] = false;

      if (user?.trainingDays != null && user!.trainingDays!.isNotEmpty) {
        final days = user.trainingDays!.split(',');
        for (var dayString in days) {
          final dayInt = int.tryParse(dayString);
          if (dayInt != null && _daysSelected.containsKey(dayInt)) {
            _daysSelected[dayInt] = true;
          }
        }
      }
    });
    _loadAllPlanItems();
  }
  
  Future<void> _loadAllPlanItems() async {
    // 清空舊資料
    _planItems.clear();
    
    for (int i = 1; i <= 7; i++) {
      final items = await DatabaseHelper.instance.getPlanItemsForDay(i);
      if (mounted) {
        setState(() {
          _planItems[i] = items;
        });
      }
    }
  }

  Future<void> _saveTrainingDays() async {
    if (_currentUser == null) return;
    
    final selectedDays = _daysSelected.entries.where((e) => e.value).map((e) => e.key.toString());
    final trainingDaysString = selectedDays.join(',');

    final updatedUser = _currentUser!.copyWith(trainingDays: trainingDaysString);
    await DatabaseHelper.instance.updateUser(updatedUser);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('練習日已儲存！')));
    Navigator.of(context).pop(true);
  }

  // 【新增】一鍵清除所有課表
  Future<void> _clearAllPlans() async {
    if (_currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認清除'),
        content: const Text('確定要刪除所有已安排的課表動作，並重置練習日嗎？此操作無法復原。'),
        actions: [
          TextButton(child: const Text('取消'), onPressed: () => Navigator.pop(ctx, false)),
          TextButton(
            child: const Text('全部清除', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 1. 刪除所有 plan_items (我們需要在 DatabaseHelper 加這個方法，或是一個一個刪)
    // 暫時解法：遍歷所有 planItems 刪除 (效率稍差但不用改 DatabaseHelper)
    // 更好的解法：在 DatabaseHelper 加 deleteAllPlanItems()
    // 這裡我們先用遍歷刪除，確保安全
    for (var dayItems in _planItems.values) {
      for (var item in dayItems) {
        if (item.id != null) {
          await DatabaseHelper.instance.deletePlanItem(item.id!);
        }
      }
    }

    // 2. 重置練習日
    final updatedUser = _currentUser!.copyWith(trainingDays: '');
    await DatabaseHelper.instance.updateUser(updatedUser);

    // 3. 刷新 UI
    if (mounted) {
      setState(() {
        for(int i=1; i<=7; i++) _daysSelected[i] = false;
        _planItems.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有課表已清除')),
      );
    }
  }


  
  Future<void> _showAddExerciseDialog(int dayOfWeek) async {
    final result = await showDialog<PlanItem>(
      context: context,
      builder: (context) => _AddExerciseDialog(dayOfWeek: dayOfWeek),
    );

    if (result != null && mounted) {
      await DatabaseHelper.instance.insertPlanItem(result);
      _loadAllPlanItems();
    }
  }

  Future<void> _deletePlanItem(int itemId) async {
    await DatabaseHelper.instance.deletePlanItem(itemId);
    _loadAllPlanItems();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯課表'),
        actions: [
          // 【新增】清除按鈕
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _clearAllPlans,
            tooltip: '清除所有課表',
          ),

          // 儲存按鈕
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveTrainingDays,
            tooltip: '儲存課表',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('請選擇您要練習的日子：', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: List.generate(7, (index) {
                final dayIndex = index + 1;
                return CheckboxListTile(
                  title: Text(_dayNames[index]),
                  value: _daysSelected[dayIndex],
                  onChanged: (bool? value) {
                    setState(() {
                      _daysSelected[dayIndex] = value ?? false;
                    });
                  },
                );
              }),
            ),
          ),
          const SizedBox(height: 32),
          
          ...List.generate(7, (index) {
            final dayIndex = index + 1;
            final dayName = _dayNames[index];
            final itemsForDay = _planItems[dayIndex] ?? [];
            
            if (_daysSelected[dayIndex] != true) {
              return const SizedBox.shrink();
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayName, style: Theme.of(context).textTheme.titleLarge),
                    const Divider(height: 20),
                    if (itemsForDay.isEmpty)
                      const Center(child: Text('尚未新增動作', style: TextStyle(color: Colors.grey))),
                    ...itemsForDay.map((item) {
                      return ListTile(
                        title: Text(item.exerciseName),
                        subtitle: Text('組數: ${item.sets}  重量: ${item.weight}kg'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deletePlanItem(item.id!),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                          onPressed: () => _showAddExerciseDialog(dayIndex),
                          tooltip: '新增動作',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// _AddExerciseDialog 保持不變，這裡省略
class _AddExerciseDialog extends StatefulWidget {
  final int dayOfWeek;
  const _AddExerciseDialog({required this.dayOfWeek});
  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}
class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  // ... 請保留您原本的程式碼 ...
  final _formKey = GlobalKey<FormState>();
  final _setsController = TextEditingController();
  final _weightController = TextEditingController();
  BodyPart? _selectedBodyPart;
  String? _selectedExerciseName;
  List<String> _exerciseOptions = [];
  @override
  void dispose() {
    _setsController.dispose();
    _weightController.dispose();
    super.dispose();
  }
  Future<void> _loadExercises(BodyPart bodyPart) async {
    final mockExercises = MockDataService.getExercisesForBodyPart(bodyPart);
    final customExercises = await DatabaseHelper.instance.getCustomExercisesForBodyPart(bodyPart);
    final allNames = <String>{};
    allNames.addAll(mockExercises.map((e) => e.name));
    allNames.addAll(customExercises.map((e) => e.name));
    setState(() {
      _exerciseOptions = allNames.toList();
      _selectedExerciseName = null;
    });
  }
  void _save() {
    if (_formKey.currentState!.validate() && _selectedExerciseName != null) {
      final newItem = PlanItem(
        dayOfWeek: widget.dayOfWeek,
        exerciseName: _selectedExerciseName!,
        sets: _setsController.text,
        weight: _weightController.text,
      );
      Navigator.of(context).pop(newItem);
    }
  }
  @override
  Widget build(BuildContext context) {
     return AlertDialog(
      title: const Text('新增動作'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<BodyPart>(
                value: _selectedBodyPart,
                hint: const Text('選擇部位'),
                items: BodyPart.values.map((part) {
                  return DropdownMenuItem(value: part, child: Text(part.displayName));
                }).toList(),
                onChanged: (BodyPart? newValue) {
                  if (newValue != null) {
                    setState(() { _selectedBodyPart = newValue; });
                    _loadExercises(newValue);
                  }
                },
                validator: (v) => v == null ? '請選擇' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedExerciseName,
                hint: const Text('選擇動作'),
                disabledHint: _selectedBodyPart == null ? const Text('請先選部位') : const Text('此部位無動作'),
                items: _exerciseOptions.map((name) {
                  return DropdownMenuItem(value: name, child: Text(name));
                }).toList(),
                onChanged: _exerciseOptions.isEmpty ? null : (String? newValue) {
                  setState(() { _selectedExerciseName = newValue; });
                },
                validator: (v) => v == null ? '請選擇' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _setsController, decoration: const InputDecoration(labelText: '預設組數'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? '請輸入' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _weightController, decoration: const InputDecoration(labelText: '預設重量 (kg)'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (v == null || v.isEmpty) ? '請輸入' : null),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(child: const Text('取消'), onPressed: () => Navigator.of(context).pop()),
        TextButton(child: const Text('儲存'), onPressed: _save),
      ],
    );
  }
}