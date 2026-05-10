import sys

def main():
    filename = sys.argv[1]
    total = 0
    with open(filename, 'r') as f:
        lines = f.readlines()
        for line in lines[1:]:  # Skip header row
            parts = line.strip().split(',');
            if len(parts) < 2:
                continue
            try:
                total += int(parts[1])
            except (ValueError, IndexError):
                pass
    print(total)

if __name__ == '__main__':
    main()