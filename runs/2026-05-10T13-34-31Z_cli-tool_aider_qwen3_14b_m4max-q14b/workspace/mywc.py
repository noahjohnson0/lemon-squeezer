import argparse
import sys
import os

def main():
    parser = argparse.ArgumentParser(description='Count lines, words, and characters in a file.')
    parser.add_argument('file', help='Path to the text file')
    parser.add_argument('-h', '--help', action='help', help='Show this help message and exit')
    args = parser.parse_args()

    file_path = args.file

    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(file_path, 'r') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        sys.exit(1)

    lines = len(content.splitlines())
    words = len(content.split())
    chars = len(content)

    print(f"{lines} {words} {chars} {file_path}")

if __name__ == '__main__':
    main()
