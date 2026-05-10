import argparse
import sys
import os

def main():
    parser = argparse.ArgumentParser(description='Count lines, words, and characters in a file.', add_help=False)
    parser.add_argument('path', help='Path to the text file')
    parser.add_argument('-h', '--help', action='help', default=argparse.SUPPRESS, help='Show this help message and exit')
    args = parser.parse_args()

    if not os.path.exists(args.path):
        print(f"Error: File not found: {args.path}", file=sys.stderr)
        sys.exit(1)

    with open(args.path, 'r') as file:
        content = file.read()

    lines = content.count('\n')
    words = len(content.split())
    chars = len(content)

    print(f"{lines} {words} {chars} {args.path}")

if __name__ == '__main__':
    main()