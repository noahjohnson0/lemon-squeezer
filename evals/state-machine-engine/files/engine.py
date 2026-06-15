"""Generic finite state-machine engine.

Implement the bodies below per the spec in prompt.md. Do not rename the public
symbols (InvalidTransition, Transition, StateMachine) or change their
signatures -- the test harness imports them by name.
"""


class InvalidTransition(Exception):
    """Raised when a transition is not allowed or is rejected by a guard."""
    pass


class Transition:
    """One allowed edge: event fires source -> dest, optionally gated by guard.

    Attributes:
        event (str), source (str), dest (str),
        guard (callable | None): guard(machine, **kwargs) -> bool
    """

    def __init__(self, event, source, dest, guard=None):
        raise NotImplementedError


class StateMachine:
    """A finite state machine. See prompt.md for full behavior."""

    def __init__(self, states, initial, transitions, on_enter=None):
        raise NotImplementedError

    @property
    def state(self):
        raise NotImplementedError

    def can_fire(self, event, **kwargs):
        """Return True iff `event` could fire from the current state now."""
        raise NotImplementedError

    def fire(self, event, **kwargs):
        """Fire `event`; return the new state or raise InvalidTransition."""
        raise NotImplementedError

    def available_events(self):
        """Sorted, de-duplicated event names with an edge from current state."""
        raise NotImplementedError
