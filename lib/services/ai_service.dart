import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AIAction {
  final String type; // 'add', 'delete', 'read' (read might be implicit)
  final Map<String, dynamic> data;

  AIAction({required this.type, required this.data});

  factory AIAction.fromJson(Map<String, dynamic> json) {
    return AIAction(
      type: json['type'] ?? '',
      data: json['data'] ?? {},
    );
  }
}

class AIResponse {
  final String message;
  final List<AIAction> actions;

  AIResponse({required this.message, required this.actions});
}

class AIService {
  static const String _systemPrompt = """
You are a helpful assistant for a 'Listy' To-Do and Shopping List application.
You have access to the user's current list.
You can help the user by adding items, deleting items, or answering questions about the list.

If the user asks to modify the list, you MUST output a JSON block at the end of your response.
The JSON block must be wrapped in ```json ... ```.

Supported actions:
1. Add Item:
{
  "actions": [
    {
      "type": "add",
      "data": { "name": "Milk", "priority": "normal" } 
    }
  ]
}
priority options: "normal", "high"

2. Delete Item:
{
  "actions": [
    {
      "type": "delete",
      "data": { "name": "Milk" }
    }
  ]
}

You can perform multiple actions in one block.
If you are just answering a question, do not output the JSON block.
Keep your text responses concise and helpful.
""";

  Future<AIResponse> sendMessage({
    required String userMessage,
    required List<Map<String, String>> messageHistory,
    required String currentListContext,
    required String provider,
    required String apiKey,
    String? imagePath,
  }) async {
    if (apiKey.isEmpty) {
      return AIResponse(message: "Error: No API Key provided for $provider.", actions: []);
    }

    try {
      if (provider == 'OpenRouter (DeepSeek Free)') {
        if (imagePath != null) {
           // Warning: DeepSeek Free might not support images, but we try or warn?
           // For now, let's just send text and append a note about the image being ignored?
           // OR switch to Gemini automatically? Implementation Plan said "Fallback".
           // Let's just ignore for now or return error?
           // Better: Add "(Image attached but ignored by this provider)" to text.
           userMessage += " [Image attachment ignored]";
        }
        return _sendOpenAICompatible(
          baseUrl: 'https://openrouter.ai/api/v1',
          model: 'deepseek/deepseek-chat',
          apiKey: apiKey,
          messages: _buildMessages(userMessage, messageHistory, currentListContext),
        );
      } else if (provider == 'OpenAI') {
         // GPT-4o supports images. Implementing OpenAI vision is complex (url structure).
         // Skipping OpenAI vision for this pass to focus on Gemini as requested.
         if (imagePath != null) userMessage += " [Image attachment ignored]";
         
        return _sendOpenAICompatible(
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini', 
          apiKey: apiKey,
          messages: _buildMessages(userMessage, messageHistory, currentListContext),
        );
      } else if (provider == 'Google Gemini') {
        return _sendGemini(
          apiKey: apiKey,
          messages: _buildMessages(userMessage, messageHistory, currentListContext),
          imagePath: imagePath,
        );
      } else {
        return AIResponse(message: "Provider $provider not implemented.", actions: []);
      }
    } catch (e) {
      return AIResponse(message: "Error communicating with AI: $e", actions: []);
    }
  }

  List<Map<String, dynamic>> _buildMessages(String userMsg, List<Map<String, String>> history, String listContext) {
    final List<Map<String, dynamic>> messages = [
      {'role': 'system', 'content': '$_systemPrompt\n\nCurrent List Context:\n$listContext'}
    ];
    
    // Add history
    for (var msg in history) {
      messages.add({'role': msg['role'], 'content': msg['content']});
    }

    messages.add({'role': 'user', 'content': userMsg});
    return messages;
  }

