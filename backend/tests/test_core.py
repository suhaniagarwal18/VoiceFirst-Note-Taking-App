import os
import pytest
import tempfile
import json
from datetime import datetime

# Set temporary database for testing before importing app
temp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
os.environ["DATABASE_FILE"] = temp_db.name

import database
from app import app
from services.intent_parser import IntentParser
from services.note_service import NoteService
from services.correction_service import CorrectionService
from services.search_service import SearchService

@pytest.fixture(autouse=True)
def setup_and_teardown():
    database.init_db()
    yield
    # Clean up tables between tests in foreign key order
    conn = database.get_db_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM correction_history")
    cursor.execute("DELETE FROM bookmarks")
    cursor.execute("DELETE FROM flashcards")
    cursor.execute("DELETE FROM quiz_history")
    cursor.execute("DELETE FROM weak_topics")
    cursor.execute("DELETE FROM notes")
    cursor.execute("DELETE FROM sessions")
    conn.commit()
    conn.close()

@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

# -------------------------------------------------------------------------
# 1. Intent Parsing Tests
# -------------------------------------------------------------------------
def test_intent_parsing_core():
    parser = IntentParser()

    # Start lecture
    p1 = parser.parse("Start Biology lecture.")
    assert p1["intent"] == "START_LECTURE"
    assert p1["entities"]["subject"].lower() == "biology"

    # Note capture
    p2 = parser.parse("Note: Mitosis is the process of cell division.")
    assert p2["intent"] == "CREATE_NOTE"
    assert p2["entities"]["content"] == "Mitosis is the process of cell division."

    # Tagging
    p3 = parser.parse("Tag this as important.")
    assert p3["intent"] == "TAG_NOTE"
    assert p3["entities"]["tag"] == "Important"

    p3b = parser.parse("Tag last note as definition")
    assert p3b["intent"] == "TAG_NOTE"
    assert p3b["entities"]["tag"] == "Definition"

    # Permutations of tagging commands
    assert parser.parse("mark this as definition")["intent"] == "TAG_NOTE"
    assert parser.parse("mark this as definition")["entities"]["tag"] == "Definition"

    assert parser.parse("mark this as a definition")["intent"] == "TAG_NOTE"
    assert parser.parse("mark this as a definition")["entities"]["tag"] == "Definition"

    assert parser.parse("tag this note as definition")["intent"] == "TAG_NOTE"
    assert parser.parse("tag this note as definition")["entities"]["tag"] == "Definition"

    assert parser.parse("mark this important")["intent"] == "TAG_NOTE"
    assert parser.parse("mark this important")["entities"]["tag"] == "Important"

    assert parser.parse("mark this note important")["intent"] == "TAG_NOTE"
    assert parser.parse("mark this note important")["entities"]["tag"] == "Important"

    assert parser.parse("mark as important")["intent"] == "TAG_NOTE"
    assert parser.parse("tag important")["intent"] == "TAG_NOTE"
    assert parser.parse("mark definition")["intent"] == "TAG_NOTE"
    assert parser.parse("tag as example")["intent"] == "TAG_NOTE"
    assert parser.parse("tag note as important")["intent"] == "TAG_NOTE"
    assert parser.parse("bookmark this note")["intent"] == "BOOKMARK_NOTE"
    assert parser.parse("stop recording")["intent"] == "END_LECTURE"
    assert parser.parse("end class")["intent"] == "END_LECTURE"
    assert parser.parse("start Chemistry class")["intent"] == "START_LECTURE"

    # Correction
    p4 = parser.parse("Correct decision to division.")
    assert p4["intent"] == "CORRECT_NOTE_REPLACE"
    assert p4["entities"]["target"] == "decision"
    assert p4["entities"]["replacement"] == "division"

    # Search
    p5 = parser.parse("Find my notes about photosynthesis.")
    assert p5["intent"] == "SEARCH_NOTES"
    assert p5["entities"]["query"] == "photosynthesis"

    # Audio navigation
    assert parser.parse("Next.")["intent"] == "AUDIO_NEXT"
    assert parser.parse("Previous.")["intent"] == "AUDIO_PREVIOUS"
    assert parser.parse("Repeat.")["intent"] == "AUDIO_REPEAT"
    assert parser.parse("Stop.")["intent"] == "AUDIO_STOP"
    assert parser.parse("Help.")["intent"] == "HELP"
    assert parser.parse("End lecture.")["intent"] == "END_LECTURE"

# -------------------------------------------------------------------------
# 2. Note Creation & Auto-Tagging Tests
# -------------------------------------------------------------------------
def test_note_creation_and_autotagging():
    user_id = "test_student"
    
    # Auto-tag definition
    note1 = NoteService.create_note(user_id, "Mitosis is the process of cell division.", subject="Biology")
    assert note1["tag"] == "Definition"
    assert note1["subject"] == "Biology"

    # Auto-tag example
    note2 = NoteService.create_note(user_id, "For example, skin cells reproduce through mitosis.", subject="Biology")
    assert note2["tag"] == "Example"

    # Explicit tag override
    note3 = NoteService.create_note(user_id, "Standard lecture point", subject="Biology", explicit_tag="Important")
    assert note3["tag"] == "Important"

    # Tag update on note
    updated = NoteService.update_tag(note3["note_id"], "Definition")
    assert updated["tag"] == "Definition"

