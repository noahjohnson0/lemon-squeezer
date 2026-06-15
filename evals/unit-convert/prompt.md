Build `convert.py`, a CLI: `python3 convert.py "<expression>"`.

Parse natural-language conversion expressions of the form `"<value> <unit> [<value> <unit> ...] to <target_unit>"` and print the result as a single number to **4 decimal places** followed by space and the target unit, e.g. `170.1800 cm`.

Support these units (case-insensitive):
- Length: `mm`, `cm`, `m`, `km`, `in`, `ft`, `yd`, `mi` (or `mile`/`miles`)
- Mass: `mg`, `g`, `kg`, `oz`, `lb` (or `lbs`)
- Volume: `ml`, `l`, `gal` (US gallon = 3.785411784 L)
- Temperature: `c`, `f`, `k` (single value only - no addition)
- Speed: `mph`, `kph`, `m/s`

Multi-term inputs (like `"5 ft 7 in"`) are summed within a compatible unit class.
Conversion across classes (e.g. `5 kg to m`) → exit 1, print `error: <message>` to stderr.
Multi-term temperature inputs → exit 1 (offsets aren't linear).
Unknown units → exit 1.

Create only `convert.py`. Don't run it.
