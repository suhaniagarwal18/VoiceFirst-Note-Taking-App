import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/theme.dart';
import '../core/services/voice_commander.dart';
import '../providers/notes_provider.dart';
import '../widgets/accessible_widgets.dart';

class VoiceRetrievalScreen extends StatelessWidget {
  const VoiceRetrievalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final voiceCommander = context.watch<VoiceCommander>();

    final results = notesProvider.searchResults;
    final currentIndex = notesProvider.searchIndex;
    final query = notesProvider.searchQuery;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Voice Retrieval",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AccessibleTheme.primaryGold),
        ),
        backgroundColor: AccessibleTheme.surface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Query & status banner
            Container(
              padding: const EdgeInsets.all(16),
              color: AccessibleTheme.surfaceElevated,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    query.isNotEmpty ? "SEARCH: \"$query\"" : "SEARCH RESULTS",
                    style: const TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    results.isEmpty
                        ? "No notes matched your search."
                        : "Showing note ${currentIndex + 1} of ${results.length}",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

            // Active note card preview
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 64, color: AccessibleTheme.tagImportant),
                            const SizedBox(height: 16),
                            const Text(
                              "No notes found.",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Say \"Find my notes about [topic]\" to try another search.",
                              style: TextStyle(fontSize: 16, color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final note = results[index];
                        final isSelected = index == currentIndex;

                        return Semantics(
                          selected: isSelected,
                          container: true,
                          label: "${isSelected ? 'Currently reading. ' : ''}Note ${index + 1} of ${results.length}. ${note.subject}, ${note.timestamp}. Tag: ${note.tag}. Content: ${note.text}",
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? AccessibleTheme.primaryGold : const Color(0xFF444444),
                                width: isSelected ? 3.5 : 1.5,
                              ),
                            ),
                            margin: const EdgeInsets.only(bottom: 14),
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
                                  const SizedBox(height: 12),
                                  Text(
                                    note.text,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

            // Audio Navigation Toolbar (Sighted & Screen-Reader fallback)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: AccessibleTheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  AccessibleButton(
                    label: "Previous",
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
