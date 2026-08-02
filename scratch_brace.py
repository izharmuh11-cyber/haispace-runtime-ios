import sys

def check_braces(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()
        
    stack = []
    for i, line in enumerate(lines):
        for j, char in enumerate(line):
            if char == '{':
                stack.append((i+1, j+1))
            elif char == '}':
                if stack:
                    stack.pop()
                else:
                    print(f"Extra closing brace at {i+1}:{j+1}")
                    
    if stack:
        print(f"Unclosed braces opened at:")
        for loc in stack:
            print(f" - {loc[0]}:{loc[1]}")
    else:
        print("Braces are balanced.")

check_braces(r'c:\Users\Izhar\Documents\Extention\HaispaceProject\haispace-runtime-ios\HaispaceRuntime\App\Views\Guest\ActiveSessionView.swift')
