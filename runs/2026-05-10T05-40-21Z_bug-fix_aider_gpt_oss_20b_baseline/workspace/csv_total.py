import csv
import sys

def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python csv_total.py <csvfile>")
        sys.exit(1)

    filename = sys.argv[1]
    total = 0

    try:
        with open(filename, newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                amount_str = row.get("amount")
                if amount_str is None:
                    continue
                try:
                    total += int(amount_str)
                except ValueError:
                    # Silently ignore rows with non‑integer amounts
                    continue
        print(total)
    except FileNotFoundError:
        print(f"File not found: {filename}")
        sys.exit(1)

if __name__ == "__main__":
    main()
