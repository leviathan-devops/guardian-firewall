#!/usr/bin/env python3
"""
GUARDIAN ANGEL - Real-Time Build Security Monitor
==================================================

Monitors builds in real-time and flags security vulnerabilities BEFORE testing.
Activates between Step 1 (write code) and Step 2 (test in docker sandbox).

Usage:
    guardian-angel start <build-directory>   # Start monitoring
    guardian-angel scan <build-directory>    # Scan for vulnerabilities
    guardian-angel report <build-directory>  # Generate security report
    guardian-angel stop                      # Stop monitoring
"""

import os
import sys
import json
import re
import subprocess
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Configuration
GUARDIAN_ANGEL_DIR = Path.home() / ".guardian-angel"
BUILD_MONITOR_DIR = GUARDIAN_ANGEL_DIR / "monitored_builds"
REPORTS_DIR = GUARDIAN_ANGEL_DIR / "reports"
LOG_FILE = GUARDIAN_ANGEL_DIR / "angel.log"

# Ensure directories exist
GUARDIAN_ANGEL_DIR.mkdir(exist_ok=True)
BUILD_MONITOR_DIR.mkdir(exist_ok=True)
REPORTS_DIR.mkdir(exist_ok=True)


class SecurityVulnerability:
    """Represents a security vulnerability found in code"""
    
    SEVERITY_CRITICAL = "CRITICAL"
    SEVERITY_HIGH = "HIGH"
    SEVERITY_MEDIUM = "MEDIUM"
    SEVERITY_LOW = "LOW"
    
    def __init__(self, severity: str, category: str, file: str, line: int, 
                 description: str, remediation: str, cwe: str = None):
        self.severity = severity
        self.category = category
        self.file = file
        self.line = line
        self.description = description
        self.remediation = remediation
        self.cwe = cwe
        self.timestamp = datetime.now().isoformat()
    
    def to_dict(self) -> dict:
        return {
            "severity": self.severity,
            "category": self.category,
            "file": str(self.file),
            "line": self.line,
            "description": self.description,
            "remediation": self.remediation,
            "cwe": self.cwe,
            "timestamp": self.timestamp
        }
    
    def __str__(self) -> str:
        severity_colors = {
            self.SEVERITY_CRITICAL: "🔴",
            self.SEVERITY_HIGH: "🟠",
            self.SEVERITY_MEDIUM: "🟡",
            self.SEVERITY_LOW: "🔵"
        }
        icon = severity_colors.get(self.severity, "⚪")
        return f"{icon} [{self.severity}] {self.category}: {self.description}\n   📁 {self.file}:{self.line}\n   💡 {self.remediation}"


