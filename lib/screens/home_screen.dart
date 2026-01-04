import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../services/localization_service.dart';
import '../constants/theme_colors.dart';
import '../constants/suggestions.dart';
import '../widgets/filter_segments.dart';
import '../widgets/task_tile.dart';
import '../widgets/settings_dialog.dart';

import 'package:image_picker/image_picker.dart';
import '../widgets/chat_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _todoFilter = 'medium';
  String _shoppingFilter = 'open';
  final TextEditingController _textController = TextEditingController();
  String _selectedPriority = 'medium';
  
  List<String> _filteredSuggestions = [];
  bool _showSuggestions = false;

  Future<void> _pickAndShowChat() async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final ImagePicker picker = ImagePicker();
    
    // Show Source Selection
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context, 
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) => SafeArea(
        child: Container(
          height: 150,
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(LocalizationService.get('camera_source_camera', settingsProvider.language) ?? 'Camera'), 
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
               ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(LocalizationService.get('camera_source_gallery', settingsProvider.language) ?? 'Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      )
    );

    if (source != null) {
      if (!mounted) return;
      try {
        final XFile? image = await picker.pickImage(source: source);
        if (image != null && mounted) {
           showDialog(
             context: context,
             builder: (_) => ChatDialog(initialImagePath: image.path)
           );
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    final lang = settingsProvider.language;
    final currentFilter = dataProvider.isShopping ? _shoppingFilter : _todoFilter;
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- Header (App Bar alternative) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Listy", 
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                      shadows: [
                        Shadow(
                          offset: const Offset(2, 2),
                          blurRadius: 4.0,
                          color: AppColors.lavender,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Camera Button
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: AppColors.lavender),
                        tooltip: "Vision Input",
                        onPressed: () => _pickAndShowChat(),
                      ),
                      // Voice Input Button
                      IconButton(
                        icon: const Icon(Icons.mic, color: AppColors.lavender),
                        tooltip: "Voice Input",
                        onPressed: () { 
                           showDialog(
                             context: context, 
                             builder: (_) => const ChatDialog(autoStartListening: true)
                           );
                        },
                      ),
                      // AI button
                      IconButton(
                        icon: const Icon(Icons.auto_awesome, color: AppColors.lavender),
                        onPressed: () {
                           showDialog(context: context, builder: (_) => const ChatDialog());
                        },
                      ),
                      // Mode Toggle
                      IconButton(
                        icon: Icon(
                          dataProvider.isShopping ? Icons.list_alt : Icons.shopping_cart, 
                          color: AppColors.lavender
                        ),
                        tooltip: dataProvider.isShopping 
                          ? LocalizationService.get('mode_todo', lang) 
                          : LocalizationService.get('mode_shopping', lang),
                        onPressed: () {
                          dataProvider.setMode(dataProvider.isShopping ? 'todo' : 'shopping');
                        },
                      ),
                      // Theme Toggle
                      IconButton(
                        icon: Icon(
                          themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          color: AppColors.lavender
                        ),
                        onPressed: () {
                          themeProvider.toggleTheme();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: AppColors.lavender),
                        onPressed: () {
                          showDialog(context: context, builder: (_) => const SettingsDialog());
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
            
            const Divider(height: 1, color: AppColors.lavenderLight),
            
            // --- Sticky Header (Inputs & Filter) ---
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      // List Selector Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.lavender),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: DropdownButton<String>(
                                  value: dataProvider.currentListId,
                                  isExpanded: true,
                                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.lavender),
                                  items: dataProvider.currentLists.entries.map((e) {
                                    return DropdownMenuItem(value: e.key, child: Text(e.value));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) dataProvider.setCurrentList(val);
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Rename List
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppColors.lavender),
                            tooltip: LocalizationService.get('rename_list', lang),
                            onPressed: () => _showRenameListDialog(context, dataProvider, lang),
                          ),
                          // Delete List
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.lavender),
                            tooltip: LocalizationService.get('delete_list', lang),
                            onPressed: dataProvider.currentListId == 'default' 
                                ? null 
                                : () => _showDeleteListDialog(context, dataProvider, lang),
                          ),
                          // Add List
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.lavender.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: AppColors.lavender),
                              tooltip: LocalizationService.get('new_list', lang),
                              onPressed: () => _showAddListDialog(context, dataProvider, lang),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      // Text Input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              decoration: InputDecoration(
                                hintText: dataProvider.isShopping 
                                  ? LocalizationService.get('add_item_hint', lang) 
                                  : LocalizationService.get('add_task_hint', lang),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: AppColors.lavender),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: AppColors.lavender),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              onChanged: (val) {
                                 if (dataProvider.isShopping && val.isNotEmpty) {
                                   setState(() {
                                     _filteredSuggestions = Suggestions.list
                                         .where((s) => s.toLowerCase().startsWith(val.toLowerCase()))
                                         .take(5)
                                         .toList();
                                     _showSuggestions = _filteredSuggestions.isNotEmpty;
                                   });
                                 } else {
                                   setState(() {
                                     _showSuggestions = false;
                                   });
                                 }
                              },
                              onSubmitted: (_) {
                                _addTask(dataProvider);
                                setState(() => _showSuggestions = false);
                              },
                            ),
                          ),
                          if (!dataProvider.isShopping)
                            const SizedBox(width: 8),
                          if (!dataProvider.isShopping)
                            DropdownButton<String>(
                               value: _selectedPriority,
                               underline: Container(),
                               icon: const Icon(Icons.flag, color: AppColors.lavender),
                               items: [
                                 DropdownMenuItem(value: 'urgent', child: Text(LocalizationService.get('urgent', lang))),
                                 DropdownMenuItem(value: 'medium', child: Text(LocalizationService.get('medium', lang))),
                                 DropdownMenuItem(value: 'low', child: Text(LocalizationService.get('low', lang))),
                               ],
                               onChanged: (val) {
                                 if (val != null) setState(() => _selectedPriority = val);
                               },
                            ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: AppColors.lavender, size: 40),
                            onPressed: () {
                              _addTask(dataProvider);
                              setState(() => _showSuggestions = false);
                            }
                          )
                        ],
                      ),
                      
                      // --- Suggestions List ---
                      // Suggestions removed from here to be placed in Stack overlay
    
                      const SizedBox(height: 10),
                      
                      // Segments
                      FilterSegments(
                        currentFilter: currentFilter, 
                        onFilterChanged: (val) {
                          setState(() {
                             if (dataProvider.isShopping) {
                               _shoppingFilter = val;
                             } else {
                               _todoFilter = val;
                             }
                          });
                        }
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // --- Task List ---
            Expanded(
              child: Stack(
                children: [
                  Consumer<DataProvider>(
                    builder: (context, data, child) {
                      final tasks = data.currentTasks;
                      final filteredTasks = tasks.where((t) {
                         if (data.isShopping) {
                           if (currentFilter == 'open') return !t.isCompleted;
                           if (currentFilter == 'cart') return t.isCompleted;
                           return true;
                         } else {
                           // Todo Mode - Filter by Priority
                           if (currentFilter == 'done') {
                             return t.isCompleted;
                           }
                           // For priority tabs, we show tasks of that priority that are NOT done
                           return t.priority == currentFilter && !t.isCompleted;
                         }
                      }).toList();
                      
                      if (filteredTasks.isEmpty) {
                        return Center(
                          child: Text(
                            LocalizationService.get('no_tasks', lang), // "No tasks"
                            style: TextStyle(color: Colors.grey[400], fontSize: 18)
                          )
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          return TaskTile(
                            task: task, 
                            onToggle: (t) {
                               data.toggleTask(t);
                               // Feedback for To-Do Mode
                               if (!data.isShopping && t.isCompleted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        LocalizationService.get('task_completed_msg', lang),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold
                                        )
                                      ),
                                      backgroundColor: AppColors.lavender,
                                      duration: const Duration(seconds: 1), 
                                    )
                                  );
                               }
                            },
                            onDelete: data.deleteTask,
                            isShopping: data.isShopping,
                            onQuantityChanged: (t, change) => data.updateTaskQuantity(t, change),
                          );
                        },
                      );
                    },
                  ),
                  
                  // Dimming Overlay when suggestions are active
                  if (_showSuggestions && dataProvider.isShopping) ...[
                     Positioned.fill(
                       child: GestureDetector(
                         onTap: () {
                           // Tap outside suggestions to close them
                           setState(() => _showSuggestions = false);
                           FocusScope.of(context).unfocus();
                         },
                         child: Container(
                           color: Colors.black.withValues(alpha: 0.95), // 95% Dimming
                         ),
                       ),
                     ),
                     Positioned(
                       top: 0,
                       left: 0,
                       right: 0,
                       bottom: 0, // Fill the available space to allow scrolling
                       child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10)
                            ),
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true, // Takes only needed space up to constraints
                            itemCount: _filteredSuggestions.length,
                            itemBuilder: (context, index) {
                              final s = _filteredSuggestions[index];
                              return InkWell(
                                onTap: () {
                                  _textController.text = s;
                                  _textController.selection = TextSelection.fromPosition(TextPosition(offset: s.length));
                                  setState(() => _showSuggestions = false);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: AppColors.lavenderLight.withOpacity(0.3))),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                                  child: Text(s, style: const TextStyle(fontSize: 16)), // Smaller Text
                                ),
                              );
                            },
                          )
                       ),
                     )
                  ],
                ],
              ),
            ),
            
            // --- Compact Footer (Clear Actions) ---
            if (dataProvider.currentTasks.isNotEmpty)
              Container(
                padding: EdgeInsets.only(
                  top: 8, 
                  left: 20, 
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 8
                ),
                decoration: BoxDecoration(
                  border: const Border(top: BorderSide(color: AppColors.lavenderLight, width: 0.5)),
                  color: isDark ? Colors.black26 : Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Clear List
                    _buildCompactAction(
                      icon: Icons.delete_sweep, 
                      color: isDark ? Colors.grey : Colors.black54, 
                      label: LocalizationService.get('clear_list', lang),
                      onTap: () => _showClearDialog(context, dataProvider, true, lang)
                    ),

                    // Middle: Keyboard Hide
                    IconButton(
                      icon: const Icon(Icons.keyboard_hide, color: AppColors.lavender),
                      onPressed: () => FocusScope.of(context).unfocus(),
                    ),

                    // Right: Clear Cart (only if shopping)
                    if (dataProvider.isShopping)
                       Padding(
                         padding: const EdgeInsets.only(left: 15),
                         child: _buildCompactAction(
                            icon: Icons.remove_shopping_cart, 
                            color: Colors.redAccent, 
                            label: LocalizationService.get('empty_cart', lang),
                            onTap: () => _showClearDialog(context, dataProvider, false, lang)
                          ),
                       )
                    else 
                       const SizedBox(width: 40), // Balance spacing
                  ],
                )
              )
          ],
        ),
      ),
    );
  }

  void _addTask(DataProvider provider) {
    if (_textController.text.isEmpty) return;
    provider.addTask(_textController.text, priority: _selectedPriority);
    _textController.clear();
  }
  
  void _showClearDialog(BuildContext context, DataProvider provider, bool clearAll, String lang) {
    String title = "";
    String content = "";
    
    if (clearAll) {
      title = LocalizationService.get('clear_list', lang);
      content = LocalizationService.get('confirm_clear_list', lang);
    } else {
      if (provider.isShopping) {
        title = LocalizationService.get('empty_cart', lang);
        content = LocalizationService.get('confirm_empty_cart', lang);
      } else {
        title = LocalizationService.get('clear_completed', lang);
        content = LocalizationService.get('confirm_clear_completed', lang);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: Text(LocalizationService.get('cancel', lang)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text(
              LocalizationService.get('delete', lang), 
              style: const TextStyle(color: Colors.red)
            ),
            onPressed: () {
              if (clearAll) {
                provider.clearAllTasks();
              } else {
                provider.clearCompleted();
              }
              Navigator.of(ctx).pop();
            },
          )
        ],
      )
    );
  }

  Future<void> _showAddListDialog(BuildContext context, DataProvider provider, String lang) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.get('new_list', lang)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: LocalizationService.get('new_list', lang)),
          autofocus: true,
        ),
        actions: [
          TextButton(
             child: Text(LocalizationService.get('cancel', lang)),
             onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text(LocalizationService.get('save', lang)),
            onPressed: () {
               if (controller.text.isNotEmpty) {
                 provider.createList(controller.text);
                 Navigator.of(ctx).pop();
               }
            },
          )
        ],
      )
    );
  }

  Future<void> _showRenameListDialog(BuildContext context, DataProvider provider, String lang) async {
    final controller = TextEditingController(text: provider.currentListName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.get('rename_list', lang)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: LocalizationService.get('rename_list', lang)),
          autofocus: true,
        ),
        actions: [
          TextButton(
             child: Text(LocalizationService.get('cancel', lang)),
             onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text(LocalizationService.get('save', lang)),
            onPressed: () {
               if (controller.text.isNotEmpty) {
                 provider.renameList(provider.currentListId, controller.text);
                 Navigator.of(ctx).pop();
               }
            },
          )
        ],
      )
    );
  }

  Future<void> _showDeleteListDialog(BuildContext context, DataProvider provider, String lang) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.get('delete_list', lang)),
        content: Text("Delete '${provider.currentListName}'?"),
        actions: [
          TextButton(
             child: Text(LocalizationService.get('cancel', lang)),
             onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text(LocalizationService.get('delete', lang), style: const TextStyle(color: Colors.red)),
            onPressed: () {
               provider.deleteList(provider.currentListId);
               Navigator.of(ctx).pop();
            },
          )
        ],
      )
    );
  }
  


  Widget _buildCompactAction({
    required IconData icon, 
    required Color color, 
    required String label, 
    required VoidCallback onTap
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))
            ],
          ),
        ),
      ),
    );
  }
}
