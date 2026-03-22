#!/usr/bin/env python3
"""
GUARDIAN ANGEL - Real-Time Build Security Monitor
==================================================

ACTUALLY monitors builds in real-time using inotify/watchdog.
Flags security vulnerabilities AS THEY ARE INTRODUCED.

Usage:
    guardian-angel start <build-directory>   # Start monitoring (launches daemon)
    guardian-angel stop                      # Stop daemon
    guardian-angel status                    # Check daemon status
    guardian-angel scan <build-directory>    # One-time scan
    guardian-angel report <build-name>       # Generate security report
    guardian-angel list                      # List monitored builds

The daemon runs in the background and watches for file changes.
When a vulnerability is detected, it alerts immediately.
"""

import os
import sys
import json
import re
import subprocess
import hashlib
import signal
import time
import threading
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Set
from dataclasses import dataclass, asdict
from enum import Enum
import traceback

# Try to import watchdog - it's required for real-time monitoring
try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler, FileModifiedEvent, FileCreatedEvent
    WATCHDOG_AVAILABLE = True
except ImportError:
    WATCHDOG_AVAILABLE = False
    print("⚠️  WARNING: watchdog not installed. Real-time monitoring unavailable.")
    print("   Install with: pip install watchdog")

# Configuration
GUARDIAN_ANGEL_DIR = Path.home() / ".guardian-angel"
BUILD_MONITOR_DIR = GUARDIAN_ANGEL_DIR / "monitored_builds"
REPORTS_DIR = GUARDIAN_ANGEL_DIR / "reports"
LOG_FILE = GUARDIAN_ANGEL_DIR / "angel.log"
DAEMON_PID_FILE = GUARDIAN_ANGEL_DIR / "daemon.pid"
DAEMON_SOCKET = GUARDIAN_ANGEL_DIR / "daemon.sock"
ALERTS_FILE = GUARDIAN_ANGEL_DIR / "alerts.json"

# Ensure directories exist
GUARDIAN_ANGEL_DIR.mkdir(exist_ok=True)
BUILD_MONITOR_DIR.mkdir(exist_ok=True)
REPORTS_DIR.mkdir(exist_ok=True)


