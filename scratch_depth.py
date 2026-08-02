import sys
import re

filepath = r'c:\Users\Izhar\Documents\Extention\HaispaceProject\haispace-runtime-ios\HaispaceRuntime\App\Views\Guest\ActiveSessionView.swift'
with open(filepath, 'r') as f:
    lines = f.readlines()

depth = 0
for i, line in enumerate(lines):
    # simple heuristic for braces
    # ignore braces in strings or comments
    # Actually just simple counting is enough for a quick check
    clean_line = re.sub(r'//.*', '', line)
    clean_line = re.sub(r'".*?"', '', clean_line)
    
    depth += clean_line.count('{')
    depth -= clean_line.count('}')
    
    if "private var" in line or "private func" in line:
        print(f"Line {i+1} depth {depth}: {line.strip()}")
