#!/usr/bin/env python3
"""Command-line entry point for the todo app.

Usage:
    python app/cli.py add "buy milk"
    python app/cli.py list
    python app/cli.py list --pending
    python app/cli.py done <id>
    python app/cli.py rm <id>

Only `add` and (plain) `list` are implemented. `done`, `rm`, and the
`list --pending` filter are stubbed out and must be completed.

Persistence lives in app/storage.py -- read it to understand the data model.
This file imports storage as a sibling module, so it works whether invoked as
`python app/cli.py ...` from the repo root or `python cli.py ...` from inside
app/.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import storage  # noqa: E402


def cmd_add(args):
    if not args:
        print("error: add requires task text", file=sys.stderr)
        return 2
    text = " ".join(args)
    tid = storage.add_task(text)
    print(f"added #{tid}: {text}")
    return 0


def cmd_list(args):
    pending_only = "--pending" in args
    tasks = storage.load()
    if pending_only:
        # TODO: implement the --pending filter (only tasks where done is False)
        raise NotImplementedError("list --pending is not implemented yet")
    if not tasks:
        print("(no tasks)")
        return 0
    for t in tasks:
        mark = "x" if t["done"] else " "
        print(f"[{mark}] #{t['id']} {t['text']}")
    return 0


def cmd_done(args):
    # TODO: mark the task with the given id as done, persist, and print
    # "done #<id>". If the id does not exist, print an error to stderr and
    # exit non-zero.
    raise NotImplementedError("done is not implemented yet")


def cmd_rm(args):
    # TODO: delete the task with the given id, persist, and print
    # "removed #<id>". If the id does not exist, print an error to stderr and
    # exit non-zero.
    raise NotImplementedError("rm is not implemented yet")


def main(argv):
    if not argv:
        print("usage: cli.py {add|list|done|rm} ...", file=sys.stderr)
        return 2
    cmd, rest = argv[0], argv[1:]
    handlers = {
        "add": cmd_add,
        "list": cmd_list,
        "done": cmd_done,
        "rm": cmd_rm,
    }
    handler = handlers.get(cmd)
    if handler is None:
        print(f"error: unknown command {cmd!r}", file=sys.stderr)
        return 2
    return handler(rest)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
