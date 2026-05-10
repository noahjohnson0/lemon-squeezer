import argparse
import os
import sys

def main():
    parser = argparse.ArgumentParser(description='Count lines, words, and characters in a file.')
    parser.add_argument('path', help='Path to the text file')
    parser.add_argument('-h', '--help', action='help', help='Show this help message and exit')
    args = parser.parse_args()

    if not os.path.exists(args.path):
        print("Error: File not found", file=sys.stderr)
        sys.exit(1)

    with open(args.path, 'r') as file:
        content = file.read()

    lines = content.count('\n')
    words = len(content.split())
    chars = len(content)

    print(f"{lines} {words} {chars} {args.path}")

if __name__ == '__main__':
    main()