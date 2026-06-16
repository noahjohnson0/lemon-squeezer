Build an interactive 3D scene as a SINGLE self-contained `index.html` file using three.js.

Requirements:

- Write the file as `index.html` in the workspace root. Everything (markup, CSS, JavaScript) lives in that one file.
- The ONLY allowed external dependency is three.js, loaded from a CDN via a `<script>` tag (for example `https://unpkg.com/three@0.160.0/build/three.min.js` or a similar CDN URL). Do not use a bundler, npm, imports of other libraries, or any build step.
- Render a lit, rotating 3D object - e.g. a colored or textured cube, sphere, or torus-knot - inside a `WebGLRenderer` canvas that fills the page.
- Add at least one light (e.g. a `DirectionalLight` or `PointLight`, plus optional ambient) so the object is actually shaded, not flat.
- Implement an animation loop with `requestAnimationFrame` that continuously rotates/animates the object.
- Implement mouse-drag orbit: dragging the mouse should rotate the camera or the object around it. You may hand-roll this with `mousedown` / `mousemove` / `mouseup` listeners, or use three.js `OrbitControls` if you load it from the same CDN. Either way, dragging the mouse must visibly change the view.
- Inline all CSS in a `<style>` block and all JS in a `<script>` block (other than the three.js CDN script). No external `.css` or `.js` files.

Keep it to one file, no build step, runnable by just opening `index.html` in a browser.
