import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/theme.dart';
import '../core/services/voice_commander.dart';
import '../providers/notes_provider.dart';
import '../widgets/accessible_widgets.dart';

class ActiveLectureScreen extends StatelessWidget {
  const ActiveLectureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final voiceCommander = context.watch<VoiceCommander>();

    final subject = notesProvider.activeSession?.subject ?? "Lecture";
    final notes = notesProvider.notes;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Active: $subject",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AccessibleTheme.primaryGold),
        ),
        backgroundColor: AccessibleTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle, color: AccessibleTheme.errorRed, size: 32),
            tooltip: "End Lecture",
            onPressed: () {
              voiceCommander.processUtterance("End lecture.");
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Voice status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AccessibleTheme.surfaceElevated,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voiceCommander.isListening
                              ? "Listening for notes..."
                              : (voiceCommander.isSpeaking ? "Speaking..." : "Ready for voice"),
                          style: TextStyle(
                            color: voiceCommander.isListening ? AccessibleTheme.successGreen : AccessibleTheme.primaryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (voiceCommander.lastSpokenText.isNotEmpty)
                          Text(
                            voiceCommander.lastSpokenText,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      voiceCommander.isListening ? Icons.mic : Icons.mic_none,
                      color: voiceCommander.isListening ? AccessibleTheme.successGreen : AccessibleTheme.primaryGold,
                      size: 32,
                    ),
                    onPressed: () {
                      if (voiceCommander.isListening) {
                        voiceCommander.stopListening();
                      } else {
                        voiceCommander.startListening();
                      }
                    },
                  ),
                ],
              ),
            ),

            // Notes list
            Expanded(
              child: notes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.mic, size: 64, color: AccessibleTheme.primaryGold),
                            const SizedBox(height: 16),
                            const Text(
                              "No notes captured yet.",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Speak naturally:\n\"Note: Mitosis is cell division.\"",
                              style: TextStyle(fontSize: 18, color: AccessibleTheme.accentBlue, height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        final isLatest = index == 0;

                        return Semantics(
                          container: true,
                          label: "${isLatest ? 'Latest note. ' : ''}${note.subject}, ${note.timestamp}. Tag: ${note.tag}. Content: ${note.text}",
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isLatest ? AccessibleTheme.primaryGold : const Color(0xFF444444),
                                width: isLatest ? 3 : 1.5,
                              ),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TagBadge(tag: note.tag),
                                      Text(
                                        note.timestamp,
                                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    note.text,
                                    style: const TextStyle(fontSize: 18, color: Colors.white, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Voice hint bar at bottom
            Container(
              padding: const EdgeInsets.all(12),
              color: AccessibleTheme.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildHintChip("Note: [text]"),
                    const SizedBox(width: 8),
                    _buildHintChip("Tag as Important"),
                    const SizedBox(width: 8),
                    _buildHintChip("Correct [word] to [word]"),
                    const SizedBox(width: 8),
                    _buildHintChip("End lecture"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AccessibleTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white38),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AccessibleTheme.primaryGold, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
