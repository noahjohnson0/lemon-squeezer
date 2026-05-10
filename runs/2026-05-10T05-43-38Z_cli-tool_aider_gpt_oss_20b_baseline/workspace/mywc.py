#!/usr/bin/env python3
import argparse
import sys
import os

def main() -> None:
    parser = argparse.ArgumentParser(
        description="A small wc clone",
        add_help=False,
        usage="%(prog)s [--help] <path>"
    )
    parser.add_argument(
        "path",
        nargs="?",
        help="Path to the text file"
    )
    parser.add_argument(
        "-h",
        "--help",
        action="store_true",
        help="Show this help message and exit"
    )

    args = parser.parse_args()

    if args.help:
        parser.print_usage()
        sys.exit(0)

    if not args.path:
        parser.error("the following arguments are required: path")

    file_path = args.path

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        sys.stderr.write(f"Error: file '{file_path}' not found\n")
        sys.exit(1)
    except OSError as e:
        sys.stderr.write(f"Error: cannot read file '{file_path}': {e}\n")
        sys.exit(1)

    lines = content.count("\n")
    words = len(content.split())
    chars = len(content)

    print(f"{lines} {words} {chars} {file_path}")

if __name__ == "__main__":
    main()
