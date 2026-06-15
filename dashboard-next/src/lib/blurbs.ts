// Per-eval explainer copy. Keep these short.
export type Blurb = { summary: string; discriminates: string };

export const EVAL_BLURBS: Record<string, Blurb> = {
  "bug-fix": {
    summary:
      "Fix a Python script that crashes on header rows + non-numeric values. Modify the file in place.",
    discriminates:
      "Pi's exact-string-match edit tool. Small models hallucinate file contents; aider's whole-file rewrite avoids the failure.",
  },
  "cli-tool": {
    summary: "Greenfield: build a `wc` clone with --help that prints `<lines> <words> <chars> <path>`.",
    discriminates: "Whether the model uses the write tool for new files vs. dumping code in chat fences.",
  },
  refactor: {
    summary:
      "Extract a `customer_total(order)` function from three duplicated per-customer loops, preserving byte-identical output.",
    discriminates: "Semantic-preserving edits. Easy to break the output by mutating data or miscomputing.",
  },
  "wifi-stats": {
    summary: "Build a Next.js + FastAPI app that polls macOS wifi stats every 3s.",
    discriminates:
      "Multi-file scaffolding. Catches missing CORS, missing 'use client', missing layout.tsx, deprecated airport CLI.",
  },
  "chem-balance": {
    summary: "Implement chemical-equation balancing via element-count matrix null vector. 7 equations including KMnO4 redox.",
    discriminates: "Numerical stability. Naive numpy SVD blows up on KMnO4 - sympy or rational elimination required.",
  },
  "projectile-sim": {
    summary: "2D projectile motion with quadratic drag, RK4 integrator. Print range, max height, flight time.",
    discriminates: "RK4 vs Euler discipline. Vector velocity in drag term. Impact via interpolation.",
  },
  "great-circle": {
    summary: "Haversine distance + initial bearing for navigation. 7 city-pair test cases plus equator/pole edge cases.",
    discriminates: "Standard formula application + atan2 argument order + bearing normalisation to [0, 360).",
  },
  "password-strength": {
    summary: "5-level (0..4) password strength scorer with explicit reasons, blocklist, character classes, sequence detection.",
    discriminates: "Following exact scoring rules. Sequence detection (1234/qwer/etc.) is the trickiest part.",
  },
  "port-scanner": {
    summary: "TCP port scanner using only `socket` stdlib. Distinguish open/closed/filtered. Bulk-test 200 ports.",
    discriminates: "ConnectionRefusedError vs socket.timeout discrimination. No socket leaks.",
  },
  "sql-injection-fix": {
    summary: "Fix a vulnerable `lookup(con, name)` route that interpolates user input into SQL. Use parameterised queries.",
    discriminates: "Defensive security awareness - must use ? placeholders, not string escaping.",
  },
  finance: {
    summary: "mortgage_payment, amortization_table, npv, irr - fixed-income / project finance arithmetic.",
    discriminates: "IRR convergence (Newton/bisection) and amortization-table final balance == 0.",
  },
  engineering: {
    summary: "Reynolds number, beam deflection, RC tau, voltage divider - pure-formula physics/EE primitives.",
    discriminates: "Easy bar - measures whether the model knows the formulas without third-party libs.",
  },
  sudoku: {
    summary: "9×9 sudoku solver. 5 puzzles including Arto Inkala's 'world's hardest' (60s timeout).",
    discriminates: "Plain backtracking times out on hard puzzles; MRV heuristic separates competent solvers.",
  },
  "base64-codec": {
    summary: "RFC 4648 encode/decode WITHOUT importing base64. Manual bit-shift implementation.",
    discriminates: "Padding handling, invalid-char rejection, exact byte round-trip.",
  },
  levenshtein: {
    summary: "Edit distance + reconstructed edit path with op-list (match/sub/ins/del).",
    discriminates: "DP backtracking + path-applies-to-recover-target invariant.",
  },
  "lru-cache": {
    summary: "O(1) get/put with eviction, recency-on-update, capacity validation.",
    discriminates: "Whether updating an existing key marks it recent (commonly missed).",
  },
  "crc-checksum": {
    summary: "CRC-32 IEEE + CRC-16 XMODEM, manual bit-shift implementation. No `binascii`.",
    discriminates: "Reflected vs non-reflected polynomial conventions; init/xor-out values.",
  },
  "hamming-code": {
    summary: "Hamming(7,4) round-trip + single-bit error correction. Tests all 16 nibbles × 7 flip positions.",
    discriminates: "Syndrome-to-position mapping under chosen bit ordering.",
  },
  dijkstra: {
    summary: "Shortest path with non-negative weights + path reconstruction.",
    discriminates: "Tie-handling, source-equals-dest, no-path detection.",
  },
  knapsack: {
    summary: "0/1 knapsack DP with index reconstruction (7 cases inc. empty/zero-cap).",
    discriminates: "Index reconstruction from the DP table - easy to miscount.",
  },
  "unit-convert": {
    summary: "CLI: parse 'X unit Y unit ... to target_unit'. Length/mass/volume/temp/speed.",
    discriminates: "Multi-term sums + class-mismatch errors + temperature non-additivity.",
  },
  "regression-ci": {
    summary: "OLS linreg + Student-t 95% CI for the mean.",
    discriminates: "Sample-stdev (ddof=1) vs population, correct df for t-quantile.",
  },
  "fft-spectrum": {
    summary: "rfft-based magnitude spectrum + dominant frequency with DC rejection.",
    discriminates: "Bin-frequency mapping (k·fs/N), one-sided length (N//2+1), DC rejection.",
  },
  "matrix-ops": {
    summary: "Manual Gauss-Jordan determinant + inverse + matmul. numpy.linalg banned.",
    discriminates: "Partial pivoting + augmented-matrix elimination correctness.",
  },
  "julian-day": {
    summary: "Meeus-Jones-Butcher Easter + Gregorian Julian Day formula.",
    discriminates: "Algorithm fidelity for the 8+ integer-division steps; Jan/Feb=month-13/14 trick.",
  },
  "solar-position": {
    summary: "NOAA-style sun altitude/azimuth from lat/lon/UTC. 5 cities × 5 dates, ±2° tolerance.",
    discriminates: "JD → ecliptic → equatorial → horizontal coordinate-frame chain.",
  },
  "kalman-filter": {
    summary: "1D constant-velocity Kalman filter (predict/update/state/covariance).",
    discriminates: "Convergence to true velocity under noise; covariance growth without measurements.",
  },
  huffman: {
    summary: "build_codes + encode + decode with prefix-free property check.",
    discriminates: "Single-character edge case + tree-walk to assign codes.",
  },
  "json-schema": {
    summary: "Subset of JSON Schema (type/required/properties/items/min/max/enum/pattern).",
    discriminates: "bool-vs-int (Python bool is int subclass), error path formatting.",
  },
  "regex-engine": {
    summary: "Tiny regex matcher: . * + ? [...] [^...] [a-z] \\d \\w \\s - without `re`.",
    discriminates: "Greedy-with-backoff for *, anchor handling.",
  },
  "boolean-sat": {
    summary: "DPLL for CNF SAT. UNSAT detection + verifiable assignment.",
    discriminates: "Unit propagation + branching + clause simplification.",
  },
  "kepler-orbit": {
    summary: "2D two-body RK4 integrator. Energy conservation < 1e-3 over full orbit.",
    discriminates: "RK4 vs Euler (Euler drifts >5% in one orbit). Vector r̈ = -GM·r/|r|³.",
  },
  "dc-circuit": {
    summary: "Modified Nodal Analysis SPICE-lite (R/V/I components, ground reference).",
    discriminates: "MNA constraint rows for voltage sources; floating-subnetwork detection.",
  },
  "rate-limiter": {
    summary: "Token-bucket with lazy refill, capacity cap, cost validation.",
    discriminates: "Whether failed allow() consumes tokens (it shouldn't).",
  },
  "bloom-filter": {
    summary: "Probabilistic set with no-false-negative guarantee + multi-type keys.",
    discriminates: "Optimal m, k from (n, p) formulas; consistent hashing across add and contains.",
  },
};
