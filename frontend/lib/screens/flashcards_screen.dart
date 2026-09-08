import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/theme.dart';
import '../core/services/voice_commander.dart';
import '../providers/notes_provider.dart';
import '../widgets/accessible_widgets.dart';

class FlashcardsScreen extends StatelessWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final voiceCommander = context.watch<VoiceCommander>();

    final cards = notesProvider.flashcards;
    final currentIndex = notesProvider.flashcardIndex;
    final currentCard = notesProvider.currentFlashcard;
    final isFlipped = notesProvider.isCardFlipped;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Audio Flashcards",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AccessibleTheme.primaryGold),
        ),
        backgroundColor: AccessibleTheme.surface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Flashcard Session Header
            Container(
              padding: const EdgeInsets.all(16),
              color: AccessibleTheme.surfaceElevated,
              child: Row(
                children: [
                  const Icon(Icons.style, color: AccessibleTheme.primaryGold, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentCard != null ? "SUBJECT: ${currentCard.subject.toUpperCase()}" : "FLASHCARD REVISION",
                          style: const TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          cards.isEmpty
                              ? "No active flashcards."
                              : "Card ${currentIndex + 1} of ${cards.length} • ${isFlipped ? "Showing Back (Answer)" : "Showing Front (Question)"}",
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Active Card Container
            Expanded(
              child: currentCard == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.style_outlined, size: 64, color: AccessibleTheme.primaryGold),
                            const SizedBox(height: 16),
                            const Text(
                              "No flashcards loaded.",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Say \"Give me flashcards on Biology\" or \"Make flashcards for Chemistry\" to generate cards from your notes.",
                              style: TextStyle(fontSize: 16, color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            container: true,
                            label: isFlipped
                                ? "Flashcard ${currentIndex + 1} of ${cards.length}. Showing Back. Answer: ${currentCard.back}. Tap or say Flip to show question."
                                : "Flashcard ${currentIndex + 1} of ${cards.length}. Showing Front. Question: ${currentCard.front}. Tap or say Flip to reveal answer.",
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => notesProvider.toggleCardFlip(),
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isFlipped ? AccessibleTheme.accentBlue : AccessibleTheme.primaryGold,
                                    width: 3.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          TagBadge(tag: currentCard.tag),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isFlipped ? Colors.blue.shade900.withOpacity(0.5) : Colors.amber.shade900.withOpacity(0.4),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isFlipped ? AccessibleTheme.accentBlue : AccessibleTheme.primaryGold,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Text(
                                              isFlipped ? "BACK • ANSWER" : "FRONT • QUESTION",
                                              style: TextStyle(
                                                color: isFlipped ? AccessibleTheme.accentBlue : AccessibleTheme.primaryGold,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      if (!isFlipped) ...[
                                        const Text(
                                          "QUESTION / CONCEPT:",
                                          style: TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          currentCard.front,
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                                        ),
                                        const SizedBox(height: 24),
                                        const Divider(color: Colors.white24, thickness: 1.5),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: const [
                                            Icon(Icons.touch_app, color: Colors.white54, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              "Tap card or say \"Flip\" to reveal answer",
                                              style: TextStyle(fontSize: 14, color: Colors.white60, fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        const Text(
                                          "GROUND TRUTH ANSWER:",
                                          style: TextStyle(color: AccessibleTheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          currentCard.back,
                                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                                        ),
                                        const SizedBox(height: 20),
                                        const Divider(color: Colors.white24, thickness: 1.5),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Question: ${currentCard.front}",
                                          style: const TextStyle(fontSize: 15, color: Colors.white60),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Card Action Controls (Flip & Navigation)
            if (currentCard != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AccessibleTheme.surfaceElevated,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    AccessibleButton(
                      label: "Previous",
                      icon: Icons.arrow_back,
                      isPrimary: false,
                      onPressed: currentIndex > 0 ? () => notesProvider.previousFlashcard() : null,
                    ),
                    AccessibleButton(
                      label: isFlipped ? "Show Front" : "Flip Card",
                      icon: Icons.flip,
                      isPrimary: true,
                      onPressed: () => notesProvider.toggleCardFlip(),
                    ),
                    AccessibleButton(
                      label: "Next",
                      icon: Icons.arrow_forward,
                      isPrimary: false,
                      onPressed: currentIndex + 1 < cards.length ? () => notesProvider.nextFlashcard() : null,
                    ),
                  ],
                ),
              ),

            // Spoken Flashcard Action Shortcuts
            Container(
              padding: const EdgeInsets.all(16),
              color: AccessibleTheme.surface,
              child: Column(
                children: [
                  const Text(
                    "SAY YOUR ANSWER OR RATE DIFFICULTY",
                    style: TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AccessibleButton(
                        label: "Easy",
                        icon: Icons.sentiment_very_satisfied,
                        onPressed: () => voiceCommander.processUtterance("Easy."),
                      ),
                      AccessibleButton(
                        label: "Medium",
                        icon: Icons.sentiment_neutral,
                        isPrimary: false,
                        onPressed: () => voiceCommander.processUtterance("Medium."),
                      ),
                      AccessibleButton(
                        label: "Hard",
                        icon: Icons.sentiment_very_dissatisfied,
                        isPrimary: false,
                        onPressed: () => voiceCommander.processUtterance("Hard."),
                      ),
                      AccessibleButton(
                        label: "Explain",
                        icon: Icons.help_outline,
                        isPrimary: false,
                        onPressed: () => voiceCommander.processUtterance("Explain."),
                      ),
                    ],
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