  Future<AIResponse> _sendOpenAICompatible({
    required String baseUrl,
    required String model,
    required String apiKey,
    required List<Map<String, dynamic>> messages,
  }) async {
    final url = Uri.parse('$baseUrl/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        if (baseUrl.contains('openrouter')) 'HTTP-Referer': 'https://github.com/MESTE92/Listy',
        if (baseUrl.contains('openrouter')) 'X-Title': 'Listy',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices'][0]['message']['content'] as String;
      return _parseContent(content);
    } else {
      throw Exception('Failed to load. Status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  String? _cachedGeminiModel;

  Future<String> _resolveGeminiModel(String apiKey) async {
    if (_cachedGeminiModel != null) return _cachedGeminiModel!;

    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List).cast<Map<String, dynamic>>();
        
        // Filter for generateContent support
        final validModels = models.where((m) {
           final methods = (m['supportedGenerationMethods'] as List).cast<String>();
           return methods.contains('generateContent');
        }).map((m) => m['name'] as String).toList();

        if (validModels.isEmpty) return 'models/gemini-1.5-flash';

        // Priorities (matching Flet app logic)
        final priorities = [
           "gemini-1.5-flash-002",
           "gemini-1.5-flash-001",
           "gemini-1.5-flash",
           "gemini-1.5-pro",
           "gemini-pro"
        ];

        for (final p in priorities) {
           for (final m in validModels) {
             if (m.endsWith(p) || m == 'models/$p') {
               _cachedGeminiModel = m.replaceFirst('models/', ''); // URL expects just name usually, or models/name?
               // API documentation says: "models/gemini-pro". But generateContent URL is models/MODEL:generateContent
               // If m is "models/gemini-pro", we keep it? 
               // The URL building was: .../models/gemini-pro:generateContent
               // So if I return "models/gemini-pro", I should ensure I don't double "models/".
               // The existing code did `models/gemini-1.5-flash...` in path.
               // Let's standardise to returning just the ID "gemini-1.5-flash-001" if possible, or handle prefix.
               // API returns "models/..." usually.
               // I will strip "models/" prefix for consistency with my URL builder.
               return _cachedGeminiModel!;
             }
           }
        }
        
        // Fallback to any flash
        for (final m in validModels) {
          if (m.contains('flash') && !m.contains('exp')) {
             _cachedGeminiModel = m.replaceFirst('models/', '');
             return _cachedGeminiModel!;
          }
        }
        
        if (validModels.isNotEmpty) {
           _cachedGeminiModel = validModels.first.replaceFirst('models/', '');
           return _cachedGeminiModel!;
        }
      }
    } catch (e) {

    }
    
    return 'gemini-1.5-flash'; // Hard fallback
  }

  Future<AIResponse> _sendGemini({
    required String apiKey,
    required List<Map<String, dynamic>> messages,
    String? imagePath,
  }) async {
    final modelId = await _resolveGeminiModel(apiKey);
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$apiKey');
    
    final contents = <Map<String, dynamic>>[];
    
    // Merge system prompt
    String systemMsg = messages.firstWhere((m) => m['role'] == 'system')['content'];
    
    bool isFirst = true;
    for (var msg in messages) {
      if (msg['role'] == 'system') continue; 
      
      String text = msg['content'];
      if (isFirst) {
        text = "SYSTEM INSTRUCTION: $systemMsg\n\nUSER MESSAGE: $text";
        isFirst = false;
      }

      final parts = <Map<String, dynamic>>[];
      parts.add({'text': text});

      // Attach image to the LAST user message (which is the current one)
      if (imagePath != null && msg == messages.last && msg['role'] == 'user') {
         try {
           final bytes = await File(imagePath).readAsBytes();
           final base64Image = base64Encode(bytes);
           parts.add({
             'inline_data': {
               'mime_type': 'image/jpeg', // Simple assumption for now
               'data': base64Image
             }
           });
         } catch (e) {

           parts.add({'text': "\n[Error attaching image: $e]"});
         }
      }
      
      contents.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': parts
      });
    }
    
    if (contents.isEmpty) {
       contents.add({
        'role': 'user',
        'parts': [{'text': "SYSTEM INSTRUCTION: $systemMsg"}]
      });
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contents': contents}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final candidate = data['candidates']?[0];
      if (candidate != null) {
        final content = candidate['content']['parts'][0]['text'] as String;
        return _parseContent(content);
      } else {
        return AIResponse(message: "No response from Gemini.", actions: []);
      }
    } else {
       throw Exception('Failed on model $modelId. Status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  AIResponse _parseContent(String content) {
    // Look for ```json ... ```
    // Logic: Find last matching block to avoid confusion? Or just first?
    // User might explain then do code.
    
    final jsonRegex = RegExp(r'```json\s*(\{.*?\})\s*```', multiLine: true, dotAll: true);
    final match = jsonRegex.firstMatch(content);

    List<AIAction> actions = [];
    String textMessage = content;

    if (match != null) {
      try {
        final jsonStr = match.group(1)!;
        final jsonMap = jsonDecode(jsonStr);
        if (jsonMap['actions'] != null) {
          final acts = jsonMap['actions'] as List;
          actions = acts.map((e) => AIAction.fromJson(e)).toList();
        }
        // Remove the JSON block from the text shown to user?
        // Usually looks cleaner if we hide it.
        textMessage = content.replaceFirst(match.group(0)!, '').trim();
      } catch (e) {

      }
    }
    
    return AIResponse(message: textMessage, actions: actions);
  }
}
