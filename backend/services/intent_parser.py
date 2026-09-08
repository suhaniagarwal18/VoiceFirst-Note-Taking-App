import re
from typing import Dict, Any, Optional

class IntentParser:
    """
    Two-tier intent parsing engine:
    1. Deterministic Regex Pattern Matcher (Primary - fast, predictable, handles all core syntax)
    2. Gemini API LLM Fallback (Secondary - for complex natural phrasing or ambiguous utterances)
    """

    def __init__(self, gemini_service=None):
        self.gemini_service = gemini_service
        self._init_patterns()

    def _init_patterns(self):
        # Compiled regex patterns for high performance and clean matching
        self.patterns = [
            # Core Lecture Lifecycle
            (
                r"^(?:please\s+)?(?:start|begin|open)\s+(?:the\s+)?(?P<subject>.+?)\s+(?:lecture|class|session)\.?$",
                "START_LECTURE"
            ),
            (
                r"^(?:please\s+)?(?:end|finish|stop|close|complete|exit|done\s+with)\s+(?:the\s+)?(?:lecture|class|session|recording)\.?$",
                "END_LECTURE"
            ),

            # Note Creation with explicit prefix
            (
                r"^(?:please\s+)?(?:take\s+a\s+note|record|note)(?:\s*:\s*|\s+that\s+|\s+)(?P<content>.+)$",
                "CREATE_NOTE"
            ),

            # Tagging Commands (checks all permutations of mark/tag/label [this/it/last note/this note] [as/to] [a/an] [tag])
            (
                r"^(?:please\s+)?(?:tag|mark|set|label)(?:\s+(?:this\s+note|the\s+last\s+note|last\s+note|this|the\s+note|note|it))?(?:\s+as|\s+to)?(?:\s+(?:a|an))?\s+(?P<tag>definition|example|important|general|exam\s+point|key\s+point|key\s+concept|exam\s+note|formula)\.?$",
                "TAG_NOTE"
            ),

            # Correction Commands
            (
                r"^(?:please\s+)?(?:correct|change|replace)\s+(?:the\s+word\s+)?(?P<target>.+?)\s+(?:to|with)\s+(?P<replacement>.+?)\.?$",
                "CORRECT_NOTE_REPLACE"
            ),
            # "Correct the last note to [new full content]" or "Correct last note: [new full content]"
            (
                r"^(?:please\s+)?(?:correct|edit)\s+(?:the\s+)?last\s+note(?:\s*:\s*|\s+to\s+)(?P<new_content>.+)$",
                "CORRECT_NOTE_FULL"
            ),
            (
                r"^(?:please\s+)?(?:correct|edit)\s+(?:the\s+)?last\s+note\.?$",
                "CORRECT_LAST_NOTE_PROMPT"
            ),

            # Search & Targeted Retrieval
            (
                r"^(?:please\s+)?(?:find|search|show|get)(?: my)? notes (?:about|on|regarding|for)\s+(?P<query>.+?)\.?$",
                "SEARCH_NOTES"
            ),
            (
                r"^(?:please\s+)?(?:find|search for)\s+(?P<query>.+?)\.?$",
                "SEARCH_NOTES"
            ),

            # Read / Audio Skim
            (
                r"^(?:please\s+)?read (?:today's|todays)\s+(?:(?P<subject>.+?)\s+)?notes\.?$",
                "READ_TODAYS_NOTES"
            ),
            (
                r"^(?:please\s+)?read (?:this week's|this weeks)\s+(?:(?P<subject>.+?)\s+)?notes\.?$",
                "READ_WEEKS_NOTES"
            ),
            (
                r"^(?:please\s+)?read (?:all\s+)?(?:my\s+)?(?P<subject>.+?)\s+notes\.?$",
                "READ_SUBJECT_NOTES"
            ),
            (
                r"^(?:please\s+)?play (?:all\s+)?(?P<filter>.+?)\s+notes(?: from (?P<timeframe>today|this week))?\.?$",
                "AUDIO_SKIM"
            ),

            # Audio Navigation Controls
            (r"^(?:next|next note|go forward)\.?$", "AUDIO_NEXT"),
            (r"^(?:previous|prev|previous note|go back)\.?$", "AUDIO_PREVIOUS"),
            (r"^(?:repeat|repeat note|again|replay)\.?$", "AUDIO_REPEAT"),
            (r"^(?:stop|pause|quiet|hush|silence|halt)\.?$", "AUDIO_STOP"),
            (r"^(?:resume|continue|keep playing)\.?$", "AUDIO_RESUME"),
            (r"^(?:exit|back|leave|done)\.?$", "AUDIO_EXIT"),
            (r"^(?:help|what can i say|instructions)\.?$", "HELP"),

            # Flashcard Generation & Revision (FLASHCARDS)
            (
                r"^(?:please\s+)?(?:give\s+me|make|create|generate|show|get)\s+(?:audio\s+)?flashcards?(?:\s+(?:on|for|about)\s+(?P<topic>.+?))?\.?$",
                "FLASHCARDS"
            ),
            (
                r"^(?:please\s+)?flashcards?(?:\s+(?:on|for|about)\s+(?P<topic>.+?))?\.?$",
                "FLASHCARDS"
            ),
            (
                r"^(?:please\s+)?start\s+(?:audio\s+)?flashcards?(?:\s+revision)?(?:\s+(?:for|on|about)\s+(?P<topic>.+?))?\.?$",
                "FLASHCARDS"
            ),
            (
                r"^(?:please\s+)?start\s+(?:audio\s+)?revision(?:\s+(?:for|on|about)\s+(?P<topic>.+?))?\.?$",
                "FLASHCARDS"
            ),
            (r"^(?P<difficulty>easy|medium|hard)\.?$", "FLASHCARD_DIFFICULTY"),
            (r"^(?:skip|next card)\.?$", "FLASHCARD_SKIP"),
            (r"^(?:i don't know|i dont know|dont know|pass)\.?$", "FLASHCARD_DONT_KNOW"),
            (r"^(?:explain|explain this|why|more details|flip|flip card)\.?$", "FLASHCARD_EXPLAIN"),

            # Quiz Generation & Exam Mode (QUIZ_ME)
            (
                r"^(?:please\s+)?(?:quiz|test)\s+me(?:\s+(?:on|about))?(?:\s+(?:all\s+)?my)?(?:\s+(?P<subject>.+?)\s+notes|\s+(?P<topic>.+?))(?:\s+from\s+(?P<timeframe>today|this\s+week))?\.?$",
                "QUIZ_ME"
            ),
            (
                r"^(?:please\s+)?(?:start\s+(?:a\s+)?quiz|exam\s+mode)(?:\s+(?:for|on|about)\s+(?P<topic>.+?))?\.?$",
                "QUIZ_ME"
            ),
            (
                r"^(?:please\s+)?revise\s+(?:my\s+)?weak\s+topics?\.?$",
                "REVISE_WEAK_TOPICS"
            ),

            # Extended 4.4: Bookmarks
            (
                r"^(?:please\s+)?(?:bookmark(?:\s+(?:this|this\s+note|the\s+note|note|it))?|save(?:\s+as)?\s+bookmark|add(?:\s+a)?\s+bookmark|mark\s+this\s+for\s+revision|important\s+exam\s+point|exam\s+bookmark)\.?$",
                "BOOKMARK_NOTE"
            ),
            (
                r"^(?:please\s+)?(?:read|show|list|get) (?:my\s+)?bookmarks\.?$",
                "READ_BOOKMARKS"
            ),
            (
                r"^(?:please\s+)?revise (?:my\s+)?exam points\.?$",
                "READ_BOOKMARKS"
            ),

            # Extended 4.5: Timeline / Memory Map
            (
                r"^(?:where|when) did i (?:note|mention|write about|talk about)\s+(?P<query>.+?)\??$",
                "TIMELINE_TOPIC_QUERY"
            ),
            (
                r"^what did i (?:note|write|record) around\s+(?P<time>.+?)\??$",
                "TIMELINE_TIME_QUERY"
            ),
            (
                r"^what topics did i cover today\??$",
                "TIMELINE_TOPICS_SUMMARY"
            ),

            # Extended 4.6: Contextual / Fuzzy Search
            (
                r"^find (?:the )?(?:example|formula|definition|note) (?:my professor gave|where i wrote|about)\s+(?P<query>.+?)\.?$",
                "CONTEXTUAL_SEARCH"
            )
        ]

    def parse(self, text: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Parses spoken text into structured intent and entity dict.
        Returns: {
            "intent": str,
            "entities": dict,
            "confidence": float,
            "raw_text": str,
            "source": "regex" | "gemini" | "fallback_dictation"
        }
        """
        if not text or not text.strip():
            return {
                "intent": "UNKNOWN",
                "entities": {},
                "confidence": 0.0,
                "raw_text": "",
                "source": "regex"
            }

        cleaned = text.strip()
        # Normalize punctuation and casing for regex match, keeping raw text intact
        normalized = cleaned.lower().rstrip(".?!")

        # 1. Check Regex Patterns First
        for pattern, intent_name in self.patterns:
            match = re.match(pattern, normalized, re.IGNORECASE)
            if match:
                entities = match.groupdict()
                # Clean entities
                cleaned_entities = {}
                for k, v in entities.items():
                    if v:
                        cleaned_entities[k] = v.strip()
                
                # If CREATE_NOTE, extract content preserving original casing if possible
                if intent_name == "CREATE_NOTE" and "content" in cleaned_entities:
                    # Extract from raw cleaned text to preserve capitalization
                    note_match = re.match(r"^(?:please\s+)?(?:take\s+a\s+note|record|note)(?:\s*:\s*|\s+that\s+|\s+)(.+)$", cleaned, re.IGNORECASE)
                    if note_match:
                        cleaned_entities["content"] = note_match.group(1).strip()

                # Normalize tag names to Title case (Important, Definition, Example, General)
                if "tag" in cleaned_entities:
                    tag_val = cleaned_entities["tag"].lower()
                    if "import" in tag_val or "exam" in tag_val or "key" in tag_val:
                        cleaned_entities["tag"] = "Important"
                    elif "def" in tag_val:
                        cleaned_entities["tag"] = "Definition"
                    elif "examp" in tag_val:
                        cleaned_entities["tag"] = "Example"
                    else:
                        cleaned_entities["tag"] = "General"

                return {
                    "intent": intent_name,
                    "entities": cleaned_entities,
                    "confidence": 1.0,
                    "raw_text": cleaned,
                    "source": "regex"
                }

        # 2. Context-dependent shorthands
        if context:
            mode = context.get("current_mode")
            if mode == "flashcard_active":
                # If answering flashcard or giving difficulty
                if normalized in ["1", "easy"]:
                    return {"intent": "FLASHCARD_DIFFICULTY", "entities": {"difficulty": "Easy"}, "confidence": 1.0, "raw_text": cleaned, "source": "regex"}
                elif normalized in ["2", "medium"]:
                    return {"intent": "FLASHCARD_DIFFICULTY", "entities": {"difficulty": "Medium"}, "confidence": 1.0, "raw_text": cleaned, "source": "regex"}
                elif normalized in ["3", "hard"]:
                    return {"intent": "FLASHCARD_DIFFICULTY", "entities": {"difficulty": "Hard"}, "confidence": 1.0, "raw_text": cleaned, "source": "regex"}
                else:
                    return {"intent": "FLASHCARD_ANSWER", "entities": {"answer": cleaned}, "confidence": 0.9, "raw_text": cleaned, "source": "regex"}
            elif mode == "quiz_active":
                return {"intent": "QUIZ_ANSWER", "entities": {"answer": cleaned}, "confidence": 0.9, "raw_text": cleaned, "source": "regex"}
            elif mode == "active_lecture" and not normalized.startswith("note"):
                # If user is in active lecture and simply speaks something lengthy without "note:",
                # but it sounds like a lecture note, we can check if it's note content.
                pass

        # 3. Gemini Fallback for Ambiguous / Natural Input
        if self.gemini_service and self.gemini_service.is_available():
            gemini_result = self.gemini_service.parse_intent(cleaned, context)
            if gemini_result and gemini_result.get("intent") != "UNKNOWN":
                return gemini_result

        # 4. Default / Fallback: If in active lecture, treat as note dictation if it doesn't match commands
        if context and context.get("current_session_id") and len(cleaned.split()) >= 3:
            return {
                "intent": "CREATE_NOTE",
                "entities": {"content": cleaned},
                "confidence": 0.75,
                "raw_text": cleaned,
                "source": "fallback_dictation"
            }

        return {
            "intent": "UNKNOWN",
            "entities": {},
            "confidence": 0.0,
            "raw_text": cleaned,
            "source": "regex"
        }
