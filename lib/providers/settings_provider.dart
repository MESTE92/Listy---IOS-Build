import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class SettingsProvider with ChangeNotifier {
  String _language = 'de';
  String _aiProvider = 'OpenRouter (DeepSeek Free)';
  Map<String, String> _apiKeys = {};
  
  // Standard Key Constant (also wrote to file)
  static const String _standardKey = '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';
  
  String get language => _language;
  String get aiProvider => _aiProvider;
  
  SettingsProvider() {
    _init();
  }
  
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? 'de';
    _aiProvider = prefs.getString('ai_provider') ?? 'OpenRouter (DeepSeek Free)';
    
    // Load Keys
    String geminiKey = prefs.getString('key_gemini') ?? '';
    String openaiKey = prefs.getString('key_openai') ?? '';
    
    _apiKeys = {
      'Google Gemini': geminiKey,
      'OpenAI': openaiKey,
      'OpenRouter (DeepSeek Free)': _standardKey // Placeholder, actual read from file below
    };
    
    await _ensureStandardKeyFile();
    notifyListeners();
  }
  
  Future<void> _ensureStandardKeyFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/standard_key.txt');
      if (!await file.exists()) {
        await file.writeAsString(_standardKey);
      }
      // Verify content?
      // String content = await file.readAsString();
      // if (content != _standardKey) await file.writeAsString(_standardKey);
    } catch (e) {
      print("Error managing standard key file: $e");
    }
  }
  
  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }
  
  Future<void> setAiProvider(String provider) async {
    _aiProvider = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_provider', provider);
    notifyListeners();
  }
  
  Future<void> setApiKey(String provider, String key) async {
    if (provider == 'OpenRouter (DeepSeek Free)') return; // Cannot set standard key
    
    _apiKeys[provider] = key;
    final prefs = await SharedPreferences.getInstance();
    if (provider == 'Google Gemini') {
      await prefs.setString('key_gemini', key);
    } else if (provider == 'OpenAI') {
      await prefs.setString('key_openai', key);
    }
    notifyListeners();
  }
  
  String getApiKey(String provider) {
    if (provider == 'OpenRouter (DeepSeek Free)') return _standardKey;
    return _apiKeys[provider] ?? '';
  }
}
