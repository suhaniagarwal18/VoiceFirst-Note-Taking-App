import sqlite3
import os
import json
from datetime import datetime

def get_db_connection():
    db_file = os.environ.get("DATABASE_FILE", os.path.join(os.path.dirname(__file__), "voice_first.db"))
    conn = sqlite3.connect(db_file, timeout=30.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()

    # Sessions table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS sessions (
        session_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        subject TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
    )
    """)

    # Notes table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS notes (
        note_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        session_id TEXT,
        subject TEXT NOT NULL,
        text TEXT NOT NULL,
        tag TEXT NOT NULL CHECK(tag IN ('Definition', 'Example', 'Important', 'General')),
        timestamp TEXT NOT NULL,
        confidence REAL DEFAULT 1.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions(session_id)
    )
    """)

    # Correction history table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS correction_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id TEXT NOT NULL,
        original_text TEXT NOT NULL,
        corrected_text TEXT NOT NULL,
        correction_timestamp TEXT NOT NULL,
        change_reason TEXT,
        FOREIGN KEY (note_id) REFERENCES notes(note_id)
    )
    """)

    # Bookmarks table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS bookmarks (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        label TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (note_id) REFERENCES notes(note_id)
    )
    """)

    # Flashcards table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS flashcards (
        id TEXT PRIMARY KEY,
        source_note_id TEXT,
        user_id TEXT NOT NULL,
        subject TEXT NOT NULL,
        tag TEXT,
        question TEXT NOT NULL,
        answer TEXT NOT NULL,
        difficulty TEXT DEFAULT 'Medium' CHECK(difficulty IN ('Easy', 'Medium', 'Hard')),
        review_count INTEGER DEFAULT 0,
        correct_count INTEGER DEFAULT 0,
        last_reviewed_at TEXT,
        FOREIGN KEY (source_note_id) REFERENCES notes(note_id)
    )
    """)

    # Quiz history table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS quiz_history (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        session_id TEXT,
        subject TEXT,
        question TEXT NOT NULL,
        user_spoken_answer TEXT,
        evaluation_result TEXT CHECK(evaluation_result IN ('Correct', 'Partially correct', 'Incorrect')),
        feedback TEXT,
        score REAL DEFAULT 0.0,
        timestamp TEXT NOT NULL,
        weakness_flag INTEGER DEFAULT 0
    )
    """)

    # Weak topics table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS weak_topics (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        topic TEXT NOT NULL,
        subject TEXT,
        error_count INTEGER DEFAULT 1,
        last_error_at TEXT NOT NULL,
        is_resolved INTEGER DEFAULT 0
    )
    """)

    # User settings table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_settings (
        user_id TEXT PRIMARY KEY,
        speech_rate REAL DEFAULT 1.0,
        speech_pitch REAL DEFAULT 1.0,
        speech_volume REAL DEFAULT 1.0,
        spoken_confirmation INTEGER DEFAULT 1,
        gemini_enabled INTEGER DEFAULT 1,
        updated_at TEXT NOT NULL
    )
    """)

    conn.commit()
    conn.close()

if __name__ == "__main__":
    init_db()
    print("Database initialized successfully.")
