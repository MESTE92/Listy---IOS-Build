import '../services/ai_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/localization_service.dart';
import '../constants/theme_colors.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _obscureKey = true;
  late TextEditingController _keyController;
  
  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _keyController = TextEditingController(text: settings.getApiKey(settings.aiProvider));
  }
  
  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final lang = settings.language;
    final isStandardKey = settings.aiProvider == 'OpenRouter (DeepSeek Free)';
    
    // Update controller if provider changes (and we aren't editing? simpler to just reset)
    if (_keyController.text != settings.getApiKey(settings.aiProvider) && !(_keyController.selection.isValid)) {
        _keyController.text = settings.getApiKey(settings.aiProvider);
    }

    return Dialog(
      backgroundColor: Colors.grey[900], // Match Flet Dark Theme style mostly
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(
                  LocalizationService.get('settings_title', lang),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 20),
            
            // Language
            Text(LocalizationService.get('language_label', lang), style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.lavender),
                borderRadius: BorderRadius.circular(30),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: settings.language,
                  isExpanded: true,
                  dropdownColor: Colors.grey[850],
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.lavender),
                  items: ['de', 'en', 'ja', 'zh'].map((code) => DropdownMenuItem(
                    value: code,
                    child: Text(LocalizationService.getLabel(code)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) settings.setLanguage(val);
                  },
                ),
              ),
            ),
            
            const Divider(color: Colors.grey, height: 40),
            
            // AI Configuration
            Text(LocalizationService.get('ai_config_title', lang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 15),
            
             Text(LocalizationService.get('ai_provider_label', lang), style: TextStyle(color: Colors.grey[400])),
             const SizedBox(height: 5),
             Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.lavender),
                borderRadius: BorderRadius.circular(30),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: settings.aiProvider,
                  isExpanded: true,
                  dropdownColor: Colors.grey[850],
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.lavender),
                  items: [
                    'OpenRouter (DeepSeek Free)', 
                    'Google Gemini', 
                    'OpenAI'
                  ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                       settings.setAiProvider(val);
                       _keyController.text = settings.getApiKey(val);
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 15),
            
            // API Key
             Text(LocalizationService.get('api_key_label', lang), style: TextStyle(color: Colors.grey[400])),
             const SizedBox(height: 5),
             TextField(
               controller: _keyController,
               obscureText: _obscureKey,
               readOnly: isStandardKey,
               style: TextStyle(color: isStandardKey ? Colors.green : Colors.white),
               decoration: InputDecoration(
                 hintText: "Enter Key...",
                 hintStyle: TextStyle(color: Colors.grey[600]),
                 enabledBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(30),
                   borderSide: const BorderSide(color: AppColors.lavender),
                 ),
                 focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(30),
                   borderSide: const BorderSide(color: AppColors.lavender),
                 ),
                 contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                 suffixIcon: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     IconButton(
                       icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                       onPressed: () => setState(() => _obscureKey = !_obscureKey),
                     ),
                     if (!isStandardKey)
                        IconButton(
                          icon: const Icon(Icons.save, color: AppColors.lavender),
                          onPressed: () {
                             settings.setApiKey(settings.aiProvider, _keyController.text);
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Key Saved")));
                          },
                        ),
                     if (!isStandardKey)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () {
                             settings.setApiKey(settings.aiProvider, '');
                             _keyController.clear();
                          },
                        ),
                     if (isStandardKey)
                       const Padding(
                         padding: EdgeInsets.only(right: 12),
                         child: Icon(Icons.lock, color: Colors.grey, size: 20),
                       )
                   ],
                 )
               ),
             ),
             if (isStandardKey)
                const Padding(
                  padding: EdgeInsets.only(top: 5, left: 10),
                  child: Text(
                    "Using built-in Standard Key", 
                    style: TextStyle(color: Colors.green, fontSize: 12)
                  ),
                ),

             const SizedBox(height: 20),
             
             // Verify Button
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AppColors.lavenderLight,
                   foregroundColor: Colors.deepPurple,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                   padding: const EdgeInsets.symmetric(vertical: 12)
                 ),
                 onPressed: () async {
                    final apiKey = _keyController.text;
                    final provider = settings.aiProvider;
                    
                    if (apiKey.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter an API Key first.")));
                      return;
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Testing connection...")));
                    
                    try {
                      final aiService = AIService();
                      final response = await aiService.sendMessage(
                        userMessage: "Hello",
                        messageHistory: [],
                        currentListContext: "Test Mode",
                        provider: provider,
                        apiKey: apiKey
                      );
                      
                      if (response.message.startsWith("Error")) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${response.message}"), backgroundColor: Colors.red));
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Successful!"), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                    }
                 },
                 child: Text(LocalizationService.get('verify_connection', lang)),
               ),
             ),
             
             const SizedBox(height: 10),
             
             Row(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: Text(LocalizationService.get('save', lang), style: const TextStyle(color: AppColors.lavender))
                 )
               ],
             )
          ],
        ),
      ),
    );
  }
}
