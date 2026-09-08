import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/theme.dart';
import '../core/constants/constants.dart';
import '../core/services/voice_commander.dart';
import '../providers/notes_provider.dart';
import '../widgets/accessible_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceCommander = context.read<VoiceCommander>();
      final notesProvider = context.read<NotesProvider>();
      
      notesProvider.fetchActiveSession();
      notesProvider.fetchNotes();
      
      // Greet immediately on open
      voiceCommander.speakGreeting(AppConstants.initialGreeting);
    });
  }

  @override
  Widget build(BuildContext context) {
    final voiceCommander = context.watch<VoiceCommander>();
    final notesProvider = context.watch<NotesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Voice-First",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AccessibleTheme.primaryGold),
        ),
        backgroundColor: AccessibleTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 30),
            tooltip: "Settings",
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Voice Indicator & State Announcer
              Center(
                child: VoiceWaveformIndicator(
                  state: voiceCommander.state,
                  onMicTap: () {
                    if (voiceCommander.isListening) {
                      voiceCommander.stopListening();
                    } else if (voiceCommander.isSpeaking) {
                      voiceCommander.interruptSpeech();
                    } else {
                      voiceCommander.startListening();
                    }
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Spoken Feedback Display Card
              if (voiceCommander.lastSpokenText.isNotEmpty)
                Semantics(
                  label: "Last spoken by app: ${voiceCommander.lastSpokenText}",
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AccessibleTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AccessibleTheme.accentBlue, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "VOICE FEEDBACK",
                          style: TextStyle(color: AccessibleTheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          voiceCommander.lastSpokenText,
                          style: const TextStyle(fontSize: 18, color: Colors.white, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Active Lecture Banner
              if (notesProvider.hasActiveLecture) ...[
                Semantics(
                  label: "Active lecture in progress: ${notesProvider.activeSession!.subject}",
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AccessibleTheme.tagImportant.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AccessibleTheme.primaryGold, width: 2.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.record_voice_over, color: AccessibleTheme.primaryGold, size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "ACTIVE LECTURE: ${notesProvider.activeSession!.subject}",
                                style: const TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const Text("Say 'Note: [content]' to record notes.", style: TextStyle(color: Colors.white70, fontSize: 15)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Voice Command Guide Section
              Semantics(
                header: true,
                child: const Text(
                  "WHAT YOU CAN SAY",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AccessibleTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 12),

              _buildCommandCard(
                context,
                title: "1. Start Lecture",
                example: "\"Start Biology lecture.\"",
                desc: "Begins a new lecture recording session.",
                icon: Icons.school,
              ),
              _buildCommandCard(
                context,
                title: "2. Capture Note",
                example: "\"Note: Mitosis is cell division.\"",
                desc: "Records and auto-tags notes with timestamps.",
                icon: Icons.edit_note,
              ),
              _buildCommandCard(
                context,
                title: "3. Voice Correction",
                example: "\"Correct decision to division.\"",
                desc: "Replaces misrecognized words completely by voice.",
                icon: Icons.spellcheck,
              ),
              _buildCommandCard(
                context,
                title: "4. Search & Retrieve",
                example: "\"Find my notes about Mitosis.\"",
                desc: "Ranks results and navigates via Next/Previous/Repeat.",
                icon: Icons.search,
              ),
              _buildCommandCard(
                context,
                title: "5. Audio Flashcards (Revision)",
                example: "\"Start flashcard revision for Biology.\"",
                desc: "Hands-free revision built from your stored notes.",
                icon: Icons.style,
              ),
              _buildCommandCard(
                context,
                title: "6. Self-Test / Exam Mode",
                example: "\"Quiz me on everything important.\"",
                desc: "Verbal Q&A quiz with scored feedback.",
                icon: Icons.quiz,
              ),

              const SizedBox(height: 24),

              // Visual Sighted / Demo Fallback Controls
              Semantics(
                header: true,
                child: const Text(
                  "ACCESSIBLE SHORTCUTS",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AccessibleButton(
                    label: "Active Lecture",
                    icon: Icons.school,
                    onPressed: () => Navigator.pushNamed(context, '/active_lecture'),
                  ),
                  AccessibleButton(
                    label: "Search Notes",
                    icon: Icons.search,
                    isPrimary: false,
                    onPressed: () => Navigator.pushNamed(context, '/retrieval'),
                  ),
                  AccessibleButton(
                    label: "Audio Review",
                    icon: Icons.headphones,
                    isPrimary: false,
                    onPressed: () => Navigator.pushNamed(context, '/audio_review'),
                  ),
                  AccessibleButton(
                    label: "Flashcards",
                    icon: Icons.style,
                    isPrimary: false,
                    onPressed: () => Navigator.pushNamed(context, '/flashcards'),
                  ),
                  AccessibleButton(
                    label: "Voice Quiz",
                    icon: Icons.quiz,
                    isPrimary: false,
                    onPressed: () => Navigator.pushNamed(context, '/quiz'),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommandCard(BuildContext context, {
    required String title,
    required String example,
    required String desc,
    required IconData icon,
  }) {
    return Semantics(
      container: true,
      label: "$title. Say $example. $desc",
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AccessibleTheme.primaryGold, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(example, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AccessibleTheme.accentBlue)),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
