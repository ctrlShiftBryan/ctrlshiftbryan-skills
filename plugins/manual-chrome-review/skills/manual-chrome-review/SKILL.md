---
name: manual-chrome-review
description: >
  Use when the user wants to manually verify a feature in a real running Chrome
  session — combining their keyboard/mouse input with Claude-driven DOM,
  network, WebSocket, and server-side inspection. Triggers include "manual
  chrome review", "verify in browser", "let's manually test this", "walk
  through my app in chrome", "live browser review", "review the new feature",
  or any time the user is about to drive a UI feature by hand and wants
  Claude to inspect state alongside them. Pair with the `monitor-active-chrome`
  skill for the WebSocket / console capture layer.
---

# Manual Chrome review with a live browser session

How to verify a web app feature by combining a real Chrome instance the
user drives with Claude-driven inspection of DOM, network, WebSocket
frames, and server-side state. Reusable across any web project.

## Why this workflow

The product is a browser-rendered web app. Most invariants live in things
only a real browser can produce: actual key events with their timing,
`getComputedStyle` results, font-rendering glyph fallbacks, focus state
across re-renders. Headless test runners can hit a CI gate, but they can't
tell you whether an icon font's glyphs render correctly or whether a
keyboard shortcut at human reflex speed lands within a chord-timeout
window.

So: the user drives the keyboard / mouse / eyes. Claude drives the rest.
The loop is **propose → execute → inspect**:

1. Claude proposes a concrete test ("press X, wait Y seconds, then Z").
2. User executes the action in their tab.
3. Claude immediately inspects state via `evaluate_script`, network logs,
   WebSocket frames, server-side files — confirming or falsifying the
   invariant.

## Prerequisites

- Chrome launched with `--remote-debugging-port=9222`. Easiest:
  ```bash
  open -a "Google Chrome" --args --remote-debugging-port=9222
  ```
- `chrome-devtools` CLI on PATH (`npm install -g chrome-devtools-mcp`).
- `monitor-active-chrome` skill installed — provides the three-layer
  capture stack (WebSocket frames, console buffer, network requests).
- `gh` authenticated, in case real bugs surface mid-cycle and need filing.

Verify Chrome is reachable: `curl -sf http://127.0.0.1:9222/json/version`.

## Session setup

1. **Pick the feature to verify.** Build a small task list (one entry per
   spec section / acceptance criterion) so progress is visible.

2. **Start the app server in the background** (so it survives terminal
   churn):
   ```bash
   nohup <start-cmd> > tmp/server.log 2>&1 & echo $! > tmp/server.pid
   ```
   The exact start command depends on the project — `npm run dev`,
   `bun run server.ts`, `cargo run`, whatever.

3. **Attach `chrome-devtools` to the running browser** and pin to the
   right tab:
   ```bash
   chrome-devtools start --browserUrl http://127.0.0.1:9222
   chrome-devtools list_pages              # find the app tab
   chrome-devtools select_page <index>
   ```

4. **Invoke the `monitor-active-chrome` skill** to install the three
   capture layers:
   - chrome-devtools CLI for HTTP / DOM / screenshot inspection
   - WebSocket frame capture to `.chrome-monitor/ws-frames.jsonl`
   - Console buffer at `window.__consoleLogs` (last 200 entries)

You now have a propose/execute/inspect loop ready.

## Split of labor

| Claude does                                 | User does                            |
| ------------------------------------------- | ------------------------------------ |
| HTTP probes (`curl`, status codes, cookies) | Keyboard input (chords, typing)      |
| DOM inspection (`evaluate_script`)          | Mouse drag (resize, drag-and-drop)   |
| Screenshots                                 | Visual judgment ("looks right?")    |
| WebSocket frame inspection                  | Subjective UX feedback               |
| Server kill / restart                       | Window resize / hard reload          |
| File reads (config, logs)                   | Reproducing race conditions          |
| State checks via filesystem                 |                                      |
| Filing GH issues mid-cycle                  |                                      |

The pattern: Claude proposes the test, user executes, Claude inspects
state immediately after via `evaluate_script` and friends.

## Inspection recipes

### DOM state of an arbitrary selector

