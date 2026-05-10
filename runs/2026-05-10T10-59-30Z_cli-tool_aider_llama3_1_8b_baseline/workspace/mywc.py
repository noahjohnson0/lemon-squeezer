import argparse
import os
import sys  # Add this line

def count_lines_words_chars(path):
    with open(path, 'r') as f:
        lines = sum(1 for _ in f)
        words = len(f.read().split())
        chars = len(f.read())
    return lines, words, chars

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('path', help='Path to a text file')
    args = parser.parse_args()

    if not os.path.exists(args.path):
        print(f"Error: File '{args.path}' does not exist", file=sys.stderr)
        sys.exit(1)

    lines, words, chars = count_lines_words_chars(args.path)
    print(f"{lines} {words} {chars} {args.path}")

if __name__ == '__main__':
    main()
