#!/usr/bin/env python3
"""
GUARDIAN Unlock Tracker - Manages file unlock state persistently
"""

import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

GUARDIAN_DIR = Path.home() / ".guardrails"
UNLOCK_STATE_FILE = GUARDIAN_DIR / "unlock_state.json"

class UnlockTracker:
    def __init__(self):
        GUARDIAN_DIR.mkdir(exist_ok=True)
        self.state = self._load_state()
    
    def _load_state(self):
        if UNLOCK_STATE_FILE.exists():
            with open(UNLOCK_STATE_FILE, 'r') as f:
                return json.load(f)
        return {"unlocked_files": {}}
    
    def _save_state(self):
        with open(UNLOCK_STATE_FILE, 'w') as f:
            json.dump(self.state, f, indent=2)
    
    def add_unlock(self, file_path: str, duration_seconds: int = 300):
        """Track an unlocked file with auto-relock time"""
        import subprocess
        self.state["unlocked_files"][file_path] = {
            "unlocked_at": datetime.now().isoformat(),
            "expires_at": time.time() + duration_seconds,
            "duration": duration_seconds
        }
        self._save_state()
        
        # Schedule relock (with crash recovery)
        self._schedule_relock(file_path, duration_seconds)
    
    def _schedule_relock(self, file_path: str, duration_seconds: int):
        """Schedule relock with persistent tracking"""
        # Write a cron-style job file
        job_file = GUARDIAN_DIR / "relock_jobs.json"
        jobs = {}
        if job_file.exists():
            with open(job_file, 'r') as f:
                jobs = json.load(f)
        
        jobs[file_path] = {
            "relock_at": time.time() + duration_seconds,
            "duration": duration_seconds
        }
        
        with open(job_file, 'w') as f:
            json.dump(jobs, f, indent=2)
    
    def check_and_relock(self):
        """Check for expired unlocks and relock them"""
        import subprocess
        current_time = time.time()
        expired = []
        
        for file_path, info in list(self.state["unlocked_files"].items()):
            if info["expires_at"] < current_time:
                expired.append(file_path)
                # Relock the file
                try:
                    subprocess.run(['sudo', 'chattr', '+i', file_path], 
                                 capture_output=True, timeout=10)
                    print(f"🔒 Auto-relocked: {file_path}")
                except Exception as e:
                    print(f"⚠️  Failed to relock {file_path}: {e}")
                del self.state["unlocked_files"][file_path]
        
        if expired:
            self._save_state()
        
        return expired
    
    def get_unlocked_files(self):
        """Get list of currently unlocked files"""
        return list(self.state["unlocked_files"].keys())
    
    def clear_unlock(self, file_path: str):
        """Manually clear an unlock (file was relocked)"""
        if file_path in self.state["unlocked_files"]:
            del self.state["unlocked_files"][file_path]
            self._save_state()

def main():
    tracker = UnlockTracker()
    
    if len(sys.argv) < 2:
        print("Usage: unlock-tracker <command> [args]")
        print("Commands:")
        print("  add <file> [duration]  - Track unlock")
        print("  check                  - Check and relock expired")
        print("  list                   - List unlocked files")
        print("  clear <file>           - Clear unlock tracking")
        return
    
    command = sys.argv[1]
    
    if command == "add" and len(sys.argv) >= 3:
        file_path = sys.argv[2]
        duration = int(sys.argv[3]) if len(sys.argv) > 3 else 300
        tracker.add_unlock(file_path, duration)
        print(f"✅ Tracking unlock: {file_path} for {duration}s")
    
    elif command == "check":
        expired = tracker.check_and_relock()
        if not expired:
            print("✅ All unlocks valid")
        else:
            print(f"🔒 Relocked {len(expired)} files")
    
    elif command == "list":
        files = tracker.get_unlocked_files()
        if files:
            print("Unlocked files:")
            for f in files:
                print(f"  - {f}")
        else:
            print("No files currently unlocked")
    
    elif command == "clear" and len(sys.argv) >= 3:
        tracker.clear_unlock(sys.argv[2])
        print(f"✅ Cleared unlock tracking for {sys.argv[2]}")
    
    else:
        print(f"Unknown command: {command}")

if __name__ == "__main__":
    main()
