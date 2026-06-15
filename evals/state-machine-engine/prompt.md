# Build a workflow state-machine engine

You are implementing a small, reusable **finite state-machine engine** plus a
concrete **order lifecycle** definition that runs on top of it. The starter
files in this workspace contain stub signatures and docstrings only — fill them
in. Do **not** change the public names, signatures, or module layout; the test
harness imports these exact symbols.

## Files

- `engine.py` — the generic, domain-agnostic engine: the `StateMachine` class,
  the `Transition` dataclass/record, and the `InvalidTransition` exception.
- `order_workflow.py` — uses `engine.py` to build the order state machine
  (`build_order_machine()`), plus the guard functions it references.

You may NOT add third-party dependencies. Standard library only.

---

## `engine.py`

### `class InvalidTransition(Exception)`
Raised when a transition is attempted that is not allowed from the current
state, or whose guard rejects it. Already declared as a stub — keep it a
subclass of `Exception`.

### `class Transition`
A record describing one allowed edge. It has these attributes:
- `event` (str): the name of the event/trigger that fires this transition.
- `source` (str): the state the machine must be in for this edge to apply.
- `dest` (str): the state the machine moves to.
- `guard` (callable or None): optional `guard(machine, **kwargs) -> bool`.
  When present and it returns a falsy value, the transition is **rejected**
  (treated exactly like a disallowed transition — see `fire` below).

### `class StateMachine`

Constructor: `StateMachine(states, initial, transitions, on_enter=None)`
- `states`: an iterable of valid state-name strings.
- `initial`: the starting state. Must be one of `states`, else raise
  `ValueError`.
- `transitions`: an iterable of `Transition` records. Every transition's
  `source` and `dest` must be in `states`, else raise `ValueError`.
- `on_enter`: optional `dict[str, callable]` mapping a state name to a hook
  `hook(machine, **kwargs)` called **every time that state is entered**,
  INCLUDING when the machine is first constructed in the `initial` state.
  (So if `initial` has an `on_enter` hook, it fires once during construction.)

Attributes / properties you must expose:
- `state` (str): the current state.
- `history` (list[str]): the ordered list of states the machine has been in,
  **starting with the initial state**. After construction it is `[initial]`.
  Each successful `fire` appends the new state. A rejected/invalid transition
  does **not** modify history.

Methods:

- `can_fire(event, **kwargs) -> bool`
  Returns `True` iff there exists a transition whose `event == event` and
  `source == self.state` **and** whose guard (if any) returns truthy when
  called as `guard(self, **kwargs)`. Does not change state. Never raises.

- `fire(event, **kwargs) -> str`
  Performs the transition for `event` from the current state.
  1. Find the transition matching `event` + current state.
  2. If none exists, raise `InvalidTransition` with a message that contains
     both the event name and the current state.
  3. If it has a guard and `guard(self, **kwargs)` is falsy, raise
     `InvalidTransition` (guard rejected).
  4. Otherwise set `self.state = dest`, append `dest` to `history`, then call
     the `on_enter` hook for `dest` if one is registered (passing
     `(self, **kwargs)`), and finally return the new state.
  If two transitions match the same `event`+`source`, the **first** one in the
  `transitions` iterable wins.

- `available_events() -> list[str]`
  The sorted, de-duplicated list of event names that have **any** transition
  from the current state (ignoring guards — purely structural).

---

## `order_workflow.py`

Model an e-commerce order. States:

```
cart -> pending -> paid -> shipped -> delivered
```

with side-branches `cancelled` and `refunded`.

### States
`"cart"`, `"pending"`, `"paid"`, `"shipped"`, `"delivered"`, `"cancelled"`,
`"refunded"`. Initial state is `"cart"`.

### Transitions (event : source -> dest)
- `checkout`  : `cart`     -> `pending`
- `pay`       : `pending`  -> `paid`     (guarded by `has_funds`)
- `ship`      : `paid`     -> `shipped`
- `deliver`   : `shipped`  -> `delivered`
- `cancel`    : `cart`     -> `cancelled`
- `cancel`    : `pending`  -> `cancelled`
- `cancel`    : `paid`     -> `cancelled`
- `refund`    : `paid`     -> `refunded`
- `refund`    : `shipped`  -> `refunded`

Note `cancel` and `refund` are each used by multiple edges — that's expected;
the right edge is selected by the current state.

### Guard: `has_funds(machine, **kwargs) -> bool`
Returns `True` only if the keyword argument `amount` is present and
`amount <= 100`. (Funds cap is exactly 100. Missing `amount` → reject.)
So `fire("pay", amount=50)` succeeds from `pending`; `fire("pay", amount=200)`
is rejected with `InvalidTransition`; `fire("pay")` (no amount) is rejected.

### `on_enter` hooks
Register an `on_enter` hook for the `"shipped"` state that appends the string
`"shipped"` to a module-level (or machine-attached) audit list, AND a hook for
`"delivered"` that appends `"delivered"`. Expose the audit log so a caller can
read it: implement `get_audit_log(machine) -> list[str]` returning the list of
hook events recorded for that machine in order. (Hint: store the list on the
machine instance, e.g. `machine.audit`, and have the hooks append to it.)

### `build_order_machine() -> StateMachine`
Constructs and returns a fresh order `StateMachine` wired with the states,
transitions, guards, and on_enter hooks above. Each call returns an
independent machine (independent state, history, and audit log).

---

## Acceptance

A correct solution will, for a fresh machine:
- start in `cart` with `history == ["cart"]`;
- walk `checkout -> pay(amount=50) -> ship -> deliver` ending in `delivered`
  with the full history recorded;
- reject `pay` with `amount=200` and reject `ship` from `cart` by raising
  `InvalidTransition` (without corrupting state or history);
- report `can_fire` / `available_events` correctly per state;
- record `["shipped", "delivered"]` in the audit log after a full happy path.
