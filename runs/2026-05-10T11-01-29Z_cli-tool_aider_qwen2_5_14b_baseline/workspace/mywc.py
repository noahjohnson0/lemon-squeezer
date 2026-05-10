import sys
from pathlib import Path


def print_usage():
    print("Usage: mywc.py <filename>")
    exit(0)


def count_lines_words_chars(file_path):
    try:
        with open(file_path, 'r') as file:
            content = file.read()
            lines = len(content.splitlines())
            words = len(content.split())
            chars = len(content)
            print(f"{lines} {words} {chars} {file_path}")
    except FileNotFoundError:
        sys.stderr.write(f"mywc: {file_path}: No such file or directory\n")
        exit(1)


def main():
    if len(sys.argv) != 2 or (sys.argv[1] in ['-h', '--help']):
        print_usage()
    else:
        count_lines_words_chars(sys.argv[1])


if __name__ == "__main__":
    main()
