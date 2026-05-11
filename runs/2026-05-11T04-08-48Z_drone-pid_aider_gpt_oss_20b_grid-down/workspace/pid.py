class PID:
    """
    A simple PID controller with anti‑windup on the integral term.
    """

    def __init__(self, kp: float, ki: float, kd: float, setpoint: float = 0.0):
        """
        Initialize the PID controller.

        Parameters
        ----------
        kp : float
            Proportional gain.
        ki : float
            Integral gain.
        kd : float
            Derivative gain.
        setpoint : float, optional
            Desired target value. Defaults to 0.0.
        """
        self.kp = kp
        self.ki = ki
        self.kd = kd
        self.setpoint = setpoint

        # Internal state
        self._integral = 0.0
        self._prev_error = None  # None indicates first call

    def update(self, measurement: float, dt: float) -> float:
        """
        Compute control output given the current measurement and timestep.

        Parameters
        ----------
        measurement : float
            Current measured value.
        dt : float
            Time difference since the last update (seconds).

        Returns
        -------
        float
            Control output.
        """
        if dt <= 0:
            raise ValueError("dt must be positive")

        error = self.setpoint - measurement

        # Proportional term
        p = self.kp * error

        # Integral term with anti‑windup clamp
        self._integral += error * dt
        # Clamp integral to ±100
        if self._integral > 100.0:
            self._integral = 100.0
        elif self._integral < -100.0:
            self._integral = -100.0
        i = self.ki * self._integral

        # Derivative term
        if self._prev_error is None:
            d = 0.0
        else:
            d = self.kd * (error - self._prev_error) / dt

        # Update previous error for next call
        self._prev_error = error

        return p + i + d

    def reset(self) -> None:
        """
        Zero internal integral and previous-error state.
        """
        self._integral = 0.0
        self._prev_error = None

    def set_setpoint(self, setpoint: float) -> None:
        """
        Update the desired setpoint.

        Parameters
        ----------
        setpoint : float
            New target value.
        """
        self.setpoint = setpoint

    def set_gains(self, kp: float, ki: float, kd: float) -> None:
        """
        Update the PID gains.

        Parameters
        ----------
        kp : float
            New proportional gain.
        ki : float
            New integral gain.
        kd : float
            New derivative gain.
        """
        self.kp = kp
        self.ki = ki
        self.kd = kd
