import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/theme.dart';
import '../core/services/voice_commander.dart';
import '../providers/notes_provider.dart';
import '../widgets/accessible_widgets.dart';

class AudioReviewScreen extends StatelessWidget {
  const AudioReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final voiceCommander = context.watch<VoiceCommander>();

    final notes = notesProvider.reviewNotes.isNotEmpty ? notesProvider.reviewNotes : notesProvider.notes;
    final currentIndex = notesProvider.reviewIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Audio Review",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AccessibleTheme.primaryGold),
        ),
        backgroundColor: AccessibleTheme.surface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Review mode header
            Container(
              padding: const EdgeInsets.all(16),
              color: AccessibleTheme.surfaceElevated,
              child: Row(
                children: [
                  const Icon(Icons.headphones, color: AccessibleTheme.primaryGold, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "AUDIO SKIM MODE",
                          style: TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          notes.isEmpty
                              ? "No notes in review queue."
                              : "Reviewing ${currentIndex + 1} of ${notes.length} notes",
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Note List
            Expanded(
              child: notes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.library_books, size: 64, color: AccessibleTheme.primaryGold),
                            const SizedBox(height: 16),
                            const Text(
                              "No notes to review.",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Say \"Read today's notes\" or \"Play all important notes from this week\".",
                              style: TextStyle(fontSize: 16, color: Colors.white70),
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
                        final isPlaying = index == currentIndex;

                        return Semantics(
                          selected: isPlaying,
                          container: true,
                          label: "${isPlaying ? 'Now playing. ' : ''}Note ${index + 1}. ${note.subject}, ${note.timestamp}. ${note.text}",
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isPlaying ? AccessibleTheme.accentBlue : const Color(0xFF444444),
                                width: isPlaying ? 3.5 : 1.5,
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
                                        "${note.subject} • ${note.timestamp}",
                                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    note.text,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                      color: Colors.white,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Controls Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: AccessibleTheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  AccessibleButton(
                    label: "Prev",
                    icon: Icons.skip_previous,
                    isPrimary: false,
                    onPressed: () => voiceCommander.processUtterance("Previous."),
                  ),
                  AccessibleButton(
                    label: "Repeat",
                    icon: Icons.replay,
                    onPressed: () => voiceCommander.processUtterance("Repeat."),
                  ),
                  AccessibleButton(
                    label: "Next",
                    icon: Icons.skip_next,
                    onPressed: () => voiceCommander.processUtterance("Next."),
                  ),
                  AccessibleButton(
                    label: "Stop",
                    icon: Icons.stop,
                    isDestructive: true,
                    onPressed: () => voiceCommander.processUtterance("Stop."),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
