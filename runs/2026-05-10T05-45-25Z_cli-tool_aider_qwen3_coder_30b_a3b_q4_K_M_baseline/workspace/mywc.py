#!/usr/bin/env python3

import sys
import os

def main():
    # Check for help flags
    if len(sys.argv) == 2 and sys.argv[1] in ('--help', '-h'):
        print('Usage: mywc.py <file>')
        sys.exit(0)
    
    # Check for exactly one argument
    if len(sys.argv) != 2:
        print('Usage: mywc.py <file>', file=sys.stderr)
        sys.exit(1)
    
    path = sys.argv[1]
    
    # Check if file exists
    if not os.path.isfile(path):
        print(f'mywc.py: {path}: No such file or directory', file=sys.stderr)
        sys.exit(1)
    
    # Read file and count
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.count('\n')
    words = len(content.split())
    chars = len(content)
    
    print(f'{lines} {words} {chars} {path}')

if __name__ == '__main__':
    main()
