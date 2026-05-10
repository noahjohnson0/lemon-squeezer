import sys

def count_lines_words_chars(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()

    line_count = len(lines)
    word_count = sum(len(line.split()) for line in lines)
    char_count = sum(len(line) for line in lines)

    return line_count, word_count, char_count

def main():
    if len(sys.argv) != 2:
        print("Usage: mywc.py <file_path>")
        sys.exit(0)

    file_path = sys.argv[1]

    try:
        lines, words, chars = count_lines_words_chars(file_path)
        print(f"{lines} {words} {chars} {file_path}")
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
