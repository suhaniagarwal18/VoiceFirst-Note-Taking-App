import os
import pytest
import tempfile
from datetime import datetime

# Use shared test db
temp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
os.environ["DATABASE_FILE"] = temp_db.name

import database
from app import app
from services.note_service import NoteService
from services.flashcard_service import FlashcardService
from services.quiz_service import QuizService
from services.bookmark_service import BookmarkService
from services.timeline_service import TimelineService

@pytest.fixture(autouse=True)
def setup_and_teardown():
    database.init_db()
    yield
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

def test_flashcards_generation_and_review():
    user_id = "student_ext"
    # Create notes
    NoteService.create_note(user_id, "Mitosis is the process of cell division.", subject="Biology", explicit_tag="Definition")
    NoteService.create_note(user_id, "Glycolysis is the breakdown of glucose.", subject="Biology", explicit_tag="Definition")

    # Generate flashcards
    cards = FlashcardService.generate_flashcards_from_notes(user_id, subject="Biology")
    assert len(cards) == 2
    assert "What is Mitosis?" in cards[0]["question"] or "What is Glycolysis?" in cards[0]["question"]

    # Review card
    card_id = cards[0]["id"]
    FlashcardService.record_review(card_id, is_correct=True, difficulty="Easy")
    
    updated_cards = FlashcardService.get_flashcards(user_id, subject="Biology")
    card_dict = next(c for c in updated_cards if c["id"] == card_id)
    assert card_dict["difficulty"] == "Easy"
    assert card_dict["review_count"] == 1
    assert card_dict["correct_count"] == 1

def test_voice_quiz_and_weakness_tracking():
    user_id = "student_ext"
    NoteService.create_note(user_id, "Photosynthesis converts sunlight into glucose.", subject="Biology", explicit_tag="Definition")
    NoteService.create_note(user_id, "Mitochondria is the powerhouse of the cell.", subject="Biology", explicit_tag="Definition")

    quiz = QuizService.generate_quiz(user_id)
    assert len(quiz) == 2

    # Evaluate correct spoken answer
    eval_correct = QuizService.evaluate_spoken_answer(quiz[0], "It converts sunlight into glucose")
    assert eval_correct["result"] in ["Correct", "Partially correct"]
    assert eval_correct["score"] > 0

    # Evaluate incorrect spoken answer
    eval_incorrect = QuizService.evaluate_spoken_answer(quiz[1], "I don't know")
    assert eval_incorrect["result"] == "Incorrect"
    assert eval_incorrect["score"] == 0.0

    # Record answer & track weak topic
    QuizService.record_quiz_answer(user_id, quiz[1], "I don't know", eval_incorrect)
    weaks = QuizService.get_weak_topics(user_id)
    assert len(weaks) >= 1

def test_voice_bookmarks():
    user_id = "student_ext"
    note = NoteService.create_note(user_id, "Crucial exam question on cellular respiration.", subject="Biology", explicit_tag="Important")

    # Bookmark note
    res = BookmarkService.add_bookmark(user_id, note_id=note["note_id"], label="Exam Priority")
    assert res["success"] is True

    # Retrieve bookmarks
    bms = BookmarkService.get_bookmarks(user_id)
    assert len(bms) == 1
    assert bms[0]["text"] == "Crucial exam question on cellular respiration."

def test_lecture_timeline_queries():
    user_id = "student_ext"
    note = NoteService.create_note(user_id, "The enzyme RuBisCO fixes carbon dioxide in photosynthesis.", subject="Biology", explicit_tag="Important")

    # Query topic time
    res = TimelineService.query_topic_time(user_id, "RuBisCO")
    assert res["found"] is True
    assert "You noted RuBisCO" in res["speech"]
    assert note["timestamp"] in res["speech"]

    # Query today topics summary
    summary = TimelineService.get_today_topics_summary(user_id)
    assert summary["found"] is True
    assert "Biology" in summary["speech"]

    # Honest query for missing topic
    missing = TimelineService.query_topic_time(user_id, "quantum computing")
    assert missing["found"] is False
    assert "couldn't find any mention" in missing["speech"]