class GuardianAngel:
    """Real-time build security monitor"""
    
    def __init__(self):
        self.monitored_builds = self._load_monitored_builds()
        self.vulnerability_patterns = self._load_vulnerability_patterns()
    
    def _load_monitored_builds(self) -> dict:
        """Load list of monitored builds"""
        index_file = BUILD_MONITOR_DIR / "index.json"
        if index_file.exists():
            with open(index_file, 'r') as f:
                return json.load(f)
        return {}
    
    def _save_monitored_builds(self):
        """Save monitored builds index"""
        index_file = BUILD_MONITOR_DIR / "index.json"
        with open(index_file, 'w') as f:
            json.dump(self.monitored_builds, f, indent=2)
    
    def _load_vulnerability_patterns(self) -> dict:
        """Load security vulnerability detection patterns"""
        return {
            "hardcoded_secrets": {
                "patterns": [
                    (r'(?i)(api[_-]?key|apikey)\s*=\s*["\'][^"\']{8,}["\']', "Hardcoded API key"),
                    (r'(?i)(secret|password|passwd|pwd)\s*=\s*["\'][^"\']{6,}["\']', "Hardcoded password/secret"),
                    (r'(?i)(aws_access_key_id|aws_secret_access_key)\s*=\s*["\'][^"\']+["\']', "Hardcoded AWS credentials"),
                    (r'(?i)(private[_-]?key|priv[_-]?key)\s*=\s*["\'][^"\']+["\']', "Hardcoded private key"),
                    (r'-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----', "Embedded private key"),
                ],
                "severity": SecurityVulnerability.SEVERITY_CRITICAL,
                "remediation": "Move to environment variables or secrets manager"
            },
            "command_injection": {
                "patterns": [
                    (r'os\.system\s*\([^)]*\+[^)]*\)', "Command injection via os.system"),
                    (r'subprocess\.(call|run|Popen)\s*\([^)]*\+[^)]*\)', "Command injection via subprocess"),
                    (r'eval\s*\([^)]*\+[^)]*\)', "Code injection via eval"),
                    (r'exec\s*\([^)]*\+[^)]*\)', "Code injection via exec"),
                ],
                "severity": SecurityVulnerability.SEVERITY_CRITICAL,
                "remediation": "Use parameterized commands, never concatenate user input"
            },
            "sql_injection": {
                "patterns": [
                    (r'execute\s*\(\s*f["\'].*\{.*\}.*["\']', "SQL injection via f-string"),
                    (r'execute\s*\([^)]*\+[^)]*\)', "SQL injection via string concatenation"),
                    (r'raw\s*\(\s*f["\'].*\{.*\}.*["\']', "Raw SQL injection"),
                ],
                "severity": SecurityVulnerability.SEVERITY_CRITICAL,
                "remediation": "Use parameterized queries or ORM"
            },
            "path_traversal": {
                "patterns": [
                    (r'open\s*\([^)]*\+[^)]*\)', "Potential path traversal"),
                    (r'os\.path\.join\s*\([^)]*request[^)]*\)', "User-controlled path join"),
                ],
                "severity": SecurityVulnerability.SEVERITY_HIGH,
                "remediation": "Validate and sanitize file paths, use allowlists"
            },
            "insecure_random": {
                "patterns": [
                    (r'random\.(random|randint|choice|shuffle)', "Insecure random for security purposes"),
                ],
                "severity": SecurityVulnerability.SEVERITY_MEDIUM,
                "remediation": "Use secrets module for security-sensitive randomness"
            },
            "hardcoded_urls": {
                "patterns": [
                    (r'https?://[^\s"\']+[^\s"\']{20,}', "Hardcoded URL - consider config"),
                ],
                "severity": SecurityVulnerability.SEVERITY_LOW,
                "remediation": "Move to configuration file or environment variables"
            },
            "debug_code": {
                "patterns": [
                    (r'(?i)#\s*(TODO|FIXME|XXX|HACK)\s*(security|todo|fixme)', "Debug/TODO comment"),
                    (r'print\s*\(\s*["\']debug', "Debug print statement"),
                ],
                "severity": SecurityVulnerability.SEVERITY_LOW,
                "remediation": "Remove debug code before production"
            },
            "missing_error_handling": {
                "patterns": [
                    (r'except\s*:', "Bare except clause"),
                    (r'except\s+Exception\s*:', "Generic exception handling"),
                    (r'pass\s*#.*ignore', "Silently ignored exception"),
                ],
                "severity": SecurityVulnerability.SEVERITY_MEDIUM,
                "remediation": "Add specific error handling and logging"
            },
        }
    
    def start_monitoring(self, build_dir: str, build_name: str = None) -> str:
        """Start monitoring a build directory"""
        build_path = Path(build_dir).resolve()
        
        if not build_path.exists():
            raise ValueError(f"Build directory not found: {build_dir}")
        
        if not build_name:
            build_name = f"build_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        # Create monitoring record
        build_monitor_path = BUILD_MONITOR_DIR / build_name
        build_monitor_path.mkdir(exist_ok=True)
        
        monitoring_record = {
            "build_name": build_name,
            "build_dir": str(build_path),
            "started_at": datetime.now().isoformat(),
            "status": "monitoring",
            "scan_count": 0,
            "vulnerabilities_found": 0,
            "last_scan": None
        }
        
        self.monitored_builds[build_name] = monitoring_record
        self._save_monitored_builds()
        
        # Perform initial scan
        self.scan_build(build_name)
        
        return build_name
    
    def scan_build(self, build_name: str) -> List[SecurityVulnerability]:
        """Scan a monitored build for vulnerabilities"""
        if build_name not in self.monitored_builds:
            raise ValueError(f"Build not monitored: {build_name}")
        
        build_record = self.monitored_builds[build_name]
        build_path = Path(build_record["build_dir"])
        
        vulnerabilities = []
        
        # Scan all code files
        code_extensions = ['.py', '.js', '.ts', '.jsx', '.tsx', '.sh', '.bash', 
                          '.json', '.yaml', '.yml', '.conf', '.config', '.env']
        
        for ext in code_extensions:
            for file_path in build_path.rglob(f'*{ext}'):
                if 'node_modules' in str(file_path) or '.git' in str(file_path):
                    continue
                
                file_vulns = self._scan_file(file_path, build_path)
                vulnerabilities.extend(file_vulns)
        
        # Update monitoring record
        build_record["scan_count"] += 1
        build_record["last_scan"] = datetime.now().isoformat()
        build_record["vulnerabilities_found"] = len(vulnerabilities)
        self._save_monitored_builds()
        
        # Save scan results
        self._save_scan_results(build_name, vulnerabilities)
        
        return vulnerabilities
    
    def _scan_file(self, file_path: Path, base_path: Path) -> List[SecurityVulnerability]:
        """Scan a single file for vulnerabilities"""
        vulnerabilities = []
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                lines = content.split('\n')
        except Exception as e:
            self._log(f"Error reading {file_path}: {e}")
            return []
        
        relative_path = file_path.relative_to(base_path)
        
        for category, config in self.vulnerability_patterns.items():
            for pattern, description in config["patterns"]:
                for line_num, line in enumerate(lines, 1):
                    if re.search(pattern, line):
                        vuln = SecurityVulnerability(
                            severity=config["severity"],
                            category=category,
                            file=str(relative_path),
                            line=line_num,
                            description=description,
                            remediation=config["remediation"],
                            cwe=self._get_cwe_for_category(category)
                        )
                        vulnerabilities.append(vuln)
        
        return vulnerabilities
    
    def _get_cwe_for_category(self, category: str) -> str:
        """Get CWE ID for vulnerability category"""
        cwe_map = {
            "hardcoded_secrets": "CWE-798",
            "command_injection": "CWE-78",
            "sql_injection": "CWE-89",
            "path_traversal": "CWE-22",
            "insecure_random": "CWE-330",
            "hardcoded_urls": "CWE-798",
            "debug_code": "CWE-489",
            "missing_error_handling": "CWE-703"
        }
        return cwe_map.get(category, "Unknown")
    
    def _save_scan_results(self, build_name: str, vulnerabilities: List[SecurityVulnerability]):
        """Save scan results to file"""
        results_file = BUILD_MONITOR_DIR / build_name / f"scan_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        results = {
            "build_name": build_name,
            "scan_time": datetime.now().isoformat(),
            "vulnerability_count": len(vulnerabilities),
            "vulnerabilities": [v.to_dict() for v in vulnerabilities]
        }
        
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)
    
    def generate_report(self, build_name: str) -> str:
        """Generate a security report for a build"""
        if build_name not in self.monitored_builds:
            raise ValueError(f"Build not monitored: {build_name}")
        
        build_record = self.monitored_builds[build_name]
        
        # Get latest scan results
        scan_dir = BUILD_MONITOR_DIR / build_name
        scan_files = list(scan_dir.glob("scan_*.json"))
        
        if not scan_files:
            return "No scan results available"
        
        latest_scan = max(scan_files)
        with open(latest_scan, 'r') as f:
            scan_results = json.load(f)
        
        # Generate formatted report
        report = self._format_report(build_name, build_record, scan_results)
        
        # Save report
        report_file = REPORTS_DIR / f"{build_name}_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
        with open(report_file, 'w') as f:
            f.write(report)
        
        return report
    
    def _format_report(self, build_name: str, build_record: dict, scan_results: dict) -> str:
        """Format scan results as markdown report"""
        vulns = scan_results["vulnerabilities"]
        
        # Group by severity
        by_severity = {}
        for v in vulns:
            sev = v["severity"]
            if sev not in by_severity:
                by_severity[sev] = []
            by_severity[sev].append(v)
        
        report = f"""# 🔐 Guardian Angel Security Report

**Build:** {build_name}  
**Scanned:** {scan_results['scan_time']}  
**Total Vulnerabilities:** {len(vulns)}  
**Status:** {'✅ SECURE' if len(vulns) == 0 else '⚠️ VULNERABILITIES FOUND'}

---

## Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | {len(by_severity.get(SecurityVulnerability.SEVERITY_CRITICAL, []))} |
| 🟠 High | {len(by_severity.get(SecurityVulnerability.SEVERITY_HIGH, []))} |
| 🟡 Medium | {len(by_severity.get(SecurityVulnerability.SEVERITY_MEDIUM, []))} |
| 🔵 Low | {len(by_severity.get(SecurityVulnerability.SEVERITY_LOW, []))} |

---

## Findings

"""
        
        for severity in [SecurityVulnerability.SEVERITY_CRITICAL, SecurityVulnerability.SEVERITY_HIGH,
                        SecurityVulnerability.SEVERITY_MEDIUM, SecurityVulnerability.SEVERITY_LOW]:
            if severity in by_severity:
                report += f"\n### {severity}\n\n"
                for v in by_severity[severity]:
                    report += f"#### {v['category'].replace('_', ' ').title()}\n\n"
                    report += f"- **File:** `{v['file']}` (line {v['line']})\n"
                    report += f"- **Description:** {v['description']}\n"
                    report += f"- **Remediation:** {v['remediation']}\n"
                    if v.get('cwe'):
                        report += f"- **CWE:** {v['cwe']}\n"
                    report += "\n---\n\n"
        
        if len(vulns) == 0:
            report += "\n✅ **No security vulnerabilities found!** Your code is secure.\n\n"
        else:
            report += f"""
---

## Required Actions

{'🔴 **CRITICAL:** Fix all critical vulnerabilities before proceeding to testing.' if by_severity.get(SecurityVulnerability.SEVERITY_CRITICAL) else ''}
{'🟠 **HIGH:** Address high severity issues before production.' if by_severity.get(SecurityVulnerability.SEVERITY_HIGH) else ''}
{'🟡 **MEDIUM:** Review and fix medium severity issues.' if by_severity.get(SecurityVulnerability.SEVERITY_MEDIUM) else ''}
{'🔵 **LOW:** Consider fixing low severity issues for best practices.' if by_severity.get(SecurityVulnerability.SEVERITY_LOW) else ''}

**Run `guardian-angel scan {build_name}` again after fixing to verify.**
"""
        
        return report
    
    def stop_monitoring(self, build_name: str):
        """Stop monitoring a build"""
        if build_name in self.monitored_builds:
            self.monitored_builds[build_name]["status"] = "stopped"
            self.monitored_builds[build_name]["stopped_at"] = datetime.now().isoformat()
            self._save_monitored_builds()
    
    def _log(self, message: str):
        """Log a message"""
        with open(LOG_FILE, 'a') as f:
            f.write(f"{datetime.now().isoformat()} - {message}\n")


