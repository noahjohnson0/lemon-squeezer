import math

class Kalman1D:
    """Tracks position + velocity along one axis given noisy position measurements.

    State vector x = [position, velocity]^T.
    Transition: x_{k+1} = F x_k where F = [[1, dt], [0, 1]].
    Process noise covariance Q is provided at construction.
    Measurement model: z_k = H x_k + noise, with H = [1, 0] (we observe position only).

    Constructor:
      Kalman1D(initial_pos: float, initial_vel: float, process_var: float, measurement_var: float, dt: float = 1.0)

    Methods:
      predict() -> None              # advance time by dt, update mean + covariance
      update(z: float) -> None       # incorporate a position measurement
      state() -> tuple[float, float] # (position, velocity)
      covariance() -> list[list[float]]  # 2x2 estimate covariance P
    """
    
    def __init__(self, initial_pos: float, initial_vel: float, process_var: float, measurement_var: float, dt: float = 1.0):
        # State vector x = [position, velocity]^T
        self.x = [initial_pos, initial_vel]
        
        # Transition matrix F = [[1, dt], [0, 1]]
        self.F = [[1.0, dt], [0.0, 1.0]]
        
        # Measurement matrix H = [1, 0]
        self.H = [1.0, 0.0]
        
        # Process noise covariance Q
        self.Q = [[dt**3/3, dt**2/2], [dt**2/2, dt]]
        for i in range(2):
            for j in range(2):
                self.Q[i][j] *= process_var
        
        # Measurement noise covariance R
        self.R = measurement_var
        
        # Initial covariance matrix P
        self.P = [[1.0, 0.0], [0.0, 1.0]]
        
        # Time step
        self.dt = dt
    
    def predict(self) -> None:
        """Advance time by dt, update mean + covariance"""
        # Predict state: x_{k+1} = F * x_k
        x_new = [0.0, 0.0]
        for i in range(2):
            for j in range(2):
                x_new[i] += self.F[i][j] * self.x[j]
        self.x = x_new
        
        # Predict covariance: P_{k+1} = F * P_k * F^T + Q
        # F * P
        FP = [[0.0, 0.0], [0.0, 0.0]]
        for i in range(2):
            for j in range(2):
                for k in range(2):
                    FP[i][j] += self.F[i][k] * self.P[k][j]
        
        # F * P * F^T
        FPF = [[0.0, 0.0], [0.0, 0.0]]
        for i in range(2):
            for j in range(2):
                for k in range(2):
                    FPF[i][j] += FP[i][k] * self.F[j][k]
        
        # P_{k+1} = F * P * F^T + Q
        for i in range(2):
            for j in range(2):
                self.P[i][j] = FPF[i][j] + self.Q[i][j]
    
    def update(self, z: float) -> None:
        """Incorporate a position measurement"""
        # Innovation (measurement residual)
        y = z - self.H[0] * self.x[0] - self.H[1] * self.x[1]
        
        # Innovation covariance
        S = self.H[0] * self.P[0][0] + self.H[1] * self.P[1][0] + self.R
        
        # Kalman gain
        K = [0.0, 0.0]
        K[0] = self.P[0][0] * self.H[0] / S
        K[1] = self.P[1][0] * self.H[0] / S
        
        # Update state estimate
        self.x[0] = self.x[0] + K[0] * y
        self.x[1] = self.x[1] + K[1] * y
        
        # Update covariance
        # I - K * H^T
        I_KH = [[1.0 - K[0] * self.H[0], -K[0] * self.H[1]], 
                [-K[1] * self.H[0], 1.0 - K[1] * self.H[1]]]
        
        # P = (I - K * H^T) * P
        P_new = [[0.0, 0.0], [0.0, 0.0]]
        for i in range(2):
            for j in range(2):
                for k in range(2):
                    P_new[i][j] += I_KH[i][k] * self.P[k][j]
        
        self.P = P_new
    
    def state(self) -> tuple[float, float]:
        """(position, velocity)"""
        return (self.x[0], self.x[1])
    
    def covariance(self) -> list[list[float]]:
        """2x2 estimate covariance P"""
        return [self.P[0][:], self.P[1][:]]
