#!/usr/bin/env python3
"""A simple `wc` clone.

This script accepts exactly one positional argument – a path to a text file –
and prints a single line with the number of lines, words, and characters
followed by the file path.

Usage:
    mywc.py [options] <file>

Options:
    -h, --help    Show this help and exit.

If the file does not exist an error is printed to stderr and the script
exits with a non‑zero status.
"""

import argparse
import sys


def _count_file(path: str):
    """Return a tuple (lines, words, chars) for the file *path*.

    Lines are counted by the number of ``\n`` characters.  Words are
    determined by splitting on any whitespace.  Characters include newlines.
    """
    try:
        with open(path, "r", encoding="utf‑8") as fp:
            data = fp.read()
    except FileNotFoundError as exc:
        sys.stderr.write(f"{path}: No such file or directory\n")
        sys.exit(1)

    lines = data.count("\n")
    words = len(data.split())
    chars = len(data)
    return lines, words, chars


def _parse_args():
    parser = argparse.ArgumentParser(
        add_help=False, usage="%(prog)s [options] <file>"
    )
    parser.add_argument("path", help="text file to analyse")
    parser.add_argument("-h", "--help", action="store_true", help="show help and exit")
    return parser.parse_args()


def main():
    args = _parse_args()
    if args.help:
        # Print a simple one‑line usage like the original `wc` does.
        print("Usage: mywc.py [options] <file>")
        sys.exit(0)

    lines, words, chars = _count_file(args.path)
    print(f"{lines} {words} {chars} {args.path}")


if __name__ == "__main__":
    main()
