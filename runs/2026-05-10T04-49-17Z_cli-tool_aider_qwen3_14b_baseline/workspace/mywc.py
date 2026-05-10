import sys

def main():
    if len(sys.argv) == 2 and sys.argv[1] in ('--help', '-h'):
        print("Usage: mywc.py <path>")
        return 0
    if len(sys.argv) != 2:
        print("Usage: mywc.py <path>")
        return 1
    path = sys.argv[1]
    try:
        with open(path, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: File not found: {path}", file=sys.stderr)
        return 1
    lines = content.count('\n')
    words = len(content.split())
    chars = len(content)
    print(f"{lines} {words} {chars} {path}")
    return 0

if __name__ == '__main__':
    sys.exit(main())
