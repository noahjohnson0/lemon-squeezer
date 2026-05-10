Write `circuit.py` exporting a SPICE-lite DC circuit solver via Modified Nodal Analysis (MNA):

```python
def solve(netlist: str) -> dict[str, float]:
    """Solve a SPICE-style DC netlist for node voltages.

    The netlist is one component per line:
      R<name> nodeA nodeB <ohms>     # resistor
      V<name> nodeA nodeB <volts>    # ideal voltage source: V(nodeA) - V(nodeB) == volts
      I<name> nodeA nodeB <amps>     # ideal current source: amps flow from nodeA -> nodeB
    Lines starting with '#' or empty are ignored.
    The reference node is named 'gnd' and is held at 0 V.

    Return {node_name: voltage} for every non-ground node. Raise ValueError
    on a singular system (floating subnetwork)."""
```

You MAY use `numpy` (numpy.linalg.solve is fine for the linear system).
Modified Nodal Analysis: build an (n+m) × (n+m) matrix where n = number of
non-ground nodes and m = number of voltage sources; KCL rows for nodes,
constraint rows for voltage sources.

Create only `circuit.py`. Don't run it.
