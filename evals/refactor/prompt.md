Refactor `orders.py` in this directory. Requirements:

1. Extract the per-customer total calculation into a single function called `customer_total(order)` that takes one order dict and returns the float total for that customer.
2. Use that function for all three customers (no copy-pasted loops).
3. Compute the grand total by summing `customer_total(o)` for each `o in orders`.
4. The output (printed lines) must be **identical** to the original behaviour:
   ```
   alice paid 8.5
   bob paid 21.5
   carol paid 3.0
   grand total 33.0
   ```

Modify `orders.py` in place. Don't run it — just refactor it.
