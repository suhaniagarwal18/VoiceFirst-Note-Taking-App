import os
import json
from typing import Dict, Any, List, Optional

class GeminiService:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("GEMINI_API_KEY", "")
        self.client = None
        self._init_client()

    def _init_client(self):
        if self.api_key:
            try:
                from google import genai
                self.client = genai.Client(api_key=self.api_key)
            except Exception as e:
                print(f"[GeminiService] Warning: Could not initialize Google GenAI client: {e}")
                self.client = None

    def is_available(self) -> bool:
        return self.client is not None

    def parse_intent(self, text: str, context: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
        """
        Uses Gemini to parse complex or ambiguous natural language commands.
        """
        if not self.is_available():
            return None

        prompt = f"""
You are the intent parser for "Voice-First", a voice-driven college note-taking mobile app for visually impaired students.
Given the user utterance: "{text}"
And the conversation context: {json.dumps(context or {})}

Classify into one of the following intents:
- START_LECTURE (entities: {{"subject": str}})
- END_LECTURE
- CREATE_NOTE (entities: {{"content": str}})
- TAG_NOTE (entities: {{"tag": "Definition" | "Example" | "Important" | "General"}})
- CORRECT_NOTE_REPLACE (entities: {{"target": str, "replacement": str}})
- CORRECT_NOTE_FULL (entities: {{"new_content": str}})
- SEARCH_NOTES (entities: {{"query": str}})
- READ_TODAYS_NOTES (entities: {{"subject": str | null}})
- AUDIO_SKIM (entities: {{"filter": str, "timeframe": str | null}})
- AUDIO_NEXT / AUDIO_PREVIOUS / AUDIO_REPEAT / AUDIO_STOP / AUDIO_EXIT / HELP
- QUIZ_ME (entities: {{"topic": str | null, "subject": str | null}})
- FLASHCARDS (entities: {{"topic": str | null, "subject": str | null}})
- START_FLASHCARDS (entities: {{"subject": str | null}})
- START_QUIZ (entities: {{"filter": str | null}})
- REVISE_WEAK_TOPICS
- BOOKMARK_NOTE
- READ_BOOKMARKS
- TIMELINE_TOPIC_QUERY (entities: {{"query": str}})
- TIMELINE_TIME_QUERY (entities: {{"time": str}})
- TIMELINE_TOPICS_SUMMARY
- UNKNOWN

Respond ONLY with valid JSON in the format:
{{"intent": "INTENT_NAME", "entities": {{}}, "confidence": 0.95}}
"""
        try:
            response = self.client.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt,
            )
            raw = response.text.strip()
            # Clean markdown codeblocks if wrapped in ```json ... ```
            if raw.startswith("```"):
                raw = raw.split("\n", 1)[1].rsplit("```", 1)[0].strip()
            data = json.loads(raw)
            data["source"] = "gemini"
            data["raw_text"] = text
            return data
        except Exception as e:
            print(f"[GeminiService] Error during parse_intent: {e}")
            return None

    def evaluate_quiz_answer(self, question: str, expected_answer: str, user_answer: str) -> Optional[Dict[str, Any]]:
        """
        Uses Gemini to semantically evaluate student's verbal response against note content.
        """
        if not self.is_available():
            return None

        prompt = f"""
You are evaluating a visually impaired college student's spoken answer in an accessible study app.
Question: "{question}"
Ground Truth Note Content: "{expected_answer}"
Student's Spoken Answer: "{user_answer}"

Evaluate if the student's answer captures the essential meaning of the note.
Classify as: "Correct", "Partially correct", or "Incorrect".
Assign a score: 1.0 (Correct), 0.5 (Partially correct), 0.0 (Incorrect).
Provide a concise, encouraging spoken explanation grounded strictly in the note content.

Respond ONLY with valid JSON:
{{
  "result": "Correct" | "Partially correct" | "Incorrect",
  "score": 1.0 | 0.5 | 0.0,
  "feedback": "Concise ground truth explanation",
  "spoken_feedback": "Short encouraging spoken feedback starting with the result"
}}
"""
        try:
            response = self.client.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt,
            )
            raw = response.text.strip()
            if raw.startswith("```"):
                raw = raw.split("\n", 1)[1].rsplit("```", 1)[0].strip()
            return json.loads(raw)
        except Exception as e:
            print(f"[GeminiService] Error during evaluate_quiz_answer: {e}")
            return None

    def contextual_fuzzy_search(self, query: str, notes: List[Dict[str, Any]]) -> Optional[List[Dict[str, Any]]]:
        """
        Uses Gemini for contextual fuzzy retrieval against real user notes.
        Strict honesty: If no note matches, returns empty list.
        """
        if not self.is_available() or not notes:
            return None

        prompt = f"""
The user asked: "{query}"
Here are the user's stored notes:
{json.dumps([{"id": n["note_id"], "subject": n["subject"], "text": n["text"]} for n in notes])}

Identify which note IDs are relevant to the user query, ordered from most relevant to least.
If NONE of the notes are relevant, return an empty array []. Never invent or hallucinate relevance.

Respond ONLY with valid JSON:
{{"matched_ids": ["id1", "id2"]}}
"""
        try:
            response = self.client.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt,
            )
            raw = response.text.strip()
            if raw.startswith("```"):
                raw = raw.split("\n", 1)[1].rsplit("```", 1)[0].strip()
            data = json.loads(raw)
            matched_ids = data.get("matched_ids", [])
            
            # Map back to note dicts
            notes_by_id = {n["note_id"]: n for n in notes}
            matched_notes = [notes_by_id[nid] for nid in matched_ids if nid in notes_by_id]
            return matched_notes
        except Exception as e:
            print(f"[GeminiService] Error during contextual_fuzzy_search: {e}")
            return None

    def generate_mcq_quiz(self, topic: str, notes: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        """
        Generates 5 multiple-choice quiz questions based ONLY on the content of user notes.
        """
        if not self.is_available() or not notes:
            return None

        prompt = f"""
You are an accessible academic quiz generator for "Voice-First", an app for visually impaired college students.
Topic: "{topic}"
Notes from Student's SQLite Database:
{json.dumps([{"subject": n.get("subject", "General"), "tag": n.get("tag", "General"), "text": n["text"]} for n in notes])}

Generate EXACTLY 5 multiple-choice quiz questions based ONLY on the content of these notes.
Each question must contain:
- "question": clear question string
- "options": an array of 4 distinct options, e.g. ["A: ...", "B: ...", "C: ...", "D: ..."] (or option texts)
- "correct_answer": the letter of the correct option ("A", "B", "C", or "D")

Never hallucinate or include information outside these notes.

Respond ONLY with valid JSON in this exact structure:
{{
  "type": "quiz",
  "topic": "{topic}",
  "questions": [
    {{
      "question": "What is ...?",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_answer": "B"
    }}
  ]
}}
"""
        try:
            response = self.client.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt,
            )
            raw = response.text.strip()
            if raw.startswith("```"):
                raw = raw.split("\n", 1)[1].rsplit("```", 1)[0].strip()
            data = json.loads(raw)
            if "questions" in data and isinstance(data["questions"], list):
                data["type"] = "quiz"
                data["topic"] = topic
                return data
            return None
        except Exception as e:
            print(f"[GeminiService] Error during generate_mcq_quiz: {e}")
            return None

    def generate_flashcards(self, topic: str, notes: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        """
        Generates 8-10 flashcards as question/answer (front/back) pairs summarizing key concepts from notes.
        """
        if not self.is_available() or not notes:
            return None

        prompt = f"""
You are an accessible study flashcard generator for "Voice-First", an app for visually impaired college students.
Topic: "{topic}"
Notes from Student's SQLite Database:
{json.dumps([{"subject": n.get("subject", "General"), "tag": n.get("tag", "General"), "text": n["text"]} for n in notes])}

Generate between 8 and 10 flashcards as question/answer (front and back) pairs summarizing key concepts strictly from these notes.
Each card must contain:
- "front": Question, key term, or prompt
- "back": Concise, accurate explanation or definition directly from the notes

Never invent facts outside these notes.

Respond ONLY with valid JSON in this exact structure:
{{
  "type": "flashcards",
  "topic": "{topic}",
  "cards": [
    {{
      "front": "Front question or concept",
      "back": "Back answer or definition"
    }}
  ]
}}
"""
        try:
            response = self.client.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt,
            )
            raw = response.text.strip()
            if raw.startswith("```"):
                raw = raw.split("\n", 1)[1].rsplit("```", 1)[0].strip()
            data = json.loads(raw)
            if "cards" in data and isinstance(data["cards"], list):
                data["type"] = "flashcards"
                data["topic"] = topic
                return data
            return None
        except Exception as e:
            print(f"[GeminiService] Error during generate_flashcards: {e}")
            return None
