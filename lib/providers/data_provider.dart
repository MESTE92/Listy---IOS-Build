import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';

class DataProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  
  // State
  String _mode = 'todo'; // 'todo' or 'shopping'
  
  Map<String, String> _todoLists = {'default': 'My Tasks'};
  Map<String, String> _shoppingLists = {'default': 'My List'};
  
  String _currentTodoListId = 'default';
  String _currentShoppingListId = 'default';
  
  // Tasks Cache: { listId: [Task, Task...] }
  Map<String, List<Task>> _todoTasks = {};
  Map<String, List<Task>> _shoppingTasks = {};

  // Getters
  String get mode => _mode;
  bool get isShopping => _mode == 'shopping';
  
  Map<String, String> get currentLists => isShopping ? _shoppingLists : _todoLists;
  String get currentListId => isShopping ? _currentShoppingListId : _currentTodoListId;
  String get currentListName => currentLists[currentListId] ?? "Unknown";

  List<Task> get currentTasks {
    Map<String, List<Task>> source = isShopping ? _shoppingTasks : _todoTasks;
    return source[currentListId] ?? [];
  }

  DataProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      // Load Meta Data (Lists, Settings)
      final data = await _storage.readJson('data.json');
      if (data.isNotEmpty) {
        if (data['settings'] != null) {
          _mode = data['settings']['mode'] ?? 'todo';
        }
        if (data['todo_lists'] != null) {
          try {
             _todoLists = Map<String, String>.from(data['todo_lists']);
          } catch (_) {}
        }
        if (data['shopping_lists'] != null) {
          try {
             _shoppingLists = Map<String, String>.from(data['shopping_lists']);
          } catch (_) {}
        }
        _currentTodoListId = data['current_todo_list'] ?? 'default';
        _currentShoppingListId = data['current_shopping_list'] ?? 'default';
      }

      // Load Tasks
      _todoTasks = await _storage.loadTasks('todo');
      _shoppingTasks = await _storage.loadTasks('shopping');
    } catch (e) {
      print("Error initializing DataProvider: $e");
      // Fallback to defaults (already set)
    }
    
    notifyListeners();
  }

  Future<void> _saveMetaData() async {
    await _storage.writeJson('data.json', {
      'settings': {'mode': _mode},
      'todo_lists': _todoLists,
      'shopping_lists': _shoppingLists,
      'current_todo_list': _currentTodoListId,
      'current_shopping_list': _currentShoppingListId,
    });
  }
  
  Future<void> _saveTasks() async {
    if (isShopping) {
      await _storage.saveTasks('shopping', _shoppingTasks);
    } else {
      await _storage.saveTasks('todo', _todoTasks);
    }
  }

  // --- Actions ---

  void setMode(String mode) {
    _mode = mode;
    _saveMetaData();
    notifyListeners();
  }

  void setCurrentList(String listId) {
    if (isShopping) {
      _currentShoppingListId = listId;
    } else {
      _currentTodoListId = listId;
    }
    _saveMetaData();
    notifyListeners();
  }

  void addTask(String name, {String priority = 'medium'}) {
    final newTask = Task(name: name, priority: priority);
    
    if (isShopping) {
      if (!_shoppingTasks.containsKey(_currentShoppingListId)) {
        _shoppingTasks[_currentShoppingListId] = [];
      }
      _shoppingTasks[_currentShoppingListId]!.add(newTask);
    } else {
      if (!_todoTasks.containsKey(_currentTodoListId)) {
        _todoTasks[_currentTodoListId] = [];
      }
      _todoTasks[_currentTodoListId]!.add(newTask);
    }
    
    _saveTasks();
    notifyListeners();
  }

  void toggleTask(Task task) {
    task.isCompleted = !task.isCompleted;
    _saveTasks();
    notifyListeners();
  }

  void updateTaskQuantity(Task task, int change) {
    int newQuantity = task.quantity + change;
    if (newQuantity < 1) return; // Minimum 1
    
    task.quantity = newQuantity;
    _saveTasks();
    notifyListeners();
  }

  void deleteTask(Task task) {
    if (isShopping) {
      _shoppingTasks[_currentShoppingListId]?.remove(task);
    } else {
      _todoTasks[_currentTodoListId]?.remove(task);
    }
    _saveTasks();
    notifyListeners();
  }

  void clearCompleted() {
    if (isShopping) {
      _shoppingTasks[_currentShoppingListId]?.removeWhere((t) => t.isCompleted);
    } else {
      _todoTasks[_currentTodoListId]?.removeWhere((t) => t.isCompleted);
    }
    _saveTasks();
    notifyListeners();
  }

  void clearAllTasks() {
    if (isShopping) {
      _shoppingTasks[_currentShoppingListId]?.clear();
    } else {
      _todoTasks[_currentTodoListId]?.clear();
    }
    _saveTasks();
    notifyListeners();
  }
  
  // List Management
  void createList(String name) {
    final id = const Uuid().v4();
    if (isShopping) {
      _shoppingLists[id] = name;
      _shoppingTasks[id] = [];
      _currentShoppingListId = id;
    } else {
      _todoLists[id] = name;
      _todoTasks[id] = [];
      _currentTodoListId = id;
    }
    _saveMetaData();
    _saveTasks(); 
    notifyListeners();
  }

  void renameList(String id, String newName) {
    if (isShopping) {
      if (_shoppingLists.containsKey(id)) {
        _shoppingLists[id] = newName;
      }
    } else {
      if (_todoLists.containsKey(id)) {
        _todoLists[id] = newName;
      }
    }
    _saveMetaData();
    notifyListeners();
  }
  
  void deleteList(String id) {
    if (id == 'default') return; // Cannot delete default
    
    if (isShopping) {
      _shoppingLists.remove(id);
      _shoppingTasks.remove(id);
      if (_currentShoppingListId == id) _currentShoppingListId = 'default';
    } else {
      _todoLists.remove(id);
      _todoTasks.remove(id);
      if (_currentTodoListId == id) _currentTodoListId = 'default';
    }
    _saveMetaData();
    _saveTasks();
    notifyListeners();
  }
}
