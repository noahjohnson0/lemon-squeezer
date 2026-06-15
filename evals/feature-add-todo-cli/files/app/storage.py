"""JSON-backed persistence for the todo CLI.

This module is COMPLETE and working. Do not change its public behavior; the
CLI relies on it. You may read it to understand the data model.

The store is a JSON file on disk holding a list of task dicts. Each task is:

    {"id": <int>, "text": <str>, "done": <bool>}

Ids are assigned monotonically (max existing id + 1) so that deleting a task
never causes an id to be reused.
"""

import json
import os


def db_path():
    """Return the path to the JSON store.

    Honors $TODO_DB if set, otherwise ~/.todo.json. Tests set $HOME (and
    $TODO_DB) to a scratch directory so they never touch a real home dir.
    """
    env = os.environ.get("TODO_DB")
    if env:
        return env
    home = os.environ.get("HOME") or os.path.expanduser("~")
    return os.path.join(home, ".todo.json")


def load():
    """Load and return the list of task dicts (empty list if no store yet)."""
    path = db_path()
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, list):
        raise ValueError("corrupt store: expected a list")
    return data


def save(tasks):
    """Persist the list of task dicts to disk (atomically-ish)."""
    path = db_path()
    parent = os.path.dirname(path)
    if parent and not os.path.isdir(parent):
        os.makedirs(parent, exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(tasks, fh, indent=2)
    os.replace(tmp, path)


def next_id(tasks):
    """Return the next id to assign (max existing id + 1, or 1 if empty)."""
    if not tasks:
        return 1
    return max(t["id"] for t in tasks) + 1


def find(tasks, task_id):
    """Return the task dict with the given id, or None."""
    for t in tasks:
        if t["id"] == task_id:
            return t
    return None


def add_task(text):
    """Append a new (not-done) task with the given text. Returns the new id."""
    tasks = load()
    tid = next_id(tasks)
    tasks.append({"id": tid, "text": text, "done": False})
    save(tasks)
    return tid
