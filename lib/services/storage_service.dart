import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/task_model.dart';

class StorageService {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _getFile(String filename) async {
    final path = await _localPath;
    return File('$path/$filename');
  }

  // --- Generic JSON Helpers ---

  Future<Map<String, dynamic>> readJson(String filename) async {
    try {
      final file = await _getFile(filename);
      if (!await file.exists()) return {};
      final contents = await file.readAsString();
      return json.decode(contents);
    } catch (e) {
      // Error reading file, return empty map
      return <String, dynamic>{};
    }

  }

  Future<void> writeJson(String filename, Map<String, dynamic> data) async {
    final file = await _getFile(filename);
    await file.writeAsString(json.encode(data));
  }

  // --- Specific Data Helpers ---

  Future<Map<String, List<Task>>> loadTasks(String mode) async {
    final filename = mode == 'shopping' ? 'shopping.json' : 'todo.json';
    final data = await readJson(filename);
    if (data is! Map<String, dynamic>) return {};

    Map<String, List<Task>> tasks = {};
    data.forEach((listId, taskList) {
      if (taskList is List) {
        tasks[listId] = taskList.map((t) => Task.fromJson(t)).toList();
      }
    });
    return tasks;
  }

  Future<void> saveTasks(String mode, Map<String, List<Task>> tasks) async {
    final filename = mode == 'shopping' ? 'shopping.json' : 'todo.json';
    Map<String, dynamic> jsonMap = {};
    
    tasks.forEach((listId, taskList) {
      jsonMap[listId] = taskList.map((t) => t.toJson()).toList();
    });
    
    await writeJson(filename, jsonMap);
  }
}
