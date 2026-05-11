# Eval categories — the grid-down skills framework

When the cloud is unreachable, what can a local LLM running on a 4070 (or M4
Max, or any future hardware) actually *do for you*? This file is the master
map. Each row points to existing evals or candidate evals; the philosophy is
that any humanly-useful skill should be measurable here, either as a coding
eval (`prompt → working Python`) or a librarian eval (`prompt → grounded
answer`).

## The two eval shapes

| Shape | Harness | What rubric verifies |
|---|---|---|
| **Coding** | aider / squeezer / squeezer-tdd / squeezer-critique / squeezer-architect / squeezer-verify / squeezer-search | running the produced code, checking outputs against known references |
| **Librarian** | qa / librarian / librarian-cascade | grep / regex over `answer.txt` for required facts, correct citations, abstention when not in corpus |

The same skill can have BOTH shapes — e.g. epidemiology has a coding eval
(implement an SIR solver) and a librarian eval ("what's the reproduction
number for measles" given a public-health corpus).

## Existing eval coverage (35 evals)

See `RUNS.md` / `findings.md` for live data. Broadly:

- **Foundational coding**: lru-cache, knapsack, levenshtein, dijkstra, hamming-code, crc-checksum, base64-codec, julian-day, matrix-ops
- **Scientific computing**: kepler-orbit, kalman-filter, chem-balance, projectile-sim, double-pendulum, fft-spectrum
- **Cyber/security**: port-scanner, password-strength, hash-collision
- **CLI/tools**: cli-tool, bug-fix
- **RAG/librarian**: truthfulqa-mc, needle-haystack, wiki-rag, wiki-rag-tool

## New categories to add (grid-down framework)

### 🚁 Robotics, drones, autonomy

| Eval | Shape | What it tests |
|---|---|---|
| **drone-pid** ✅ | coding | PID controller for altitude hold; step-response, no oscillation |
| **slam-particle-filter** ✅ | coding | 1D particle filter; convergence to ground truth |
| **robot-arm-ik** ✅ | coding | 2-link planar arm inverse kinematics |
| drone-waypoints | coding | great-circle distance + bearing sequencing |
| ekf-localize | coding | extended Kalman filter for differential drive robot |
| occupancy-grid | coding | raster from lidar scans |
| icp-align | coding | iterative-closest-point on 2D point clouds |
| mavlink-parser | coding | decode a MAVLink message stream |
| pid-tuning | librarian | Ziegler-Nichols method, when to use vs PID variants |

### 🏥 Medicine, first aid, public health

| Eval | Shape | What it tests |
|---|---|---|
| **first-aid-triage** ✅ | librarian | START triage on patient list; assign red/yellow/green/black |
| **epidemiology-sir** ✅ | coding | SIR model with RK4 integration |
| drug-interaction | librarian | given list of meds, flag known interactions |
| dose-pediatric | coding | mg/kg dose calc with safety bounds, route-of-admin caveats |
| seir-outbreak | coding | SEIR with vaccinated compartment |
| r0-from-trace | coding | estimate R₀ from contact-tracing data |
| symptoms-differential | librarian | differential diagnosis from symptom list, cite a medical reference |
| wound-care | librarian | clean+dress procedure by wound type |
| burn-rule-9 | coding | total body-surface burn % from body-region inputs |
| bls-cpr-protocol | librarian | adult/child/infant CPR steps + rate |

### 🥋 Martial arts, self-defense, physical training

| Eval | Shape | What it tests |
|---|---|---|
| belt-curriculum | librarian | given style + rank, list required techniques |
| fitness-plan | coding | generate a 4-week mesocycle with periodization for a goal |
| recovery-protocol | librarian | post-injury PT progression by injury type |
| BJJ-position-flow | librarian | given starting position, list common transitions/submissions |

(Note: martial arts is mostly librarian-shaped — there's no "execute this
roundhouse and verify" reductive test. The value is reliable retrieval from
curriculum/technique docs.)

### 🌾 Agriculture, food, foraging

| Eval | Shape | What it tests |
|---|---|---|
| crop-rotation | coding | given soil + climate, generate 3-year rotation plan |
| seed-spacing | coding | row/plant spacing math for a garden plot |
| compost-cn-ratio | coding | balance carbon/nitrogen ratio in a compost mix |
| canning-times | librarian | safe pressure-canning time by food + altitude |
| edible-id | librarian | from feature description, identify plant (with abstain if unsure) |
| brewing-mash | coding | water-to-grain ratio + strike-temp calc |
| food-preservation | librarian | salt-cure, smoke, dry, ferment — when to use which |

### ⚡ Energy, power, off-grid systems

| Eval | Shape | What it tests |
|---|---|---|
| solar-sizing | coding | given load profile + insolation, size panels/battery/inverter |
| battery-runtime | coding | Peukert's law, depth-of-discharge limits |
| wire-gauge | coding | NEC wire-size lookup for amperage + run length |
| generator-fuel | coding | runtime from tank + load + efficiency curve |
| windmill-power | coding | swept-area power calc for turbine sizing |
| inverter-surge | coding | continuous vs surge wattage for motor loads |

### 💧 Water, sanitation

| Eval | Shape | What it tests |
|---|---|---|
| **water-purify-bleach** ✅ | coding | 5% NaOCl dose by volume + clarity, CDC values |
| boil-time-altitude | coding | boiling-point + min boil-time by altitude |
| filter-pore-size | librarian | micron size needed for bacteria/protozoa/virus |
| rainwater-collect | coding | catchment-area × rainfall → gallons |
| latrine-spacing | coding | distance-to-water-table safe sites |
| chlorine-test | coding | residual-chlorine ppm calc |

### 📡 Communications

| Eval | Shape | What it tests |
|---|---|---|
| **ham-radio-antenna** ✅ | coding | dipole/quarter-wave length math by band |
| morse-encode | coding | text → morse with timing |
| nato-phonetic | coding | alphabet-spelling table; tolerant to case/punct |
| frequency-allocation | librarian | which bands need which license class (US/intl) |
| repeater-offset | coding | repeater input/output frequency math |
| dipole-balun | librarian | when to use 1:1 vs 4:1 balun |

### 🧭 Navigation, surveying

| Eval | Shape | What it tests |
|---|---|---|
| dead-reckoning | coding | new position from heading+speed+time |
| celestial-sun-alt | coding | sun altitude/azimuth from lat/lon/date/time |
| great-circle | coding | haversine distance + bearing between two lat/lon points |
| utm-convert | coding | lat/lon ↔ UTM grid coords |
| compass-declination | librarian | magnetic vs true north correction for a location/year |
| pace-count | coding | calibrate stride-per-100m, convert pace count → distance |

### 🏗️ Construction, repair, fabrication

| Eval | Shape | What it tests |
|---|---|---|
| joist-span | coding | allowable span by lumber size + species + load |
| concrete-mix | coding | yards of concrete + cement/sand/gravel ratio |
| roof-pitch | coding | rise/run/length math, rafter cut angles |
| cut-list-optimizer | coding | bin-packing for cuts from standard lumber lengths |
| knot-recommend | librarian | given use case (load-bearing? slip-free? easy-untie?), pick knot |
| pipe-flow | coding | Hazen-Williams pressure drop |

### 🛡️ Cryptography, security (grid-down style)

| Eval | Shape | What it tests |
|---|---|---|
| one-time-pad | coding | OTP encode/decode with shared key |
| vigenere | coding | classical cipher implementation |
| diffie-hellman-toy | coding | key exchange with small numbers |
| password-entropy | coding | bits-of-entropy calc from charset |
| caesar-break | coding | frequency analysis to break Caesar cipher |

### 🌦️ Weather, environmental

| Eval | Shape | What it tests |
|---|---|---|
| heat-index | coding | NWS heat-index formula |
| wind-chill | coding | NWS wind-chill formula |
| dew-point | coding | Magnus formula |
| pressure-altitude | coding | hypsometric equation |
| storm-distance | coding | flash-to-bang seconds → miles |

### 🗳️ Politics, civics, history

| Eval | Shape | What it tests |
|---|---|---|
| voting-irv | coding | instant-runoff tabulation |
| voting-condorcet | coding | Condorcet winner from ballots |
| districting-compactness | coding | Polsby-Popper score for a polygon |
| constitution-cite | librarian | "where does the X amendment say Y?" — must cite article/section |
| historical-event | librarian | grounded date + brief from a history corpus |

### 🐾 Animal care, vet basics

| Eval | Shape | What it tests |
|---|---|---|
| vet-dose | coding | weight-based dose for common drugs; species safety |
| gestation-table | librarian | gestation periods by species |
| feed-conversion | coding | feed-to-weight-gain ratios |

### 🍳 Domestic, kitchen, household

| Eval | Shape | What it tests |
|---|---|---|
| recipe-scale | coding | linear/non-linear scaling (baking exceptions) |
| sourdough-feeding | librarian | starter feed schedule + ratio |
| dye-mordant | librarian | natural dye + mordant combinations |
| stain-removal | librarian | by stain type + fabric |

## Conventions for adding evals

1. `mkdir evals/<name>` and inside it: `prompt.md`, `rubric.sh`, optionally
   `setup.sh` + `files/`.
2. Coding evals: write the prompt as a single self-contained task description.
   Specify the file name(s) the model should produce. Avoid ambiguity — small
   local models are sensitive to vague specs.
3. Rubric MUST: only emit JSON on stdout, every echo of debug → stderr (we
   lost score data once to this). Include a `used_search_tool` or `used_X`
   check for librarian evals so a model can't get full credit by guessing.
4. Always self-test with a known-good reference impl in `/tmp/` aiming for
   100% on the reference. See top of CLAUDE.md for the snippet.
5. Choose weights so the eval scales to ~100 total points and the easy parts
   don't dominate (e.g. "file exists" should be ≤5, not ≥20).

## Long-term: cross-domain skills

Some evals span domains and would benefit from a "skill panel" view in the
dashboard:

- **Math everywhere**: ODE solvers (SIR, drone PID, Kepler, RK4) are the
  same skill in different costumes — a single failure pattern reveals it
- **Citation discipline**: librarian evals across domains should be scored
  by the same `cite_real_file` + `abstain_when_absent` cross-cutters
- **Numerical safety**: doses (medicine, vet, water purification) all need
  hard upper/lower bounds — a rubric module could check "did the model
  refuse out-of-range inputs"

The goal of this framework is not just to test — it's to **discover** which
combinations of (hardware, model, harness, RAG corpus) actually make a local
machine *useful* for a grid-down lifestyle. Right now we have evidence that
gpt-oss:20b @ librarian harness is the gold standard for factual lookup, and
gemma4:e4b @ librarian is the fast/honest daily driver. We need analogous
findings for every category above.
