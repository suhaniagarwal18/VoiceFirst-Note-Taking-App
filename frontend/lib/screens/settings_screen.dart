import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/theme.dart';
import '../core/services/voice_commander.dart';
import '../providers/settings_provider.dart';
import '../widgets/accessible_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  bool _isBackendConnected = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _urlController = TextEditingController(text: settings.backendUrl);
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() => _isChecking = true);
    final voiceCommander = context.read<VoiceCommander>();
    final connected = await voiceCommander.apiClient.checkHealth();
    setState(() {
      _isBackendConnected = connected;
      _isChecking = false;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final voiceCommander = context.watch<VoiceCommander>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Accessible Settings",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AccessibleTheme.primaryGold),
        ),
        backgroundColor: AccessibleTheme.surface,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Backend Connection Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "BACKEND CONNECTION",
                      style: TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _isBackendConnected ? Icons.check_circle : Icons.error,
                          color: _isBackendConnected ? AccessibleTheme.successGreen : AccessibleTheme.errorRed,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isBackendConnected
                                ? "Backend Connected (Localhost: 5000)"
                                : "Backend Disconnected",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        _isChecking
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AccessibleTheme.primaryGold),
                              )
                            : IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                onPressed: _checkHealth,
                                tooltip: "Check Connection",
                              ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: "Backend API URL",
                        labelStyle: TextStyle(color: AccessibleTheme.primaryGold),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AccessibleTheme.primaryGold, width: 2)),
                      ),
                      onSubmitted: (val) {
                        settings.updateBackendUrl(val);
                        voiceCommander.apiClient.baseUrl = val;
                        _checkHealth();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Voice & Speech Output Settings Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "SPEECH SYNTHESIS (TTS)",
                      style: TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    
                    // Speech Rate Slider
                    Text(
                      "Speech Rate: ${(settings.speechRate * 2).toStringAsFixed(1)}x",
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    Slider(
                      value: settings.speechRate,
                      min: 0.2,
                      max: 1.0,
                      divisions: 8,
                      activeColor: AccessibleTheme.primaryGold,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        settings.updateSpeechRate(val);
                        voiceCommander.ttsService.setRate(val);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Speech Pitch Slider
                    Text(
                      "Speech Pitch: ${settings.speechPitch.toStringAsFixed(1)}",
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    Slider(
                      value: settings.speechPitch,
                      min: 0.5,
                      max: 1.5,
                      divisions: 10,
                      activeColor: AccessibleTheme.accentBlue,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        settings.updateSpeechPitch(val);
                        voiceCommander.ttsService.setPitch(val);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Test Voice Output Button
                    AccessibleButton(
                      label: "Test Voice Feedback",
                      icon: Icons.volume_up,
                      onPressed: () {
                        voiceCommander.ttsService.speak("Voice-First test. Speech rate and pitch configured successfully.");
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Voice Interaction Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "VOICE PREFERENCES",
                      style: TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text("Continuous Auto-Listening", style: TextStyle(color: Colors.white, fontSize: 16)),
                      subtitle: const Text("Automatically resumes listening after speaking answers", style: TextStyle(color: Colors.white70)),
                      value: settings.autoListen,
                      activeColor: AccessibleTheme.primaryGold,
                      onChanged: (val) {
                        settings.toggleAutoListen(val);
                        voiceCommander.setAutoListen(val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text("Spoken Confirmations", style: TextStyle(color: Colors.white, fontSize: 16)),
                      subtitle: const Text("Announce confirmations after every note capture and tag", style: TextStyle(color: Colors.white70)),
                      value: settings.spokenConfirmation,
                      activeColor: AccessibleTheme.primaryGold,
                      onChanged: (val) {
                        settings.toggleSpokenConfirmation(val);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
