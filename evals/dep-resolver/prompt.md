Write `resolver.py` exporting a single function `resolve(graph, root)` that
computes a valid **install order** for a package dependency graph.

```python
def resolve(graph: dict[str, list[str]], root: str) -> list[str]:
    """Return the install order for `root` and all its transitive dependencies.

    `graph` maps a package name -> list of the packages it directly depends on
    ("A": ["B", "C"] means A depends on B and C, so B and C must be installed
    BEFORE A).

    Rules:
      1. The returned list is a TOPOLOGICAL ORDER: every dependency appears
         strictly before the package that needs it. `root` is the LAST element.
      2. Only packages REACHABLE from `root` are included (do not install
         unrelated packages that happen to be in `graph`).
      3. DIAMOND dependencies are installed EXACTLY ONCE (no duplicates in the
         output), even when several packages share a common dependency.
      4. DETERMINISTIC TIE-BREAK: produce the LEXICOGRAPHICALLY-SMALLEST valid
         topological order. Concretely: at every step, among all packages whose
         dependencies are ALREADY installed, install the alphabetically-smallest
         one next (a greedy "smallest installable" frontier, i.e. Kahn's
         algorithm with a min-heap). Note this is NOT the same as installing in
         strict dependency "layers" - a package freed early can be installed
         before a same-layer sibling that sorts after it. The output must be
         byte-for-byte identical on every run and every machine for the same
         input.
      5. CYCLE DETECTION: if the reachable subgraph contains a dependency cycle,
         raise `CycleError`. The exception MUST carry the cycle as a `.cycle`
         attribute: a list of node names forming the loop, where the first and
         last element are the SAME node (e.g. ["A", "B", "A"]). The cycle must
         be reported in its CANONICAL ROTATION: it starts at the
         alphabetically-smallest node in the loop and lists the loop by
         following edges from there. A node depending on itself
         ("A": ["A"]) is the cycle ["A", "A"].
      6. MISSING DEPENDENCY: if any reachable package lists a dependency that is
         NOT a key in `graph`, raise `MissingDependencyError`. The exception
         MUST carry the offending name as a `.missing` attribute. If several
         dependencies are missing, report the alphabetically-smallest one.
         (Cycle detection is NOT required to look past missing deps - but a
         self-evident cycle that does not touch a missing node must still be
         detected; missing-dependency detection takes priority only when the
         SAME traversal would otherwise hit the missing node first.)
      7. If `root` itself is not a key in `graph`, raise
         `MissingDependencyError` with `.missing == root`.

    Define `CycleError` and `MissingDependencyError` in resolver.py. Both must
    subclass `Exception`.
    """
```

### Determinism, precisely

`resolve` must be a pure function of its arguments. Do not use sets in a way
that leaks iteration order into the output, do not depend on Python dict
insertion order for the tie-break, and do not use randomness or wall-clock.
Two graphs that are equal as data must produce identical output. The
alphabetical tie-break in rule 4 is what makes the order unique.

Worked example:

```
graph = {
    "app":  ["db", "web"],
    "web":  ["util"],
    "db":   ["util"],
    "util": [],
}
resolve(graph, "app") == ["util", "db", "web", "app"]
```

`util` is installed first (no deps). Then `db` and `web` are both free; `db`
sorts before `web`. Finally `app`. `util` appears once despite the diamond.

### Performance

The graph can be large (tens of thousands of nodes and edges). `resolve` must
run in roughly **linear** time in the size of the reachable subgraph
(O(V + E)). A solution that, for example, repeatedly rescans the whole node
set to find the next installable package (O(V^2)), or that re-walks shared
subtrees without memoizing, will time out on the large-graph check. Use an
explicit Kahn / DFS topological sort with a heap or sorted frontier for the
tie-break, not repeated linear scans.

Create only `resolver.py`. Do not run it, do not print anything.