```js
chrome-devtools evaluate_script '() => {
  return Array.from(document.querySelectorAll("<your-selector>")).map(el => ({
    id: el.id,
    classes: el.className,
    rect: { w: el.offsetWidth, h: el.offsetHeight },
    text: el.textContent?.slice(0, 80),
  }));
}'
```

### Computed style on the rendered element

`getComputedStyle` on an outer container often returns *inherited* values
(e.g. font-family from `<body>`). For fonts/colors/etc., probe the
*actual* descendant where the style takes effect. If a feature renders
text inside `.some-content`, query that, not the wrapper.

```js
getComputedStyle(document.querySelector("<rendered-element-selector>")).fontFamily
```

### Capture key event timing

When a chord or keyboard interaction acts flaky, inject a probe before
asking the user to reproduce:

```js
window.__keyProbe = [];
document.addEventListener("keydown", e => {
  window.__keyProbe.push({
    t: Date.now(), key: e.key, code: e.code,
    ctrl: e.ctrlKey, shift: e.shiftKey, alt: e.altKey, meta: e.metaKey,
  });
}, true);
```

Then dump `window.__keyProbe` after reproduction. Inter-event timing
often reveals a race between human reflex and an arbitrary timeout.

### Verify what bundle the server is actually serving

When a code change "doesn't take effect" in the browser, prove whether
the issue is server-side (stale bundle) or browser-side (cached asset):

```bash
curl -s -b "<auth-cookie-if-any>" <app-url>/<bundle-path> | grep "<expected-string>"
```

If the expected string appears in the curl output but not in the running
page, it's a browser cache issue → hard reload. If it doesn't appear in
curl either, the server is still serving the old build → restart the
dev server.

### Network requests during a flow

```bash
chrome-devtools list_network_requests
```

Useful for verifying request payloads, status codes, and timing right
after an action.

## Issue capture mid-cycle

When verification surfaces a real bug (not a guide error or a missing
prereq):

1. **Capture the evidence** while the system is in the failing state —
   probe log, screenshot, file dump. Preserves what you saw before any
   retry mutates state.

2. **File a GitHub issue** with `gh issue create --repo ...` using a body
   that reads like an implementer spec — file paths, expected behavior,
   actual behavior, scope of the fix, acceptance criteria. The richer
   the spec, the more an asynchronous implementer (or agent) can do
   without coming back to ask.

3. **Track the work** in whatever the project's task surface is (a
   to-do checklist file, a project board, an agent's queue) so it
   doesn't get forgotten between sessions.

## Generic pitfalls

These apply to most web projects:

- **Dev server caches the bundle at boot.** If the framework builds
  client code at startup (some Bun/Vite/esbuild configs), editing
  source requires a server restart, not just `Cmd+R` in the browser.
- **Soft reload may serve cached assets.** When verifying a code change
  landed, use a hard reload (`Cmd+Shift+R`) or append a cachebust query
  param. Soft reloads can hit Chrome's HTTP cache and serve the stale
  bundle.
- **`Closes #N` only auto-closes on merge to the default branch.**
  Pushing the closing commit to a feature branch does *not* change the
  issue state — the merge to main is what triggers GitHub's auto-close.
  Don't expect issues to close just because the work landed on a PR.
- **Inspect the rendered element, not the container.**
  `getComputedStyle` on a wrapper returns inherited values; for fonts,
  colors, sizing, query the actual text-bearing or rendered descendant.

## Cleanup

```bash
# Stop the app server
kill $(cat tmp/server.pid) 2>/dev/null

# Stop the monitoring stack
SKILL_DIR="$HOME/.claude/skills/monitor-active-chrome"
bash "$SKILL_DIR/scripts/setup.sh" stop
chrome-devtools stop
```

The app's user-state directory (cookies, tokens, persisted layouts)
typically survives by default so the next session resumes where you
left off. Only wipe it if the verification cycle wants a clean slate.

## When this is the wrong tool

- **Pure unit-testable invariants** → write a unit test, don't
  manual-verify.
- **Pure server-side concerns (auth flows, GC, file shape)** →
  `curl` + filesystem inspection is enough; you don't need the browser.
- **Headless-reproducible scenarios** → port to a Playwright/Cypress
  test where it can run in CI.

This workflow earns its keep on UI-affecting changes where human
perception or human-speed input matters, plus the diagnostic loop when
something is failing and you don't yet know whether it's the code,
the test, or the test-driver.
