Build a fully playable **Snake** game as ONE self-contained `index.html`.

Requirements:

- The whole game lives in a single file named `index.html` at the workspace root.
- All CSS and JavaScript are **inline** (in `<style>` and `<script>` tags). No
  external scripts, no stylesheets, no images, no CDN, no build step, no
  dependencies whatsoever.
- Render the game on an HTML5 `<canvas>` using its 2D context (`getContext`).
- Drive the game loop with `requestAnimationFrame` (you may throttle the snake's
  step rate, but the animation loop itself should use `requestAnimationFrame`).
- Control the snake with the **arrow keys AND WASD** via a `keydown` listener
  (`addEventListener('keydown', ...)`). The snake cannot reverse directly back on
  itself.
- The snake **grows** by one segment each time it eats a piece of **food**. Food
  spawns at a new random cell after being eaten.
- Show the current **score** somewhere on the page and increment it as the snake
  eats.
- **Game over** when the snake hits a wall or runs into its own body. On game
  over, display a message and allow the player to **restart** (a key press or a
  button) without reloading the page.

Write only the file `index.html`. Do not run it.
