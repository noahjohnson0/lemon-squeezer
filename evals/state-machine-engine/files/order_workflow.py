"""Order lifecycle built on the generic engine.

Implement the guard, the on_enter hooks, get_audit_log, and
build_order_machine per the spec in prompt.md. Standard library only.
"""

from engine import StateMachine, Transition, InvalidTransition  # noqa: F401


def has_funds(machine, **kwargs):
    """Guard for the `pay` event. True only if amount is present and <= 100."""
    raise NotImplementedError


def get_audit_log(machine):
    """Return the ordered list of on_enter hook events recorded on `machine`."""
    raise NotImplementedError


def build_order_machine():
    """Build and return a fresh, independent order StateMachine."""
    raise NotImplementedError
