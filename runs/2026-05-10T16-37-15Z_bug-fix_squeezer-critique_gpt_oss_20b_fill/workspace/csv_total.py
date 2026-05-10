"""Sum the 'amount' column of a CSV file.

Usage: python csv_total.py <path>

The original version crashed on the header row and on rows with
non‑numeric amounts.  This version skips the header and ignores any
row whose amount cannot be converted to an ``int``.
"""
import csv
import sys


def total(path: str) -> int:
    """Return the sum of the *amount* column.

    Parameters
    ----------
    path:
        Path to a CSV file.  The first row is treated as a header and
        is ignored.  Subsequent rows must provide at least two fields;
        the second field is interpreted as an ``int``.

    The function is intentionally tolerant: rows with missing fields
    or non‑numeric amounts are ignored.
    """
    s = 0
    # ``newline=''`` guarantees that the csv module handles line ending
    # correctly across platforms.
    with open(path, newline='') as f:
        reader = csv.reader(f)
        # Skip the header row.
        next(reader, None)
        for row in reader:
            # Guard against rows that are too short.
            if len(row) < 2:
                continue
            try:
                s += int(row[1])
            except ValueError:
                # Silently ignore any non‑integer amount.
                continue
    return s


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python csv_total.py <path>")
        sys.exit(1)
    print(total(sys.argv[1]))
