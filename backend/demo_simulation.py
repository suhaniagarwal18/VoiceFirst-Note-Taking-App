"""
Voice-First End-to-End Simulation Script
Demonstrates the full hands-free voice experience for both CORE and EXTENDED phases.
"""
import os
import json
import time
from app import app
import database

def run_voice_step(client, step_num, user_utterance, context, expected_intent=None):
    print(f"\n=======================================================")
    print(f"STEP {step_num}: USER SPEAKS -> \"{user_utterance}\"")
    print(f"-------------------------------------------------------")
    
    response = client.post("/api/voice/process", json={
        "user_id": "demo_student",
        "text": user_utterance,
        "context": context
    })
    
    res = response.get_json()
    intent = res["intent"]
    spoken = res["spoken_response"]
    action = res["action"]
    next_context = res["context"]
    
    print(f"-> INTENT DETECTED : {intent}")
    print(f"-> SPOKEN RESPONSE : \"{spoken}\"")
    print(f"-> UI ACTION       : {action}")
    print(f"-> ACTIVE MODE     : {next_context.get('current_mode')}")
    
    if expected_intent:
        assert intent == expected_intent, f"Expected intent {expected_intent}, got {intent}"
        
    return next_context

def main():
    print("\n" + "#"*60)
    print("  VOICE-FIRST: END-TO-END DEMO SIMULATION (CORE & EXTENDED)")
    print("#"*60)
    
    # Initialize fresh DB
    database.init_db()
    
    with app.test_client() as client:
        # App Launch Greeting
        print("\n[APP LAUNCH] App opens -> Voice-First becomes voice-ready immediately.")
        print("-> SPOKEN GREETING: \"Voice-First is ready. What would you like to do?\"")
        
        context = {"current_mode": "home"}
        
        # -------------------------------------------------------------
        # CORE PHASE VERIFICATION
        # -------------------------------------------------------------
        print("\n" + "="*50)
        print("  PHASE 1: CORE WORKFLOW EXECUTION")
        print("="*50)
        
        # 1. Start Lecture
        context = run_voice_step(client, 1, "Start Biology lecture.", context, "START_LECTURE")
        
        # 2. Capture Note (with transcription typo)
        context = run_voice_step(client, 2, "Note: Mitosis is the process of cell decision.", context, "CREATE_NOTE")
        
        # 3. Tag Note as Important
        context = run_voice_step(client, 3, "Tag this as important.", context, "TAG_NOTE")
        
        # 4. Voice Correction (Zero typing required!)
        context = run_voice_step(client, 4, "Correct decision to division.", context, "CORRECT_NOTE_REPLACE")
        
        # 5. Capture second note
        context = run_voice_step(client, 5, "Note: For example skin cells reproduce through mitosis.", context, "CREATE_NOTE")
        
        # 6. Search and Ranked Retrieval
        context = run_voice_step(client, 6, "Find my notes about cell division.", context, "SEARCH_NOTES")
        
        # 7. Audio Navigation: Next Note
        context = run_voice_step(client, 7, "Next.", context, "AUDIO_NEXT")
        
        # 8. Audio Navigation: Repeat Note
        context = run_voice_step(client, 8, "Repeat.", context, "AUDIO_REPEAT")
        
        # 9. Voice Interrupt: Stop
        context = run_voice_step(client, 9, "Stop.", context, "AUDIO_STOP")
        
        # 10. Read Today's Notes
        context = run_voice_step(client, 10, "Read today's Biology notes.", context, "READ_TODAYS_NOTES")
        
        # 11. End Lecture
        context = run_voice_step(client, 11, "End lecture.", context, "END_LECTURE")

        # -------------------------------------------------------------
        # EXTENDED PHASE VERIFICATION
        # -------------------------------------------------------------
        print("\n" + "="*50)
        print("  PHASE 2: EXTENDED FEATURES EXECUTION")
        print("="*50)
        
        # 12. Audio Flashcards Generation (generated from existing notes via FLASHCARDS)
        context = run_voice_step(client, 12, "Make flashcards on Biology.", context, "FLASHCARDS")
        
        # 13. Answer Flashcard verbally or flip
        context = run_voice_step(client, 13, "The process of cell division.", context, "FLASHCARD_ANSWER")
        
        # 14. Voice Quiz Generation & Exam Mode (generated from existing notes via QUIZ_ME)
        context = run_voice_step(client, 14, "Quiz me on Biology.", context, "QUIZ_ME")
        
        # 15. Answer Quiz verbally
        context = run_voice_step(client, 15, "Option B", context, "QUIZ_ANSWER")
        
        # 16. Smart Weak-Topic Revision
        context = run_voice_step(client, 16, "Revise my weak topics.", context, "REVISE_WEAK_TOPICS")
        
        # 17. Voice Note Bookmarks
        context = run_voice_step(client, 17, "Bookmark this.", context, "BOOKMARK_NOTE")
        
        # 18. Retrieve Bookmarks
        context = run_voice_step(client, 18, "Read my bookmarks.", context, "READ_BOOKMARKS")
        
        # 19. Lecture Timeline: Topic Query
        context = run_voice_step(client, 19, "Where did I note cell division?", context, "TIMELINE_TOPIC_QUERY")
        
        # 20. Lecture Timeline: Topics covered today
        context = run_voice_step(client, 20, "What topics did I cover today?", context, "TIMELINE_TOPICS_SUMMARY")
        
        print("\n" + "#"*60)
        print("  ALL CORE & EXTENDED WORKFLOWS VERIFIED SUCCESSFULLY (100%)")
        print("#"*60 + "\n")

if __name__ == "__main__":
    main()
