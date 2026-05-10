import sys
import argparse
import os

def count_metrics(file_path):
    try:
        with open(file_path, 'r') as file:
            content = file.read()
    except FileNotFoundError:
        return None, None, None

    lines = content.count('\n')
    words = len(content.split())
    chars = len(content)
    return lines, words, chars

def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('-h', '--help', action='help', default=argparse.SUPPRESS, help='Show help message')
    parser.add_argument('file', type=str, help='Path to the text file')
    args = parser.parse_args()

    if not args.file:
        parser.print_help()
        sys.exit(1)

    lines, words, chars = count_metrics(args.file)
    if not lines and not words and not chars:
        print(f"Error: File '{args.file}' not found")
        sys.exit(1)

    print(f"{lines} {words} {chars} {args.file}")

if __name__ == '__main__':
    main()
