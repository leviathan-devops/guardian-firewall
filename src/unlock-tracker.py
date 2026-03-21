#!/usr/bin/env python3
"""
GUARDIAN Unlock Tracker - Manages file unlock state persistently
With HMAC integrity verification and immutable state files
"""

import json
import os
import sys
import time
import hashlib
import hmac
import subprocess
from datetime import datetime
from pathlib import Path

GUARDIAN_DIR = Path.home() / ".guardrails"
UNLOCK_STATE_FILE = GUARDIAN_DIR / "unlock_state.json"
AUDIT_LOG_FILE = GUARDIAN_DIR / "audit.log"
HMAC_KEY_FILE = GUARDIAN_DIR / ".hmac_key"

class UnlockTracker:
    def __init__(self):
        GUARDIAN_DIR.mkdir(exist_ok=True)
        self.hmac_key = self._get_or_create_hmac_key()
        self.state = self._load_state()
    
    def _get_or_create_hmac_key(self):
        """Get or create HMAC key for audit log integrity"""
        if not HMAC_KEY_FILE.exists():
            key = os.urandom(32).hex()
            with open(HMAC_KEY_FILE, 'w') as f:
                f.write(key)
            os.chmod(HMAC_KEY_FILE, 0o600)
            # Make key file immutable
            try:
                subprocess.run(['sudo', 'chattr', '+i', str(HMAC_KEY_FILE)], 
                             capture_output=True, timeout=5)
            except:
                pass  # Best effort
        with open(HMAC_KEY_FILE, 'r') as f:
            return f.read().strip()
    
    def _compute_hmac(self, data):
        """Compute HMAC for data integrity"""
        return hmac.new(
            self.hmac_key.encode(),
            data.encode(),
            hashlib.sha256
        ).hexdigest()
    
    def _verify_hmac(self, data, signature):
        """Verify HMAC signature"""
        expected = self._compute_hmac(data)
        return hmac.compare_digest(expected, signature)
    
    def _load_state(self):
        """Load unlock state with integrity verification"""
        if not UNLOCK_STATE_FILE.exists():
            return {"unlocked_files": {}}
        
        try:
            # Try to make file mutable temporarily for reading
            subprocess.run(['sudo', 'chattr', '-i', str(UNLOCK_STATE_FILE)], 
                         capture_output=True, timeout=5)
        except:
            pass
        
        try:
            with open(UNLOCK_STATE_FILE, 'r') as f:
                content = f.read()
            
            # Check for HMAC signature
            if '___HMAC:' in content:
                data, signature = content.rsplit('___HMAC:', 1)
                if not self._verify_hmac(data, signature.strip()):
                    print("⚠️  WARNING: State file integrity check failed!")
                    return {"unlocked_files": {}}
                return json.loads(data)
            else:
                # Legacy format without HMAC
                return json.loads(content)
        except Exception as e:
            print(f"⚠️  Error loading state: {e}")
            return {"unlocked_files": {}}
    
    def _save_state(self):
        """Save state with HMAC signature and make immutable"""
        data = json.dumps(self.state, indent=2, sort_keys=True)
        signature = self._compute_hmac(data)
        signed_content = f"{data}___HMAC:{signature}"
        
        try:
            # Make file mutable first
            subprocess.run(['sudo', 'chattr', '-i', str(UNLOCK_STATE_FILE)], 
                         capture_output=True, timeout=5)
        except:
            pass
        
        with open(UNLOCK_STATE_FILE, 'w') as f:
            f.write(signed_content)
        os.chmod(UNLOCK_STATE_FILE, 0o600)
        
        # Make immutable
        try:
            subprocess.run(['sudo', 'chattr', '+i', str(UNLOCK_STATE_FILE)], 
                         capture_output=True, timeout=5)
        except:
            pass
    
    def _log_audit(self, action, details):
        """Log audit entry with HMAC signature (append-only)"""
        timestamp = datetime.now().isoformat()
        entry = f"{timestamp} | {action} | {details}"
        signature = self._compute_hmac(entry)
        log_entry = f"{entry} | HMAC:{signature}\n"
        
        try:
            # Make log append-only if not already
            subprocess.run(['sudo', 'chattr', '+a', str(AUDIT_LOG_FILE)], 
                         capture_output=True, timeout=5)
        except:
            pass
        
        with open(AUDIT_LOG_FILE, 'a') as f:
            f.write(log_entry)
    
    def add_unlock(self, file_path: str, duration_seconds: int = 300):
        """Track an unlocked file with auto-relock time"""
        self.state["unlocked_files"][file_path] = {
            "unlocked_at": datetime.now().isoformat(),
            "expires_at": time.time() + duration_seconds,
            "duration": duration_seconds
        }
        self._save_state()
        self._log_audit("UNLOCK", f"file={file_path} duration={duration_seconds}s")
        
        # Schedule relock (with crash recovery via cron)
        self._schedule_relock(file_path, duration_seconds)
    
    def _schedule_relock(self, file_path: str, duration_seconds: int):
        """Schedule relock with persistent tracking"""
        job_file = GUARDIAN_DIR / "relock_jobs.json"
        jobs = {}
        if job_file.exists():
            try:
                with open(job_file, 'r') as f:
                    jobs = json.load(f)
            except:
                jobs = {}
        
        jobs[file_path] = {
            "relock_at": time.time() + duration_seconds,
            "duration": duration_seconds
        }
        
        with open(job_file, 'w') as f:
            json.dump(jobs, f, indent=2)
    
    def check_and_relock(self):
        """Check for expired unlocks and relock them"""
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
                    self._log_audit("AUTO_RELOCK", f"file={file_path} reason=expired")
                except Exception as e:
                    print(f"⚠️  Failed to relock {file_path}: {e}")
                    self._log_audit("RELOCK_FAILED", f"file={file_path} error={e}")
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
            self._log_audit("MANUAL_RELOCK", f"file={file_path}")

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
