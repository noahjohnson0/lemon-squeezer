#!/usr/bin/env python3
"""A simple `wc` clone.

The script accepts exactly one positional argument – a path to a text file –
and prints a single line with the number of lines, words, and characters
followed by the file path.

The tool also supports ``-h`` / ``--help``; in that case it prints a usage
line and exits with status code 0.

If the specified file does not exist an error message is written to stderr
and the program exits with a non‑zero status.
"""

import sys

USAGE_LINE = "Usage: mywc.py [options] <file>"


def _print_usage_and_exit() -> None:
    """Print the usage line and exit with status code 0."""
    print(USAGE_LINE)
    sys.exit(0)


def _error_and_exit(message: str) -> None:
    """Print an error message to stderr and exit with a non‑zero status.

    Parameters
    ----------
    message:
        The error text to write.
    """
    sys.stderr.write(message + "\n")
    sys.exit(1)


def _count_file(path: str):
    """Return a tuple (lines, words, chars) for the file `path`.

    Lines are counted by the number of ``\n`` characters.  Words are
    determined by splitting on any whitespace.  Characters include
    newlines.
    """
    try:
        with open(path, "r", encoding="utf-8") as fp:
            data = fp.read()
    except FileNotFoundError:
        _error_and_exit(f"{path}: No such file or directory")

    lines = data.count("\n")
    words = len(data.split())
    chars = len(data)
    return lines, words, chars


def main() -> None:
    """Parse command‑line arguments and produce the ``wc``‑style output.

    The function performs minimal parsing: it first checks for the ``-h`` or
    ``--help`` flags, handles the special case of missing arguments, and
    finally processes the single file path.
    """
    # ``sys.argv`` includes the program name at index 0.
    args = sys.argv[1:]

    if "-h" in args or "--help" in args:
        _print_usage_and_exit()

    if len(args) != 1:
        _error_and_exit("mywc.py: missing operand")

    path = args[0]
    lines, words, chars = _count_file(path)
    print(f"{lines} {words} {chars} {path}")


if __name__ == "__main__":
    main()
