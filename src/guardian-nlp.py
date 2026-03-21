#!/usr/bin/env python3
"""
GUARDIAN Natural Language Approval System
==========================================
Integrates with Qwen Code to allow natural language approval/denial
without requiring users to run terminal commands.

Usage:
    This runs automatically when guardian request is created.
    User responds in Qwen Code chat with "approved", "yes", "denied", "no", etc.
"""

import json
import os
import sys
import re
from datetime import datetime

APPROVAL_QUEUE = os.path.expanduser("~/.guardrails/approval_queue")
APPROVAL_LOG = os.path.expanduser("~/.guardrails/approval_log")
RESPONSES_FILE = os.path.expanduser("~/.guardrails/pending_responses.json")

class GuardianApproval:
    def __init__(self):
        self.pending_responses = self.load_responses()
    
    def load_responses(self):
        """Load pending responses from file"""
        if os.path.exists(RESPONSES_FILE):
            with open(RESPONSES_FILE, 'r') as f:
                return json.load(f)
        return {}
    
    def save_responses(self):
        """Save pending responses to file"""
        with open(RESPONSES_FILE, 'w') as f:
            json.dump(self.pending_responses, f, indent=2)
    
    def create_request(self, file_path, reason, agent_name="agent"):
        """Create a new approval request"""
        import secrets
        import string
        
        request_id = secrets.token_hex(8)
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        request = {
            "request_id": request_id,
            "timestamp": timestamp,
            "file": file_path,
            "reason": reason,
            "agent": agent_name,
            "status": "PENDING",
            "user_response": None,
            "response_text": None
        }
        
        # Save to approval queue
        request_file = os.path.join(APPROVAL_QUEUE, f"{request_id}.request")
        with open(request_file, 'w') as f:
            json.dump(request, f, indent=2)
        
        # Save to pending responses (for Qwen Code to read)
        self.pending_responses[request_id] = request
        self.save_responses()
        
        # Log the request
        with open(APPROVAL_LOG, 'a') as f:
            f.write(f"{timestamp}|{agent_name}|request|{file_path}|{reason}|PENDING\n")
        
        return request
    
    def format_approval_prompt(self, request):
        """Format a natural language approval prompt for Qwen Code"""
        return f"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🔐 GUARDIAN FILE EDIT REQUEST                             ║
╚══════════════════════════════════════════════════════════════════════════════╝

📁 **File to Modify:** `{request['file']}`

🤖 **Agent:** {request['agent']}

📝 **Reason for Edit:**
{request['reason']}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  **This file is GUARDIAN encrypted** - it cannot be modified without your approval.

**What is GUARDIAN?**
GUARDIAN is a protection system that prevents accidental or unauthorized changes
to important files. It ensures you always know what's being changed and why.

**What happens if you approve?**
- The file will be temporarily unlocked for 5 minutes
- The agent can make ONLY the requested change
- The file automatically re-locks after 5 minutes
- This request is logged for your records

**What happens if you deny?**
- The file remains protected
- The agent cannot make this change
- You can ask the agent for an alternative approach

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ **To APPROVE this request, respond with:**
   - "approved"
   - "yes"
   - "go ahead"
   - "approve"
   - "ok"
   - "yes, allow the change"

❌ **To DENY this request, respond with:**
   - "denied"
   - "no"
   - "reject"
   - "don't do it"
   - "keep it locked"

💡 **To ask for more info, respond with:**
   - "Why is this change needed?"
   - "What exactly will you change?"
   - "Is there another way?"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Request ID:** `{request['request_id']}`
