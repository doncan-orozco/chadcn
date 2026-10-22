# JavaScript controller tests (`test/javascript`)

The parity runner (`parity_run.mjs`) compares the Phlex port with the React oracle step by step, so it can only check what a scenario step can express and what React does identically. Everything else about a controller is tested here, in a real browser, against the real Phlex parity pages. There is no jsdom and no bundler: the pages load the importmap modules (Stimulus, controllers, primitives) exactly as in the app.

## Run

```bash
bin/rails test:javascript    # starts the dev servers, runs everything, stops them
```

One file (the dev servers must be running):

```bash
ruby .claude/scripts/shadcn/servers.rb start
node --test --test-reporter=spec test/javascript/popover.test.mjs
```

It uses the Playwright of `dev/react-shadcn-catalog` (`playwright_ensure.rb` makes sure a browser launches) and Node's built-in `node:test`; nothing new is installed. It is not part of `bin/ci` (it needs a browser and two dev servers).

## What belongs here

Behavior the runner cannot compare, per component spec ("Not expressible in the runner"):

- touch / pen input (`pointerType`), long press, `touchstart`;
- cancelable public events (`chadcn--x:escape-key-down`, `pointer-down-outside`, `interact-outside`, `open-auto-focus`, `close-auto-focus`) and a caller's `preventDefault`;
- positioner options (`hide_when_detached`, `update_position_strategy`, `collision_boundary`), shared by popover, hover-card and tooltip in `positioning.mjs`;
- nesting one layer in another (`nesting.test.mjs`: a popover or hover card inside a modal Dialog), which no scenario can render because a scenario tree may only use its own component.

Anything a scenario step can express stays a scenario (compared with React), not a test here.

## Writing a test

- `harness.mjs` exports `browserTest(name, fn, { touch })`: one browser per process, a fresh context and page per test, page errors fail the test. Set `browserTest.component` once per file.
- `support.mjs`: `openScenario` (waits for `networkidle`, which is when the importmap modules have loaded), `reconnectWithOptions` (rewrites a content template's `data-options` and reconnects the controller), `recordEvents` (collects a controller's public events, optionally preventing some).
- Every test that asserts a state should have a control that proves the assertion can fail (the touch tests have a mouse twin, `hide_when_detached=false` twin, the boundary test measures the unbounded placement first). Mutate the controller once to confirm a new test goes red, then revert.
- Prefer keyboard focus to open floating content (no hover timers). Radix hover timers are not cleared by Escape; do not assert on them here either.
