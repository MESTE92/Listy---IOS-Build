import 'dart:io';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_service.dart';

import '../constants/theme_colors.dart';

class ChatDialog extends StatefulWidget {
  final bool autoStartListening;
  final String? initialImagePath;
  
  const ChatDialog({super.key, this.autoStartListening = false, this.initialImagePath});

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  final List<Map<String, String>> _messages = []; // role, content
  bool _isLoading = false;

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.initialImagePath;
    _initSpeech();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _speechToText.cancel(); 
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
    
    if (_speechEnabled && widget.autoStartListening) {
      // Small delay to let UI build
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _startListening();
      }
    }
  }

  Timer? _silenceTimer;

  void _startListening() async {
    _silenceTimer?.cancel();
    // Start timer immediately in case user says nothing? 
    // Usually wait for first result? Or just silence from start? 
    // "wenn der user 5 sekunden nichts gesagt hat" implies silence after start or after last word.
    _silenceTimer = Timer(const Duration(seconds: 5), () => _sendMessage());

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
        });
        
        // Reset timer on every word detected
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(seconds: 5), () {
           // Auto-send logic
           if (_isListening) { 
             _sendMessage(); // _sendMessage handles stopping listening
           }
        });
      },
      listenFor: const Duration(minutes: 3),
      pauseFor: const Duration(seconds: 10), // Keep native pause longer than our auto-send
      partialResults: true,
      localeId: 'de_DE', 
      cancelOnError: true,
      listenMode: ListenMode.dictation,
    );
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    _silenceTimer?.cancel();
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _imagePath == null) return;

    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final data = Provider.of<DataProvider>(context, listen: false);
    
    final currentImage = _imagePath;

    // 1. Add User Message
    setState(() {
      _messages.add({
         'role': 'user', 
         'content': text + (currentImage != null ? " [Image Attached]" : "")
      });
      _isLoading = true;
      _imagePath = null;
    });
    _controller.clear();
    _scrollToBottom();

    // 2. Build Context
    final listName = data.currentListName;
    final mode = data.isShopping ? 'Shopping' : 'To-Do';
    final tasks = data.currentTasks;
    
    final StringBuffer contextBuffer = StringBuffer();
    contextBuffer.writeln("Current List: '$listName' (Mode: $mode)");
    contextBuffer.writeln("Items:");
    if (tasks.isEmpty) {
      contextBuffer.writeln("- (List is empty)");
    } else {
      for (var t in tasks) {
        contextBuffer.writeln("- ${t.name} (Priority: ${t.priority}, Completed: ${t.isCompleted})");
      }
    }
    
    final currentListContext = contextBuffer.toString();
    final providerName = settings.aiProvider;
    final apiKey = settings.getApiKey(providerName);

    // 3. Call AI
    try {
      final response = await _aiService.sendMessage(
        userMessage: text,
        messageHistory: _messages,
        currentListContext: currentListContext,
        provider: providerName,
        apiKey: apiKey,
        imagePath: currentImage
      );

      // 4. Handle Response
      setState(() {
        _messages.add({'role': 'assistant', 'content': response.message});
      });

      // 5. Execute Actions
      if (response.actions.isNotEmpty) {
        for (var action in response.actions) {
          if (action.type == 'add') {
             final dataMap = action.data;
             final name = dataMap['name'];
             String priority = dataMap['priority'] ?? 'medium';
             if (priority.toLowerCase().contains('high') || priority.toLowerCase().contains('urgent')) { priority = 'urgent'; }
             else if (priority.toLowerCase().contains('low')) { priority = 'low'; }
             else { priority = 'medium'; }
             
             if (name != null && name.toString().isNotEmpty) {
               data.addTask(name, priority: priority);
             }
          } else if (action.type == 'delete') {
             final name = action.data['name'];
             if (name != null) {
               try {
                 final task = data.currentTasks.firstWhere((t) => t.name.toLowerCase() == name.toString().toLowerCase());
                 data.deleteTask(task);
               } catch(e) { /* ignore */ }
             }
          }
        }
      }
      
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': "Error: $e"});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lavender),
          boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.2),
               blurRadius: 10,
               spreadRadius: 2
             )
          ]
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.lavenderLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Row(
                     children: [
                       Icon(Icons.auto_awesome, color: AppColors.lavender),
                       SizedBox(width: 10),
                       Text(
                         "AI Assistant",
                         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                       ),
                     ],
                   ),
                   IconButton(
                     icon: const Icon(Icons.close),
                     onPressed: () => Navigator.of(context).pop(),
                   )
                ],
              ),
            ),
            
            // Chat Area
            Expanded(
              child: _messages.isEmpty 
                ? const Center(
                    child: Text(
                      "Ask me to add items, delete tasks,\nor suggest recipes!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(15),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.lavender : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: isUser ? const Radius.circular(15) : Radius.zero,
                              bottomRight: isUser ? Radius.zero : const Radius.circular(15),
                            ),
                          ),
                          child: Text(
                             msg['content'] ?? '',
                             style: TextStyle(
                               color: isUser ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color
                             ),
                          ),
                        ),
                      );
                    },
                  ),
            ),

            // Loading Indicator
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(color: AppColors.lavender),
              ),

            // Input Area
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.lavenderLight)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_imagePath != null)
                    Container(
                      height: 100,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10)
                      ),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                           Center(child: Image.file(File(_imagePath!), fit: BoxFit.contain)),
                           GestureDetector(
                             onTap: () => setState(() => _imagePath = null),
                             child: Container(
                               padding: const EdgeInsets.all(2),
                               decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                               child: const Icon(Icons.close, color: Colors.red, size: 20)
                             ),
                           )
                        ],
                      ),
                    ),
                  Row(
                    children: [
                       // Microphone Button
                       IconButton(
                         icon: Icon(
                           _isListening ? Icons.mic : Icons.mic_none,
                           color: _isListening ? Colors.red : AppColors.lavender,
                         ),
                         onPressed: !_speechEnabled ? null : (_isListening ? _stopListening : _startListening),
                         tooltip: 'Spracheingabe',
                       ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: _isListening ? "Listening..." : (_imagePath != null ? "Describe image..." : "Type a message..."),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: AppColors.lavender),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: AppColors.lavender,
                        onPressed: _isLoading ? null : _sendMessage,
                        child: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