# -------------------------------------------------------------------------
# 3. Voice Correction Flow & History Tests
# -------------------------------------------------------------------------
def test_voice_correction_flow():
    user_id = "test_student"
    note = NoteService.create_note(user_id, "Mitosis is the process of cell decision.", subject="Biology")
    
    # Correct word
    success, speech, updated = CorrectionService.correct_word_replacement(user_id, "decision", "division")
    assert success is True
    assert updated["text"] == "Mitosis is the process of cell division."
    assert "The note now says: Mitosis is the process of cell division." in speech

    # Check history log
    history = CorrectionService.get_correction_history(note["note_id"])
    assert len(history) == 1
    assert history[0]["original_text"] == "Mitosis is the process of cell decision."
    assert history[0]["corrected_text"] == "Mitosis is the process of cell division."

    # Error handling when word is missing
    fail_success, fail_speech, _ = CorrectionService.correct_word_replacement(user_id, "nonexistent", "replacement")
    assert fail_success is False
    assert "couldn't find nonexistent" in fail_speech

# -------------------------------------------------------------------------
# 4. Search and Ranked Retrieval Tests
# -------------------------------------------------------------------------
def test_search_and_ranked_retrieval():
    user_id = "test_student"
    NoteService.create_note(user_id, "General note about plants", subject="Botany")
    NoteService.create_note(user_id, "Photosynthesis converts light energy into chemical energy.", subject="Biology", explicit_tag="Definition")
    NoteService.create_note(user_id, "Chlorophyll is the pigment in photosynthesis.", subject="Biology", explicit_tag="Important")

    results = SearchService.search_notes(user_id, "photosynthesis")
    assert len(results) == 2
    # The important/definition ones rank first
    assert "photosynthesis" in results[0]["text"].lower()

    # Spoken summary
    speech = SearchService.format_search_speech(results, "photosynthesis", index=0)
    assert "Found 2 notes about photosynthesis" in speech
    assert "Note 1 of 2" in speech

# -------------------------------------------------------------------------
# 5. Full Canonical Core End-to-End Voice Flow via API
# -------------------------------------------------------------------------
def test_canonical_core_voice_workflow(client):
    user_id = "test_student"

    # Step 1: "Start Biology lecture."
    r1 = client.post("/api/voice/process", json={"user_id": user_id, "text": "Start Biology lecture."})
    d1 = r1.get_json()
    assert d1["intent"] == "START_LECTURE"
    assert "Started Biology lecture" in d1["spoken_response"]
    context = d1["context"]
    assert context["current_mode"] == "active_lecture"
    assert context["current_subject"] == "Biology"

    # Step 2: "Note: Mitosis is the process of cell decision." (Captured silently during lecture)
    r2 = client.post("/api/voice/process", json={"user_id": user_id, "text": "Note: Mitosis is the process of cell decision.", "context": context})
    d2 = r2.get_json()
    assert d2["intent"] == "CREATE_NOTE"
    assert d2["spoken_response"] == "" # Silent capture during active lecture (no echo / no interrupt)
    context = d2["context"]

    # Step 3: "Tag this as important." or "mark this important"
    r3 = client.post("/api/voice/process", json={"user_id": user_id, "text": "mark this important", "context": context})
    d3 = r3.get_json()
    assert d3["intent"] == "TAG_NOTE"
    assert "Tagged as Important." in d3["spoken_response"]

    # Step 4: "Correct decision to division."
    r4 = client.post("/api/voice/process", json={"user_id": user_id, "text": "Correct decision to division.", "context": context})
    d4 = r4.get_json()
    assert d4["intent"] == "CORRECT_NOTE_REPLACE"
    assert "The note now says: Mitosis is the process of cell division." in d4["spoken_response"]
    context = d4["context"]

    # Step 5: "Find my notes about cell division."
    r5 = client.post("/api/voice/process", json={"user_id": user_id, "text": "Find my notes about cell division.", "context": context})
    d5 = r5.get_json()
    assert d5["intent"] == "SEARCH_NOTES"
    assert "Found 1 note about cell division" in d5["spoken_response"]
    context = d5["context"]
    assert context["current_mode"] == "retrieval"

    # Step 6: "Stop."
    r6 = client.post("/api/voice/process", json={"user_id": user_id, "text": "Stop.", "context": context})
    d6 = r6.get_json()
    assert d6["intent"] == "AUDIO_STOP"
    assert d6["spoken_response"] == "Stopped."

    # Step 7: "End lecture."
    r7 = client.post("/api/voice/process", json={"user_id": user_id, "text": "End lecture.", "context": context})
    d7 = r7.get_json()
    assert d7["intent"] == "END_LECTURE"
    assert "Biology lecture ended. Total 1 notes saved." in d7["spoken_response"]
