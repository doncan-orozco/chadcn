# Combobox scroll-lock browser test flake (#201)

## Symptom

`combobox: a modal popup locks the page scroll and closes on a backdrop press` failed intermittently on CI (PR #195 run
39383808766, also seen on #196, #198 and one main run) and never locally:

```
✖ combobox: a modal popup locks the page scroll and closes on a backdrop press (806.704247ms)
  AssertionError [ERR_ASSERTION]: Expected values to be strictly equal:
  1 !== 0
      at .../test/javascript/combobox.test.mjs:333:10
```

Line 333 is `assert.equal(await page.locator(popup).count(), 0)` after `page.mouse.click(5, 5)` + `settle`: the press on the
backdrop did not close the popup. The two assertions before it (scroll lock attribute, one backdrop) had passed.

## Probable root cause: test timing against a deliberately deferred listener

Consistent with the deterministic emulation below; the CI failure itself cannot be re-observed on demand. Judge it by green CI reruns.

`primitives/dismissable_layer.js` registers its `pointerdown` listener in `setTimeout(..., 0)`, exactly like Radix, so the event
that opened the layer cannot close it. The scroll lock, the backdrop and `aria-hidden` are applied synchronously at open. So
"locked + backdrop present" does not prove the outside press is armed, and the test pressed right after `page.click(input)` with
only evaluate round trips in between. On a starved runner the renderer handles the injected press before that zero-delay timer
task runs, the press is not heard, and the popup stays (`1 !== 0`).

It is not a controller race worth fixing: the deferral is the Radix contract (radix-stimulus R8/R9), no human can press inside
that task, and removing it would let the opening press close the popup. The controller is unchanged.

## Reproduction

- Natural load did not reproduce it here: 30 runs under 20 busy-loop burners (plus about 6 other workers) never failed. That
  stress also made the shared machine unusable for the other workers, so it was dropped.
- Deterministic emulation of the starved timer queue: `SHADCN_TEST_TIMER_DELAY_MS=300` (knob added to `test/javascript/harness.mjs`, `browserTest` pages only; a non-numeric or negative value throws)
  makes every zero-delay `setTimeout` of the page fire 300 ms late while input is delivered at once.
  - Before the fix: `SHADCN_TEST_TIMER_DELAY_MS=300 node --test --test-name-pattern="modal popup locks" test/javascript/combobox.test.mjs`
    fails 10/10 with `1 !== 0` at the same assertion as CI.
  - After the fix: the same command passes 30/30 consecutive runs (and the unloaded gate passes).
- Load hygiene only (it did not reproduce the failure): if a CPU burner is wanted anyway, `nice -n 19` on at most 6 busy loops (cores minus 4).

## Fix

The test calls `settle(page)` after opening. `settle` ends with a zero-delay `setTimeout`, queued behind the controller's own, so
when it resolves the listener is armed (same ordering holds under the delayed-timer emulation, since both timers get the same
delay). The assertions are unchanged and exactly as strong: lock present while open, one backdrop, popup gone and lock released
after the backdrop press. Nothing was loosened and no other test was edited.
