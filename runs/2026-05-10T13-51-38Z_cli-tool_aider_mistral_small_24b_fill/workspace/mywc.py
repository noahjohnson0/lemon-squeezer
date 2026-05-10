import sys

def count_lines(file_path):
    with open(file_path, 'r') as file:
        lines = file.readlines()
    return len(lines)

def count_words(file_path):
    with open(file_path, 'r') as file:
        words = file.read().split()
    return len(words)

def count_chars(file_path):
    with open(file_path, 'r') as file:
        chars = file.read()
    return len(chars)

def main():
    if len(sys.argv) != 2 or sys.argv[1] in ('-h', '--help'):
        print("Usage: mywc.py <file_path>")
        exit(0)

    file_path = sys.argv[1]

    try:
        lines = count_lines(file_path)
        words = count_words(file_path)
        chars = count_chars(file_path)
        print(f"{lines} {words} {chars} {file_path}")
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.", file=sys.stderr)
        exit(1)

if __name__ == '__main__':
    main()
