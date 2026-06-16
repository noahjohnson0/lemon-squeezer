Build an interactive particle / physics toy as a single `index.html` rendered on an HTML `<canvas>`.

Requirements:
- ONE self-contained file named `index.html` in the workspace root. All HTML, CSS and JS inline. No external dependencies, no CDN, no build step, no frameworks.
- Render to a `<canvas>` element using its 2D context (`getContext('2d')`).
- Many particles animate continuously in a smooth loop driven by `requestAnimationFrame`. Each frame: clear/fade the canvas, update particle positions/velocities, redraw.
- The simulation reacts to the mouse: particles attract toward or repel from the cursor, and/or new particles spawn on click. Wire this up with `addEventListener` for `mousemove` and `click` (or `mousedown`).
- The canvas fills the browser window and resizes when the window resizes (`addEventListener('resize', ...)` updating `canvas.width`/`canvas.height`).
- It should look good on its own with no instructions - the toy starts animating immediately on load.

Write the file as `index.html` in the workspace root. Do not run it.
