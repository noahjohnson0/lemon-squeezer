# Finish the todo CLI

You are given a small todo-list command-line app under `app/`:

- `app/storage.py` - JSON persistence. **Complete and working; do not break it.**
  Read it to learn the data model. Each task is a dict
  `{"id": <int>, "text": <str>, "done": <bool>}`, stored as a JSON list in the
  file returned by `storage.db_path()`.
- `app/cli.py` - the command dispatcher. `add` and plain `list` already work.
  Three things are stubbed out with `NotImplementedError` and must be finished.

The CLI is invoked as `python app/cli.py <command> ...`. Implement the missing
behavior so that **all** of the following work. Match the exact stdout strings
and exit codes described - they are checked literally.

## 1. `done <id>` - mark a task complete

- `python app/cli.py done 2` sets the `done` flag of task #2 to `true`,
  persists the change, and prints exactly:

  ```
  done #2
  ```

  then exits `0`.
- If no task with that id exists, print an error to **stderr** (any message)
  and exit with a **non-zero** status. Stdout must not contain `done #<id>`.
- If the id argument is missing or not an integer, print an error to stderr and
  exit non-zero.
- Marking an already-done task done again is allowed (still prints `done #<id>`,
  exits 0).

## 2. `rm <id>` - delete a task

- `python app/cli.py rm 1` removes task #1 from the store, persists, and prints
  exactly:

  ```
  removed #1
  ```

  then exits `0`. After removal, that task must no longer appear in `list`
  output, and the ids of the remaining tasks must be unchanged.
- If no task with that id exists, print an error to stderr and exit non-zero.
- If the id argument is missing or not an integer, print an error to stderr and
  exit non-zero.

## 3. `list --pending` - show only unfinished tasks

- `python app/cli.py list --pending` prints only the tasks whose `done` flag is
  `false`, in id order, using the **same line format** as plain `list`:

  ```
  [ ] #3 walk the dog
  ```

  (a single space inside the brackets for a pending task).
- If there are no pending tasks, print exactly `(no tasks)` and exit `0`.
- Plain `list` (no flag) must keep showing all tasks, done ones rendered with an
  `x`: `[x] #2 buy milk`.

## Constraints

- Edit `app/cli.py` (and only `app/cli.py`); keep using `app/storage.py` for all
  reads and writes so state persists across separate process invocations.
- Do not change the on-disk JSON format or the `storage.py` public functions.
- Ids must never be renumbered or reused after a delete.