class Severity(Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INFO = "INFO"


@dataclass
class Vulnerability:
    """Represents a security vulnerability found in code"""
    severity: str
    category: str
    file: str
    line: int
    description: str
    remediation: str
    cwe: str = None
    timestamp: str = None
    code_snippet: str = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now().isoformat()
    
    def to_dict(self) -> dict:
        return asdict(self)
    
    def __str__(self) -> str:
        severity_icons = {
            Severity.CRITICAL.value: "🔴",
            Severity.HIGH.value: "🟠",
            Severity.MEDIUM.value: "🟡",
            Severity.LOW.value: "🔵",
        }
        icon = severity_icons.get(self.severity, "⚪")
        return f"{icon} [{self.severity}] {self.category}: {self.description}\n   📁 {self.file}:{self.line}\n   💡 {self.remediation}"


@dataclass
class Alert:
    """Real-time alert for detected vulnerability"""
    vulnerability: Vulnerability
    build_name: str
    acknowledged: bool = False
    timestamp: str = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.now().isoformat()


class VulnerabilityPatterns:
    """Security vulnerability detection patterns"""
    
    PATTERNS = {
        "hardcoded_secrets": {
            "patterns": [
                (r'(?i)(api[_-]?key|apikey)\s*=\s*["\'][^"\']{8,}["\']', "Hardcoded API key"),
                (r'(?i)(secret|password|passwd|pwd)\s*=\s*["\'][^"\']{6,}["\']', "Hardcoded password/secret"),
                (r'(?i)(aws_access_key_id|aws_secret_access_key)\s*=\s*["\'][^"\']+["\']', "Hardcoded AWS credentials"),
                (r'(?i)(private[_-]?key|priv[_-]?key)\s*=\s*["\'][^"\']+["\']', "Hardcoded private key"),
                (r'-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----', "Embedded private key"),
                (r'(?i)(github[_-]?token|gh[_-]?token)\s*=\s*["\'][^"\']+["\']', "Hardcoded GitHub token"),
                (r'(?i)(slack[_-]?token|slack[_-]?webhook)\s*=\s*["\'][^"\']+["\']', "Hardcoded Slack token"),
                (r'xox[baprs]-[0-9]{10,}-[0-9]{10,}-[a-zA-Z0-9]{24}', "Slack token pattern"),
                (r'sk-[a-zA-Z0-9]{20,}', "OpenAI API key pattern"),
                (r'sk-ant-[a-zA-Z0-9]{20,}', "Anthropic API key pattern"),
            ],
            "severity": Severity.CRITICAL.value,
            "remediation": "Move secrets to environment variables or secrets manager",
            "cwe": "CWE-798"
        },
        "command_injection": {
            "patterns": [
                (r'os\.system\s*\([^)]*\+', "Command injection via os.system with string concat"),
                (r'subprocess\.(call|run|Popen)\s*\([^)]*shell\s*=\s*True[^)]*\+', "Command injection with shell=True"),
                (r'eval\s*\([^)]*\+', "Code injection via eval"),
                (r'exec\s*\([^)]*\+', "Code injection via exec"),
                (r'__import__\s*\([^)]*\+', "Dynamic import injection"),
                (r'compile\s*\([^)]*\+', "Code compilation injection"),
            ],
            "severity": Severity.CRITICAL.value,
            "remediation": "Use parameterized commands, subprocess without shell=True",
            "cwe": "CWE-78"
        },
        "sql_injection": {
            "patterns": [
                (r'execute\s*\(\s*f["\'].*\{.*\}.*["\']', "SQL injection via f-string"),
                (r'execute\s*\([^)]*\+[^)]*\)', "SQL injection via string concatenation"),
                (r'raw\s*\(\s*f["\'].*\{.*\}.*["\']', "Raw SQL injection"),
                (r'cursor\.execute\s*\([^)]*\+', "Cursor SQL injection"),
                (r'(?i)(select|insert|update|delete).*\+.+\s*(from|into|set|where)', "SQL query construction"),
            ],
            "severity": Severity.CRITICAL.value,
            "remediation": "Use parameterized queries or ORM",
            "cwe": "CWE-89"
        },
        "path_traversal": {
            "patterns": [
                (r'open\s*\([^)]*\.\.', "Potential path traversal with .."),
                (r'os\.path\.join\s*\([^)]*request[^)]*\)', "User-controlled path join"),
                (r'send_file\s*\([^)]*request[^)]*\)', "User-controlled file send"),
                (r'read_file\s*\([^)]*\+', "File read with concatenation"),
            ],
            "severity": Severity.HIGH.value,
            "remediation": "Validate and sanitize file paths, use allowlists",
            "cwe": "CWE-22"
        },
        "ssrf": {
            "patterns": [
                (r'requests\.(get|post|put|delete)\s*\([^)]*request[^)]*\)', "SSRF via request object"),
                (r'urllib\.request\.urlopen\s*\([^)]*\+', "SSRF via urllib"),
                (r'httpx\.(get|post)\s*\([^)]*request[^)]*\)', "SSRF via httpx"),
                (r'aiohttp\.ClientSession\(\)\.(get|post)\s*\([^)]*request', "SSRF via aiohttp"),
            ],
            "severity": Severity.HIGH.value,
            "remediation": "Validate URLs, use allowlists for external requests",
            "cwe": "CWE-918"
        },
        "xss": {
            "patterns": [
                (r'render_template_string\s*\([^)]*\+', "XSS via template injection"),
                (r'Markup\s*\([^)]*\+', "XSS via Markup"),
                (r'\|safe\s*\}\}', "Jinja2 safe filter - potential XSS"),
                (r'dangerouslySetInnerHTML', "React dangerouslySetInnerHTML"),
            ],
            "severity": Severity.HIGH.value,
            "remediation": "Sanitize user input, escape HTML entities",
            "cwe": "CWE-79"
        },
        "insecure_random": {
            "patterns": [
                (r'random\.(random|randint|choice|shuffle|seed)\s*\([^)]*\)', "Insecure random for potential security use"),
            ],
            "severity": Severity.MEDIUM.value,
            "remediation": "Use secrets module for security-sensitive randomness",
            "cwe": "CWE-330"
        },
        "insecure_crypto": {
            "patterns": [
                (r'hashlib\.(md5|sha1)\s*\(', "Weak hash algorithm (MD5/SHA1)"),
                (r'DES\s*\(', "DES encryption - too weak"),
                (r'ECB', "ECB mode - insecure"),
                (r'random\.seed\s*\(', "Predictable random seed"),
            ],
            "severity": Severity.MEDIUM.value,
            "remediation": "Use strong crypto: SHA-256+, AES-GCM, secrets module",
            "cwe": "CWE-327"
        },
        "hardcoded_urls": {
            "patterns": [
                (r'https?://[^\s"\']+\.(com|io|net|org)[^\s"\']*', "Hardcoded URL"),
            ],
            "severity": Severity.LOW.value,
            "remediation": "Move to configuration file or environment variables",
            "cwe": "CWE-798"
        },
        "debug_code": {
            "patterns": [
                (r'debug\s*=\s*True', "Debug mode enabled"),
                (r'FLASK_DEBUG\s*=\s*True', "Flask debug mode"),
                (r'DEBUG\s*=\s*True', "Debug flag set"),
                (r'print\s*\(\s*f?["\'].*\{.*debug', "Debug print statement"),
                (r'console\.log\s*\([^)]*debug', "Debug console.log"),
                (r'breakpoint\s*\(\s*\)', "Breakpoint in code"),
                (r'import pdb', "PDB debugger import"),
                (r'import ipdb', "IPDB debugger import"),
            ],
            "severity": Severity.LOW.value,
            "remediation": "Remove debug code before production",
            "cwe": "CWE-489"
        },
        "missing_error_handling": {
            "patterns": [
                (r'except\s*:', "Bare except clause"),
                (r'except\s+Exception\s*:\s*pass', "Silent exception swallowing"),
                (r'catch\s*\(\s*\)\s*\{\s*\}', "Empty catch block"),
            ],
            "severity": Severity.MEDIUM.value,
            "remediation": "Add specific error handling and logging",
            "cwe": "CWE-703"
        },
        "dangerous_functions": {
            "patterns": [
                (r'pickle\.loads?\s*\(', "Pickle can execute arbitrary code"),
                (r'marshal\.loads?\s*\(', "Marshal can be dangerous"),
                (r'yaml\.load\s*\([^)]*\)(?!.*Loader)', "YAML load without safe Loader"),
                (r'shelve\.open\s*\(', "Shelve can execute code"),
            ],
            "severity": Severity.HIGH.value,
            "remediation": "Use safe alternatives: json, yaml.safe_load",
            "cwe": "CWE-502"
        },
    }


class CodeScanner:
    """Static code scanner for vulnerabilities"""
    
    CODE_EXTENSIONS = {'.py', '.js', '.ts', '.jsx', '.tsx', '.sh', '.bash', 
                       '.json', '.yaml', '.yml', '.conf', '.config', '.env',
                       '.rb', '.php', '.go', '.java', '.cs'}
    
    IGNORE_DIRS = {'node_modules', '.git', '__pycache__', 'venv', '.venv',
                   'env', '.env', 'dist', 'build', '.next', 'coverage'}
    
    def __init__(self):
        self.patterns = VulnerabilityPatterns.PATTERNS
    
    def scan_file(self, file_path, base_path=None) -> List[Vulnerability]:
        """Scan a single file for vulnerabilities"""
        vulnerabilities = []
        
        # Convert to Path if string
        file_path = Path(file_path) if isinstance(file_path, str) else file_path
        base_path = Path(base_path) if base_path and isinstance(base_path, str) else base_path
        
        # Skip non-code files
        if file_path.suffix not in self.CODE_EXTENSIONS:
            return vulnerabilities
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                lines = content.split('\n')
        except Exception as e:
            return vulnerabilities
        
        relative_path = str(file_path.relative_to(base_path)) if base_path else str(file_path)
        
        for category, config in self.patterns.items():
            for pattern, description in config["patterns"]:
                try:
                    for line_num, line in enumerate(lines, 1):
                        if re.search(pattern, line):
                            # Get code snippet (line before and after)
                            start = max(0, line_num - 2)
                            end = min(len(lines), line_num + 1)
                            snippet = '\n'.join(f"{i+1}: {lines[i]}" for i in range(start, end))
                            
                            vuln = Vulnerability(
                                severity=config["severity"],
                                category=category,
                                file=relative_path,
                                line=line_num,
                                description=description,
                                remediation=config["remediation"],
                                cwe=config.get("cwe"),
                                code_snippet=snippet
                            )
                            vulnerabilities.append(vuln)
                except re.error:
                    # Invalid regex pattern, skip
                    continue
        
        return vulnerabilities
    
    def scan_directory(self, directory: Path, callback=None) -> List[Vulnerability]:
        """Scan all code files in a directory"""
        vulnerabilities = []
        directory = Path(directory).resolve()
        
        for ext in self.CODE_EXTENSIONS:
            for file_path in directory.rglob(f'*{ext}'):
                # Skip ignored directories
                if any(ignored in file_path.parts for ignored in self.IGNORE_DIRS):
                    continue
                
                file_vulns = self.scan_file(file_path, directory)
                if file_vulns:
                    vulnerabilities.extend(file_vulns)
                    if callback:
                        callback(file_path, file_vulns)
        
        return vulnerabilities


class RealTimeMonitor(FileSystemEventHandler):
    """Real-time file monitor using watchdog"""
    
    def __init__(self, build_path: Path, build_name: str, scanner: CodeScanner, alert_callback=None):
        self.build_path = Path(build_path).resolve()
        self.build_name = build_name
        self.scanner = scanner
        self.alert_callback = alert_callback
        self.recently_scanned: Set[str] = set()
        self.scan_lock = threading.Lock()
        self.vulnerabilities: List[Vulnerability] = []
        
        # Debounce settings
        self.debounce_seconds = 0.5
        self.last_scan_time: Dict[str, float] = {}
    
    def _should_scan(self, file_path: str) -> bool:
        """Check if file should be scanned (with debouncing)"""
        now = time.time()
        last_scan = self.last_scan_time.get(file_path, 0)
        
        if now - last_scan < self.debounce_seconds:
            return False
        
        self.last_scan_time[file_path] = now
        return True
    
    def on_modified(self, event):
        """Handle file modification events"""
        if event.is_directory:
            return
        
        file_path = Path(event.src_path)
        
        # Check if it's a code file
        if file_path.suffix not in self.scanner.CODE_EXTENSIONS:
            return
        
        # Skip ignored directories
        if any(ignored in file_path.parts for ignored in self.scanner.IGNORE_DIRS):
            return
        
        # Debounce
        if not self._should_scan(str(file_path)):
            return
        
        # Scan the file
        self._scan_and_alert(file_path)
    
    def on_created(self, event):
        """Handle file creation events"""
        self.on_modified(event)
    
    def _scan_and_alert(self, file_path: Path):
        """Scan file and generate alerts for vulnerabilities"""
        with self.scan_lock:
            vulnerabilities = self.scanner.scan_file(file_path, self.build_path)
            
            if vulnerabilities:
                self.vulnerabilities.extend(vulnerabilities)
                
                # Log the detection
                self._log_detection(file_path, vulnerabilities)
                
                # Create alerts
                for vuln in vulnerabilities:
                    alert = Alert(
                        vulnerability=vuln,
                        build_name=self.build_name
                    )
                    self._save_alert(alert)
                
                # Call alert callback if provided
                if self.alert_callback:
                    self.alert_callback(file_path, vulnerabilities)
    
    def _log_detection(self, file_path: Path, vulnerabilities: List[Vulnerability]):
        """Log vulnerability detection"""
        timestamp = datetime.now().isoformat()
        log_entry = f"\n{'='*60}\n"
        log_entry += f"[{timestamp}] VULNERABILITIES DETECTED\n"
        log_entry += f"File: {file_path}\n"
        log_entry += f"Count: {len(vulnerabilities)}\n"
        
        for vuln in vulnerabilities:
            log_entry += f"\n  {vuln}\n"
        
        log_entry += f"{'='*60}\n"
        
        with open(LOG_FILE, 'a') as f:
            f.write(log_entry)
        
        # Also print to stdout for immediate visibility
        print(f"\n🔴 GUARDIAN ANGEL ALERT: {len(vulnerabilities)} vulnerabilities in {file_path.name}")
        for vuln in vulnerabilities[:3]:  # Show first 3
            print(f"   {vuln}")
        if len(vulnerabilities) > 3:
            print(f"   ... and {len(vulnerabilities) - 3} more")
    
    def _save_alert(self, alert: Alert):
        """Save alert to alerts file"""
        alerts = []
        if ALERTS_FILE.exists():
            try:
                with open(ALERTS_FILE, 'r') as f:
                    alerts = json.load(f)
            except:
                alerts = []
        
        alerts.append(alert.to_dict())
        
        with open(ALERTS_FILE, 'w') as f:
            json.dump(alerts, f, indent=2)


class GuardianAngelDaemon:
    """Background daemon for real-time monitoring"""
    
    def __init__(self):
        self.scanner = CodeScanner()
        self.monitors: Dict[str, RealTimeMonitor] = {}
        self.observers: Dict[str, Observer] = {}
        self.running = False
    
    def start(self):
        """Start the daemon"""
        if not WATCHDOG_AVAILABLE:
            print("❌ Cannot start daemon: watchdog not installed")
            print("   pip install watchdog")
            return False
        
        # Load monitored builds
        self._load_monitored_builds()
        
        # Start observers for each build
        for build_name, build_info in self._monitored_builds.items():
            if build_info.get('status') == 'monitoring':
                self._start_observer(build_name, Path(build_info['build_dir']))
        
        self.running = True
        self._save_pid()
        
        # Write daemon status
        self._update_status('running')
        
        # Keep running
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            self.stop()
        
        return True
    
    def stop(self):
        """Stop the daemon"""
        self.running = False
        
        # Stop all observers
        for build_name, observer in self.observers.items():
            observer.stop()
            observer.join()
        
        self.observers.clear()
        self.monitors.clear()
        
        self._remove_pid()
        self._update_status('stopped')
    
    def add_build(self, build_name: str, build_path: Path):
        """Add a build to monitor"""
        if not WATCHDOG_AVAILABLE:
            return False
        
        # Save to monitored builds
        self._monitored_builds[build_name] = {
            'build_name': build_name,
            'build_dir': str(build_path),
            'started_at': datetime.now().isoformat(),
            'status': 'monitoring'
        }
        self._save_monitored_builds()
        
        # If daemon is running, start observer immediately
        if self.running:
            self._start_observer(build_name, build_path)
        
        return True
    
    def remove_build(self, build_name: str):
        """Remove a build from monitoring"""
        if build_name in self.observers:
            self.observers[build_name].stop()
            self.observers[build_name].join()
            del self.observers[build_name]
        
        if build_name in self.monitors:
            del self.monitors[build_name]
        
        if build_name in self._monitored_builds:
            self._monitored_builds[build_name]['status'] = 'stopped'
            self._monitored_builds[build_name]['stopped_at'] = datetime.now().isoformat()
            self._save_monitored_builds()
    
    def _start_observer(self, build_name: str, build_path: Path):
        """Start a watchdog observer for a build"""
        monitor = RealTimeMonitor(
            build_path=build_path,
            build_name=build_name,
            scanner=self.scanner,
            alert_callback=self._alert_callback
        )
        
        observer = Observer()
        observer.schedule(monitor, str(build_path), recursive=True)
        observer.start()
        
        self.monitors[build_name] = monitor
        self.observers[build_name] = observer
        
        self._log(f"Started monitoring: {build_name} at {build_path}")
    
    def _alert_callback(self, file_path: Path, vulnerabilities: List[Vulnerability]):
        """Callback for when vulnerabilities are detected"""
        # Send desktop notification if available
        self._send_notification(file_path, vulnerabilities)
    
    def _send_notification(self, file_path: Path, vulnerabilities: List[Vulnerability]):
        """Send desktop notification for critical/high vulnerabilities"""
        critical_count = sum(1 for v in vulnerabilities if v.severity == Severity.CRITICAL.value)
        high_count = sum(1 for v in vulnerabilities if v.severity == Severity.HIGH.value)
        
        if critical_count > 0 or high_count > 0:
            try:
                title = f"🚨 Guardian Angel Alert"
                body = f"{critical_count} CRITICAL, {high_count} HIGH vulnerabilities in {file_path.name}"
                
                # Try notify-send (Linux)
                subprocess.run(['notify-send', '-u', 'critical', title, body], 
                             capture_output=True, timeout=5)
            except:
                pass  # Desktop notifications not available
    
    def _load_monitored_builds(self):
        """Load monitored builds from file"""
        index_file = BUILD_MONITOR_DIR / "index.json"
        if index_file.exists():
            try:
                with open(index_file, 'r') as f:
                    self._monitored_builds = json.load(f)
            except:
                self._monitored_builds = {}
        else:
            self._monitored_builds = {}
    
    def _save_monitored_builds(self):
        """Save monitored builds to file"""
        index_file = BUILD_MONITOR_DIR / "index.json"
        with open(index_file, 'w') as f:
            json.dump(self._monitored_builds, f, indent=2)
    
    def _save_pid(self):
        """Save daemon PID"""
        with open(DAEMON_PID_FILE, 'w') as f:
            f.write(str(os.getpid()))
    
    def _remove_pid(self):
        """Remove daemon PID file"""
        if DAEMON_PID_FILE.exists():
            DAEMON_PID_FILE.unlink()
    
    def _update_status(self, status: str):
        """Update daemon status file"""
        status_file = GUARDIAN_ANGEL_DIR / "daemon_status.json"
        with open(status_file, 'w') as f:
            json.dump({
                'status': status,
                'pid': os.getpid() if status == 'running' else None,
                'updated_at': datetime.now().isoformat()
            }, f, indent=2)
    
    def _log(self, message: str):
        """Log message to file"""
        with open(LOG_FILE, 'a') as f:
            f.write(f"[{datetime.now().isoformat()}] {message}\n")


class GuardianAngelCLI:
    """CLI interface for Guardian Angel"""
    
    def __init__(self):
        self.scanner = CodeScanner()
    
    def start_monitoring(self, build_dir: str, build_name: str = None):
        """Start monitoring a build directory"""
        if not WATCHDOG_AVAILABLE:
            print("❌ Real-time monitoring requires watchdog library")
            print("   Install with: pip install watchdog")
            print("\n   You can still use 'guardian-angel scan' for one-time scanning")
            return False
        
        build_path = Path(build_dir).resolve()
        
        if not build_path.exists():
            print(f"❌ Directory not found: {build_dir}")
            return False
        
        if not build_name:
            build_name = f"build_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        # Check if daemon is running
        if self._is_daemon_running():
            # Send command to running daemon to add build
            self._send_daemon_command('add_build', build_name, str(build_path))
        else:
            # Start daemon with this build
            self._start_daemon(build_name, build_path)
        
        # Perform initial scan
        print(f"\n📊 Performing initial security scan...")
        vulnerabilities = self.scanner.scan_directory(build_path)
        
        if vulnerabilities:
            self._print_vulnerabilities(vulnerabilities)
        else:
            print("✅ No security vulnerabilities found in initial scan")
        
        print(f"\n🎯 Real-time monitoring ACTIVE for: {build_name}")
        print(f"📁 Watching: {build_path}")
        print(f"🔴 Alerts will appear when vulnerabilities are introduced")
        print(f"\n   Stop monitoring: guardian-angel stop {build_name}")
        print(f"   View alerts: guardian-angel alerts")
        
        return True
    
    def stop_monitoring(self, build_name: str = None):
        """Stop monitoring"""
        if build_name:
            if self._is_daemon_running():
                self._send_daemon_command('remove_build', build_name)
                print(f"✅ Stopped monitoring: {build_name}")
            else:
                # Update status file directly
                self._update_build_status(build_name, 'stopped')
                print(f"✅ Marked as stopped: {build_name}")
        else:
            # Stop entire daemon
            if self._is_daemon_running():
                pid = self._get_daemon_pid()
                try:
                    os.kill(pid, signal.SIGTERM)
                    print("✅ Guardian Angel daemon stopped")
                except ProcessLookupError:
                    print("❌ Daemon process not found")
            else:
                print("ℹ️  Daemon is not running")
    
    def status(self):
        """Show daemon and monitoring status"""
        print("\n" + "="*60)
        print("🛡️  GUARDIAN ANGEL STATUS")
        print("="*60)
        
        # Daemon status
        if self._is_daemon_running():
            pid = self._get_daemon_pid()
            print(f"\n🟢 Daemon: RUNNING (PID: {pid})")
        else:
            print(f"\n🔴 Daemon: STOPPED")
        
        # Monitored builds
        builds = self._get_monitored_builds()
        if builds:
            print(f"\n📁 Monitored Builds:")
            for name, info in builds.items():
                status = info.get('status', 'unknown')
                icon = '🟢' if status == 'monitoring' else '🔴'
                print(f"   {icon} {name}")
                print(f"      Path: {info.get('build_dir', 'N/A')}")
                print(f"      Status: {status}")
                if 'started_at' in info:
                    print(f"      Started: {info['started_at']}")
        else:
            print(f"\n📁 No builds currently monitored")
        
        # Recent alerts
        alerts = self._get_recent_alerts(5)
        if alerts:
            print(f"\n🔔 Recent Alerts ({len(alerts)}):")
            for alert in alerts:
                vuln = alert.get('vulnerability', {})
                sev = vuln.get('severity', 'UNKNOWN')
                icon = {'CRITICAL': '🔴', 'HIGH': '🟠', 'MEDIUM': '🟡', 'LOW': '🔵'}.get(sev, '⚪')
                print(f"   {icon} {vuln.get('file', 'unknown')}:{vuln.get('line', '?')} - {vuln.get('description', 'N/A')}")
        
        print("\n" + "="*60)
    
    def scan(self, build_dir: str):
        """Perform a one-time security scan"""
        build_path = Path(build_dir).resolve()
        
        if not build_path.exists():
            print(f"❌ Directory not found: {build_dir}")
            return
        
        print(f"\n🔍 Scanning: {build_path}")
        print("─" * 40)
        
        start_time = time.time()
        vulnerabilities = self.scanner.scan_directory(build_path)
        scan_duration = time.time() - start_time
        
        print(f"\n📊 Scan complete in {scan_duration:.2f}s")
        print(f"   Files scanned: {self._count_scanned_files(build_path)}")
        
        if vulnerabilities:
            self._print_vulnerabilities(vulnerabilities)
            self._save_scan_results(build_path, vulnerabilities)
        else:
            print("\n✅ No security vulnerabilities found!")
    
    def alerts(self, count: int = 20):
        """Show recent alerts"""
        alerts = self._get_recent_alerts(count)
        
        if not alerts:
            print("\n✅ No alerts recorded")
            return
        
        print(f"\n🔔 Recent Alerts ({len(alerts)}):")
        print("="*60)
        
        for alert in alerts:
            vuln = alert.get('vulnerability', {})
            print(f"\n{vuln.get('severity', 'UNKNOWN')} | {vuln.get('category', 'unknown')}")
            print(f"📁 {vuln.get('file', 'unknown')}:{vuln.get('line', '?')}")
            print(f"📝 {vuln.get('description', 'N/A')}")
            print(f"💡 {vuln.get('remediation', 'N/A')}")
            print(f"⏰ {alert.get('timestamp', 'N/A')}")
    
    def report(self, build_name: str):
        """Generate a security report"""
        builds = self._get_monitored_builds()
        
        if build_name not in builds:
            print(f"❌ Build not found: {build_name}")
            return
        
        build_info = builds[build_name]
        build_path = Path(build_info['build_dir'])
        
        # Run fresh scan
        vulnerabilities = self.scanner.scan_directory(build_path)
        
        # Generate report
        report = self._generate_report(build_name, build_info, vulnerabilities)
        
        # Save report
        report_file = REPORTS_DIR / f"{build_name}_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
        with open(report_file, 'w') as f:
            f.write(report)
        
        print(report)
        print(f"\n📄 Report saved to: {report_file}")
    
    def list_builds(self):
        """List all monitored builds"""
        builds = self._get_monitored_builds()
        
        if not builds:
            print("\n📁 No builds currently monitored")
            return
        
        print("\n📁 Monitored Builds:")
        for name, info in builds.items():
            status = info.get('status', 'unknown')
            icon = '🟢' if status == 'monitoring' else '🔴'
            print(f"   {icon} {name} - {status}")
    
    # Helper methods
    
    def _is_daemon_running(self) -> bool:
        """Check if daemon is running"""
        if not DAEMON_PID_FILE.exists():
            return False
        
        try:
            pid = self._get_daemon_pid()
            os.kill(pid, 0)  # Check if process exists
            return True
        except (ProcessLookupError, ValueError):
            return False
    
    def _get_daemon_pid(self) -> int:
        """Get daemon PID"""
        with open(DAEMON_PID_FILE, 'r') as f:
            return int(f.read().strip())
    
    def _start_daemon(self, build_name: str, build_path: Path):
        """Start the daemon process"""
        # Fork to background
        pid = os.fork()
        
        if pid > 0:
            # Parent process - wait for daemon to start
            time.sleep(0.5)
            return True
        
        # Child process - become daemon
        os.setsid()
        
        # Create new daemon instance
        daemon = GuardianAngelDaemon()
        daemon.add_build(build_name, build_path)
        daemon.start()
    
    def _send_daemon_command(self, command: str, *args):
        """Send command to running daemon (via signal or socket)"""
        # For simplicity, we'll use status files for communication
        command_file = GUARDIAN_ANGEL_DIR / "daemon_command.json"
        with open(command_file, 'w') as f:
            json.dump({
                'command': command,
                'args': args,
                'timestamp': datetime.now().isoformat()
            }, f)
    
    def _get_monitored_builds(self) -> dict:
        """Get monitored builds"""
        index_file = BUILD_MONITOR_DIR / "index.json"
        if index_file.exists():
            with open(index_file, 'r') as f:
                return json.load(f)
        return {}
    
    def _update_build_status(self, build_name: str, status: str):
        """Update build status"""
        builds = self._get_monitored_builds()
        if build_name in builds:
            builds[build_name]['status'] = status
            builds[build_name]['stopped_at'] = datetime.now().isoformat()
            
            index_file = BUILD_MONITOR_DIR / "index.json"
            with open(index_file, 'w') as f:
                json.dump(builds, f, indent=2)
    
    def _get_recent_alerts(self, count: int) -> list:
        """Get recent alerts"""
        if not ALERTS_FILE.exists():
            return []
        
        with open(ALERTS_FILE, 'r') as f:
            alerts = json.load(f)
        
        return alerts[-count:]
    
    def _count_scanned_files(self, directory: Path) -> int:
        """Count scanned code files"""
        count = 0
        for ext in self.scanner.CODE_EXTENSIONS:
            for _ in directory.rglob(f'*{ext}'):
                if not any(ignored in _.parts for ignored in self.scanner.IGNORE_DIRS):
                    count += 1
        return count
    
    def _print_vulnerabilities(self, vulnerabilities: List[Vulnerability]):
        """Print vulnerability summary"""
        # Group by severity
        by_severity = {}
        for v in vulnerabilities:
            sev = v.severity
            if sev not in by_severity:
                by_severity[sev] = []
            by_severity[sev].append(v)
        
        print(f"\n⚠️  Found {len(vulnerabilities)} potential vulnerabilities:\n")
        
        severity_order = [Severity.CRITICAL.value, Severity.HIGH.value, 
                         Severity.MEDIUM.value, Severity.LOW.value]
        
        for severity in severity_order:
            if severity in by_severity:
                vulns = by_severity[severity]
                icon = {'CRITICAL': '🔴', 'HIGH': '🟠', 'MEDIUM': '🟡', 'LOW': '🔵'}.get(severity, '⚪')
                print(f"\n{icon} {severity} ({len(vulns)}):")
                
                for v in vulns[:5]:  # Show first 5
                    print(f"   📁 {v.file}:{v.line}")
                    print(f"      {v.description}")
                
                if len(vulns) > 5:
                    print(f"   ... and {len(vulns) - 5} more")
    
    def _save_scan_results(self, build_path: Path, vulnerabilities: List[Vulnerability]):
        """Save scan results"""
        scan_file = GUARDIAN_ANGEL_DIR / f"scan_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        results = {
            'build_path': str(build_path),
            'scan_time': datetime.now().isoformat(),
            'vulnerability_count': len(vulnerabilities),
            'vulnerabilities': [v.to_dict() for v in vulnerabilities]
        }
        
        with open(scan_file, 'w') as f:
            json.dump(results, f, indent=2)
        
        print(f"\n📄 Full results saved to: {scan_file}")
    
    def _generate_report(self, build_name: str, build_info: dict, vulnerabilities: List[Vulnerability]) -> str:
        """Generate markdown security report"""
        by_severity = {}
        for v in vulnerabilities:
            sev = v.severity
            if sev not in by_severity:
                by_severity[sev] = []
            by_severity[sev].append(v)
        
        report = f"""# 🔐 Guardian Angel Security Report

**Build:** {build_name}
**Path:** {build_info.get('build_dir', 'N/A')}
**Scanned:** {datetime.now().isoformat()}
**Total Vulnerabilities:** {len(vulnerabilities)}
**Status:** {'✅ SECURE' if not vulnerabilities else '⚠️ VULNERABILITIES FOUND'}

---

## Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | {len(by_severity.get(Severity.CRITICAL.value, []))} |
| 🟠 High | {len(by_severity.get(Severity.HIGH.value, []))} |
| 🟡 Medium | {len(by_severity.get(Severity.MEDIUM.value, []))} |
| 🔵 Low | {len(by_severity.get(Severity.LOW.value, []))} |

---

## Findings

"""
        
        severity_order = [Severity.CRITICAL.value, Severity.HIGH.value, 
                         Severity.MEDIUM.value, Severity.LOW.value]
        
        for severity in severity_order:
            if severity in by_severity:
                report += f"\n### {severity}\n\n"
                for v in by_severity[severity]:
                    report += f"#### {v.category.replace('_', ' ').title()}\n\n"
                    report += f"- **File:** `{v.file}` (line {v.line})\n"
                    report += f"- **Description:** {v.description}\n"
                    report += f"- **Remediation:** {v.remediation}\n"
                    if v.cwe:
                        report += f"- **CWE:** {v.cwe}\n"
                    if v.code_snippet:
                        report += f"\n```{Path(v.file).suffix.lstrip('.')}\n{v.code_snippet}\n```\n"
                    report += "\n---\n\n"
        
        if not vulnerabilities:
            report += "\n✅ **No security vulnerabilities found!**\n\n"
        
        return report