def main():
    """Main entry point"""
    angel = GuardianAngel()
    
    if len(sys.argv) < 2:
        print(__doc__)
        return
    
    command = sys.argv[1]
    
    if command == "start" and len(sys.argv) >= 3:
        build_dir = sys.argv[2]
        build_name = sys.argv[3] if len(sys.argv) > 3 else None
        
        try:
            name = angel.start_monitoring(build_dir, build_name)
            print(f"✅ Guardian Angel started monitoring: {name}")
            print(f"📁 Build directory: {build_dir}")
            print(f"📊 Run 'guardian-angel scan {name}' to check for vulnerabilities")
        except Exception as e:
            print(f"❌ Error: {e}")
            sys.exit(1)
    
    elif command == "scan" and len(sys.argv) >= 3:
        build_name = sys.argv[2]
        
        try:
            vulns = angel.scan_build(build_name)
            
            if not vulns:
                print("✅ No security vulnerabilities found!")
            else:
                print(f"⚠️ Found {len(vulns)} potential vulnerabilities:\n")
                
                # Print by severity
                for severity in [SecurityVulnerability.SEVERITY_CRITICAL, SecurityVulnerability.SEVERITY_HIGH,
                                SecurityVulnerability.SEVERITY_MEDIUM, SecurityVulnerability.SEVERITY_LOW]:
                    sev_vulns = [v for v in vulns if v.severity == severity]
                    if sev_vulns:
                        print(f"\n{severity} ({len(sev_vulns)}):")
                        for v in sev_vulns[:5]:  # Show first 5
                            print(f"  {v}")
                        if len(sev_vulns) > 5:
                            print(f"  ... and {len(sev_vulns) - 5} more")
                
                print(f"\n📄 Full report: guardian-angel report {build_name}")
        except Exception as e:
            print(f"❌ Error: {e}")
            sys.exit(1)
    
    elif command == "report" and len(sys.argv) >= 3:
        build_name = sys.argv[2]
        
        try:
            report = angel.generate_report(build_name)
            print(report)
        except Exception as e:
            print(f"❌ Error: {e}")
            sys.exit(1)
    
    elif command == "stop" and len(sys.argv) >= 3:
        build_name = sys.argv[2]
        
        try:
            angel.stop_monitoring(build_name)
            print(f"✅ Stopped monitoring: {build_name}")
        except Exception as e:
            print(f"❌ Error: {e}")
            sys.exit(1)
    
    elif command == "list":
        if not angel.monitored_builds:
            print("No builds currently monitored")
        else:
            print("Monitored builds:")
            for name, record in angel.monitored_builds.items():
                status = record.get("status", "unknown")
                vulns = record.get("vulnerabilities_found", 0)
                print(f"  📁 {name} - Status: {status}, Vulnerabilities: {vulns}")
    
    else:
        print(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