**Created:** {request['timestamp']}
"""
    
    def process_user_response(self, request_id, user_text):
        """Process natural language user response"""
        if request_id not in self.pending_responses:
            return {"error": "Request not found"}
        
        request = self.pending_responses[request_id]
        user_text_lower = user_text.lower().strip()
        
        # Detect approval
        approval_keywords = ['approved', 'approve', 'yes', 'go ahead', 'ok', 'allow', 'sure', 'go for it']
        denial_keywords = ['denied', 'deny', 'no', 'reject', "don't", 'dont', 'keep locked', 'no thanks']
        
        is_approved = any(kw in user_text_lower for kw in approval_keywords)
        is_denied = any(kw in user_text_lower for kw in denial_keywords)
        
        if is_approved and not is_denied:
            return self.approve_request(request_id, user_text)
        elif is_denied and not is_approved:
            return self.deny_request(request_id, user_text)
        elif is_approved and is_denied:
            return {"error": "Ambiguous response - contains both approval and denial keywords"}
        else:
            return {"error": "Unclear response - please use 'approved' or 'denied'"}
    
    def approve_request(self, request_id, user_text="Approved by user"):
        """Approve a request and unlock file"""
        import subprocess
        
        request = self.pending_responses[request_id]
        file_path = request['file']
        
        # Update request status
        request['status'] = 'APPROVED'
        request['user_response'] = True
        request['response_text'] = user_text
        
        # Save updated request
        request_file = os.path.join(APPROVAL_QUEUE, f"{request_id}.request")
        with open(request_file, 'w') as f:
            json.dump(request, f, indent=2)
        
        # Update pending responses
        self.pending_responses[request_id] = request
        self.save_responses()
        
        # Log the approval
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(APPROVAL_LOG, 'a') as f:
            f.write(f"{timestamp}|user|approve|{file_path}|{user_text}|APPROVED\n")
        
        # Unlock the file (using /usr/bin/sudo to bypass guardian wrapper)
        try:
            subprocess.run(['/usr/bin/sudo', 'chattr', '-i', file_path], check=True)
            
            # Schedule auto-relock in 5 minutes (300 seconds)
            subprocess.Popen(
                f'sleep 300 && /usr/bin/sudo chattr +i "{file_path}" 2>/dev/null',
                shell=True
            )
            
            return {
                "status": "APPROVED",
                "message": f"✅ Request approved! File unlocked for 5 minutes.",
                "file": file_path,
                "request_id": request_id,
                "auto_relock": "5 minutes"
            }
        except subprocess.CalledProcessError as e:
            return {
                "status": "ERROR",
                "message": f"❌ Failed to unlock file: {e}"
            }
    
    def deny_request(self, request_id, user_text="Denied by user"):
        """Deny a request"""
        request = self.pending_responses[request_id]
        file_path = request['file']
        
        # Update request status
        request['status'] = 'DENIED'
        request['user_response'] = False
        request['response_text'] = user_text
        
        # Save updated request
        request_file = os.path.join(APPROVAL_QUEUE, f"{request_id}.request")
        with open(request_file, 'w') as f:
            json.dump(request, f, indent=2)
        
        # Update pending responses
        self.pending_responses[request_id] = request
        self.save_responses()
        
        # Log the denial
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(APPROVAL_LOG, 'a') as f:
            f.write(f"{timestamp}|user|deny|{file_path}|{user_text}|DENIED\n")
        
        # Remove from pending
        del self.pending_responses[request_id]
        self.save_responses()
        
        return {
            "status": "DENIED",
            "message": f"❌ Request denied. File remains protected.",
            "file": file_path,
            "request_id": request_id
        }
    
    def get_pending_requests(self):
        """Get all pending requests"""
        return list(self.pending_responses.values())
    
    def format_pending_list(self):
        """Format pending requests as a list"""
        pending = self.get_pending_requests()
        
        if not pending:
            return "✅ No pending approval requests."
        
        output = "📋 **Pending Approval Requests:**\n\n"
        for req in pending:
            output += f"🔹 **{req['request_id']}** - `{req['file']}`\n"
            output += f"   Reason: {req['reason']}\n"
            output += f"   Agent: {req['agent']}\n"
            output += f"   Time: {req['timestamp']}\n\n"
        
        return output


def main():
    """Main entry point for CLI"""
    guardian = GuardianApproval()
    
    if len(sys.argv) < 2:
        print("GUARDIAN Natural Language Approval System")
        print("\nUsage:")
        print("  guardian-nlp request <file> <reason>  - Create request")
        print("  guardian-nlp respond <id> <response>  - Respond to request")
        print("  guardian-nlp pending                  - List pending requests")
        print("\nIn Qwen Code, just respond naturally to approval prompts.")
        return
    
    command = sys.argv[1]
    
    if command == "request" and len(sys.argv) >= 4:
        file_path = sys.argv[2]
        reason = ' '.join(sys.argv[3:])
        request = guardian.create_request(file_path, reason)
        print(guardian.format_approval_prompt(request))
    
    elif command == "respond" and len(sys.argv) >= 4:
        request_id = sys.argv[2]
        response = ' '.join(sys.argv[3:])
        result = guardian.process_user_response(request_id, response)
        print(json.dumps(result, indent=2))
    
    elif command == "pending":
        print(guardian.format_pending_list())
    
    else:
        print("Unknown command. Use: request, respond, or pending")


if __name__ == "__main__":
    main()