def test_extended_voice_api_flows(client):
    user_id = "student_ext"
    NoteService.create_note(user_id, "Osmosis is the diffusion of water across a semipermeable membrane.", subject="Biology", explicit_tag="Definition")

    # Voice Flashcards
    r1 = client.post("/api/voice/process", json={"user_id": user_id, "text": "Make flashcards on Biology."})
    d1 = r1.get_json()
    assert d1["intent"] == "FLASHCARDS"
    assert "flashcards on Biology" in d1["spoken_response"]
    context = d1["context"]
    assert context["current_mode"] == "flashcard_active"
    assert len(d1["data"]["cards"]) >= 8

    # Voice Bookmark
    r2 = client.post("/api/voice/process", json={"user_id": user_id, "text": "Bookmark this.", "context": context})
    d2 = r2.get_json()
    assert d2["intent"] == "BOOKMARK_NOTE"
    assert "Bookmarked" in d2["spoken_response"]

    # Voice Timeline query
    r3 = client.post("/api/voice/process", json={"user_id": user_id, "text": "Where did I note Osmosis?", "context": context})
    d3 = r3.get_json()
    assert d3["intent"] == "TIMELINE_TOPIC_QUERY"
    assert "you noted osmosis" in d3["spoken_response"].lower()

def test_quiz_me_and_flashcard_generation_features(client):
    user_id = "student_quiz_fc"
    NoteService.create_note(user_id, "Mitochondria generates most of the chemical energy needed by the cell.", subject="Biology", explicit_tag="Definition")
    NoteService.create_note(user_id, "ATP is the primary energy currency of the cell.", subject="Biology", explicit_tag="Important")

    # 1. QUIZ_ME Intent
    r_quiz = client.post("/api/voice/process", json={"user_id": user_id, "text": "Quiz me on Biology."})
    d_quiz = r_quiz.get_json()
    assert d_quiz["intent"] == "QUIZ_ME"
    assert "Here are 5 quiz questions on Biology" in d_quiz["spoken_response"]
    assert d_quiz["data"]["type"] == "quiz"
    assert len(d_quiz["data"]["questions"]) == 5
    for q in d_quiz["data"]["questions"]:
        assert "question" in q
        assert len(q["options"]) == 4
        assert q["correct_answer"] in ["A", "B", "C", "D"]

    # 2. QUIZ_ME on non-existent topic
    r_empty_quiz = client.post("/api/voice/process", json={"user_id": user_id, "text": "Quiz me on Astronomy."})
    d_empty_quiz = r_empty_quiz.get_json()
    assert "No notes found for Astronomy" in d_empty_quiz["spoken_response"]

    # 3. FLASHCARDS Intent
    r_fc = client.post("/api/voice/process", json={"user_id": user_id, "text": "Give me flashcards for Biology."})
    d_fc = r_fc.get_json()
    assert d_fc["intent"] == "FLASHCARDS"
    assert "flashcards on Biology" in d_fc["spoken_response"]
    assert d_fc["data"]["type"] == "flashcards"
    assert len(d_fc["data"]["cards"]) >= 8
    for c in d_fc["data"]["cards"]:
        assert "front" in c
        assert "back" in c

    # 4. FLASHCARDS on non-existent topic
    r_empty_fc = client.post("/api/voice/process", json={"user_id": user_id, "text": "Make flashcards on Astrophysics."})
    d_empty_fc = r_empty_fc.get_json()
    assert "No notes found for Astrophysics" in d_empty_fc["spoken_response"]

    # 5. REST Endpoints
    r_api_quiz = client.post("/api/quiz/generate", json={"user_id": user_id, "topic": "Biology"})
    assert r_api_quiz.status_code == 200
    assert r_api_quiz.get_json()["type"] == "quiz"
    assert len(r_api_quiz.get_json()["questions"]) == 5

    r_api_fc = client.post("/api/flashcards/generate", json={"user_id": user_id, "topic": "Biology"})
    assert r_api_fc.status_code == 200
    assert r_api_fc.get_json()["type"] == "flashcards"
    assert len(r_api_fc.get_json()["cards"]) >= 8
