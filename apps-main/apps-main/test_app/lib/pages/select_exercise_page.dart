import 'package:flutter/material.dart';
import '../models/exercise_model.dart';
import '../models/custom_exercise.dart';
import '../services/mock_data_service.dart';
import '../services/database_helper.dart';
import './exercise_setup_page.dart';
import './training_mode_selection_page.dart';

// 主畫面
class SelectExercisePage extends StatefulWidget {
  final BodyPart bodyPart;
  const SelectExercisePage({super.key, required this.bodyPart});

  @override
  State<SelectExercisePage> createState() => _SelectExercisePageState();
}

class _SelectExercisePageState extends State<SelectExercisePage> {
  late final List<Exercise> _predefinedExercises;
  List<CustomExercise> _customExercises = [];

  @override
  void initState() {
    super.initState();
    _predefinedExercises = MockDataService.getExercisesForBodyPart(widget.bodyPart);
    _loadCustomExercises();
  }

  Future<void> _loadCustomExercises() async {
    _customExercises = await DatabaseHelper.instance.getCustomExercisesForBodyPart(widget.bodyPart);
    setState(() {});
  }

  // 跳到動作設定頁
  void _goToSetupPage(Exercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
       builder: (context) => TrainingModeSelectionPage(
          exercise: exercise,
          bodyPart: widget.bodyPart,
        ),
      ),
    );
  }

  // 新增自訂動作浮動窗
  Future<void> _showAddCustomExerciseDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增自訂動作'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '動作名稱'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入動作名稱' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final customExercise = CustomExercise(
                    bodyPart: widget.bodyPart,
                    name: name,
                  );
                  await DatabaseHelper.instance.insertCustomExercise(customExercise);
                  Navigator.of(context).pop();
                  await _loadCustomExercises();
                }
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyPartName = widget.bodyPart.displayName;

    return Scaffold(
      appBar: AppBar(
        title: Text('選擇 $bodyPartName 動作'),
      ),
      body: ListView.builder(
        itemCount: _predefinedExercises.length + _customExercises.length,
        itemBuilder: (context, index) {
          if (index < _predefinedExercises.length) {
            final exercise = _predefinedExercises[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(exercise.description ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _goToSetupPage(exercise),
              ),
            );
          } else {
            // custom exercise slot
            final customExercise = _customExercises[index - _predefinedExercises.length];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                title: Text(customExercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(customExercise.description ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: '刪除此自訂動作',
                  onPressed: () async {
                    await DatabaseHelper.instance.deleteCustomExercise(customExercise.id!);
                    await _loadCustomExercises();
                  }
                ),
                onTap: () => _goToSetupPage(
                  Exercise(name: customExercise.name, description: customExercise.description),
                ),
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomExerciseDialog,
        tooltip: '新增自訂動作',
        child: const Icon(Icons.add),
      ),
    );
  }
}
