The file `csv_total.py` in this directory is supposed to print the sum of the `amount` column of a CSV file. Right now `python csv_total.py data.csv` crashes.

Fix `csv_total.py` so that:
1. It correctly skips the header row.
2. It silently ignores any row whose amount is not a valid integer (does not crash on `not_a_number` etc.).
3. For the included `data.csv`, `python csv_total.py data.csv` should print exactly `100`.

Modify `csv_total.py` in place. Don't run the script - just fix it.
