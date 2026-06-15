Build a CLI tool `mywc.py` (a small `wc` clone). Requirements:

1. Reads exactly one positional argument: a path to a text file.
2. Prints one line containing four whitespace-separated fields: `<lines> <words> <chars> <path>`.
   - `lines` = number of `\n`-terminated lines
   - `words` = number of whitespace-separated tokens
   - `chars` = total character count (including newlines)
   - `path` = the path argument as given
3. Supports `--help` / `-h`, which prints a usage line and exits 0.
4. If the file doesn't exist, prints an error to stderr and exits non-zero.

Create only `mywc.py`. Don't run it - just write it.
