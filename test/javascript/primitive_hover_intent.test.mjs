import { assert, primitiveTest, useFakeTimers } from "./primitives_support.mjs";

const setup = async (page) => { await useFakeTimers(page) };

primitiveTest("hover_intent: enter() opens after openDelay as a delayed open; leave() before that cancels it", async (page) => {
  await setup(page);
  const result = await page.evaluate(async () => {
    const { hoverIntent } = await import("shadcn/primitives/hover_intent");
    const log = [];
    const intent = hoverIntent({ openDelay: 700, onOpen: (info) => log.push(["open", info.delayed]), onClose: () => log.push("close") });
    intent.enter();
    window.__clock.advance(699);
    const early = intent.isOpen;
    window.__clock.advance(1);
    const opened = intent.isOpen;
    intent.leave();
    intent.enter();
    intent.leave();
    window.__clock.advance(2000);
    return { early, opened, log, final: intent.isOpen };
  });
  assert.deepEqual(result, { early: false, opened: true, log: [["open", true], "close"], final: false });
});

primitiveTest("hover_intent: leave() honors closeDelay, and re-entering cancels the pending close", async (page) => {
  await setup(page);
  const result = await page.evaluate(async () => {
    const { hoverIntent } = await import("shadcn/primitives/hover_intent");
    let closes = 0;
    const intent = hoverIntent({ open: true, closeDelay: 300, onClose: () => closes++ });
    intent.leave();
    window.__clock.advance(299);
    const before = { open: intent.isOpen, closes };
    intent.enter();
    window.__clock.advance(5000);
    const reentered = { open: intent.isOpen, closes };
    intent.leave();
    window.__clock.advance(300);
    return { before, reentered, after: { open: intent.isOpen, closes } };
  });
  assert.deepEqual(result, { before: { open: true, closes: 0 }, reentered: { open: true, closes: 0 }, after: { open: false, closes: 1 } });
});

primitiveTest("hover_intent: open() and close() are immediate, fire only on transitions, and cancelOpen drops a pending open", async (page) => {
  await setup(page);
  const result = await page.evaluate(async () => {
    const { hoverIntent } = await import("shadcn/primitives/hover_intent");
    const log = [];
    const intent = hoverIntent({ onOpen: ({ delayed }) => log.push(`open:${delayed}`), onClose: () => log.push("close") });
    intent.open(); intent.open();
    intent.close(); intent.close();
    intent.enter();
    intent.cancelOpen();
    window.__clock.advance(5000);
    return { log, open: intent.isOpen, pending: window.__clock.pending() };
  });
  assert.deepEqual(result, { log: ["open:false", "close"], open: false, pending: 0 });
});

primitiveTest("hover_intent: sync() adopts a controlled state and clears the timers; release() clears them too", async (page) => {
  await setup(page);
  const result = await page.evaluate(async () => {
    const { hoverIntent } = await import("shadcn/primitives/hover_intent");
    let opens = 0;
    const intent = hoverIntent({ onOpen: () => opens++ });
    intent.enter();
    intent.sync(true);
    const afterSync = { open: intent.isOpen, pending: window.__clock.pending() };
    intent.leave();
    intent.enter();
    intent.release();
    window.__clock.advance(5000);
    return { afterSync, opens, pending: window.__clock.pending() };
  });
  assert.deepEqual(result, { afterSync: { open: true, pending: 0 }, opens: 0, pending: 0 });
});

primitiveTest("hover_intent: the provider skips the open delay right after a close and restores it after skipDelayDuration", async (page) => {
  await setup(page);
  const result = await page.evaluate(async () => {
    const { hoverIntent, hoverProvider } = await import("shadcn/primitives/hover_intent");
    const provider = hoverProvider({ skipDelayDuration: 300 });
    const log = [];
    const make = (name) => hoverIntent({ provider, openDelay: 700, onOpen: ({ delayed }) => log.push(`${name}:${delayed}`) });
    const first = make("first");
    const second = make("second");
    const initial = provider.isOpenDelayed;
    first.enter();
    window.__clock.advance(700);
    const whileOpen = provider.isOpenDelayed;
    first.close();
    const afterClose = provider.isOpenDelayed;
    second.enter(); // inside the skip window: immediate, not delayed
    const instant = second.isOpen;
    second.close();
    window.__clock.advance(300);
    const restored = provider.isOpenDelayed;
    return { initial, whileOpen, afterClose, instant, restored, log };
  });
  assert.deepEqual(result, { initial: true, whileOpen: false, afterClose: false, instant: true, restored: true, log: ["first:true", "second:false"] });
});

primitiveTest("hover_intent: skipDelayDuration <= 0 never changes the provider; release() clears the skip timer; isPointerInTransit is settable", async (page) => {
  await setup(page);
  const result = await page.evaluate(async () => {
    const { hoverProvider } = await import("shadcn/primitives/hover_intent");
    const never = hoverProvider({ skipDelayDuration: 0 });
    never.onOpen(); never.onClose();
    const provider = hoverProvider();
    provider.onOpen(); provider.onClose();
    const armed = window.__clock.pending();
    provider.release();
    provider.isPointerInTransit = true;
    return { never: never.isOpenDelayed, armed, afterRelease: window.__clock.pending(), transit: provider.isPointerInTransit, default: hoverProvider().isPointerInTransit };
  });
  assert.deepEqual(result, { never: true, armed: 1, afterRelease: 0, transit: true, default: false });
});