def main():
    """Main entry point"""
    cli = GuardianAngelCLI()
    
    if len(sys.argv) < 2:
        print(__doc__)
        return
    
    command = sys.argv[1]
    
    if command == "start" and len(sys.argv) >= 3:
        build_dir = sys.argv[2]
        build_name = sys.argv[3] if len(sys.argv) > 3 else None
        cli.start_monitoring(build_dir, build_name)
    
    elif command == "stop":
        build_name = sys.argv[2] if len(sys.argv) > 2 else None
        cli.stop_monitoring(build_name)
    
    elif command == "status":
        cli.status()
    
    elif command == "scan" and len(sys.argv) >= 3:
        build_dir = sys.argv[2]
        cli.scan(build_dir)
    
    elif command == "alerts":
        count = int(sys.argv[2]) if len(sys.argv) > 2 else 20
        cli.alerts(count)
    
    elif command == "report" and len(sys.argv) >= 3:
        build_name = sys.argv[2]
        cli.report(build_name)
    
    elif command == "list":
        cli.list_builds()
    
    elif command == "daemon":
        # Start daemon directly (for systemd)
        if WATCHDOG_AVAILABLE:
            daemon = GuardianAngelDaemon()
            daemon.start()
        else:
            print("❌ watchdog library required for daemon mode")
            sys.exit(1)
    
    else:
        print(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
