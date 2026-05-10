#!/usr/bin/env python3
import argparse
import sys

def count_file(filepath):
    """Count lines, words, and characters in a file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = 0
            words = 0
            chars = 0
            
            for line in f:
                lines += 1
                words += len(line.split())
                chars += len(line)
                
        return lines, words, chars
    except FileNotFoundError:
        print(f"mywc.py: {filepath}: No such file or directory", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"mywc.py: {filepath}: Error reading file - {e}", file=sys.stderr)
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description='Print newline, word, and byte counts for each file')
    parser.add_argument('--help', '-h', action='help', help='Show this help message and exit')
    parser.add_argument('filepath', nargs=1, help='Path to the text file')
    
    args = parser.parse_args()
    
    filepath = args.filepath[0]
    lines, words, chars = count_file(filepath)
    
    print(f"{lines} {words} {chars} {filepath}")

if __name__ == "__main__":
    main()