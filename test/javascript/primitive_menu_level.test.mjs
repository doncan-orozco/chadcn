import { assert, frames, primitiveTest } from "./primitives_support.mjs";

// menu_level: the react-menu mechanics shared by dropdown-menu, context-menu and menubar, driven here with a stand-in
// controller (the values, dispatch and flags MenuLevel reads) and hand-built templates. The defaults are the DropdownMenu
// root; a custom `behavior` (the menubar's case) replaces the data-attribute prefix, the sub trigger slot, modality and
// the root hooks, and every sub level inherits it.
const markup = (prefix, slot) => `
  <button id="anchor">Open</button>
  <template data-${prefix}-template="root" data-options='{"side":"bottom"}'>
    <div data-radix-menu-content data-slot="${slot}-content" role="menu" tabindex="-1">
      <div role="menuitem" data-radix-collection-item tabindex="-1">Apple</div>
      <div role="menuitemradio" data-radix-collection-item data-${prefix}-value="banana" tabindex="-1">Banana</div>
      <div role="menuitem" data-radix-collection-item data-slot="${slot}-sub-trigger" data-${prefix}-sub-content-id="sub" data-state="closed" tabindex="-1">More</div>
      <template data-${prefix}-template="sub" data-options='{}'>
        <div data-radix-menu-content data-slot="${slot}-sub-content" role="menu" tabindex="-1">
          <div role="menuitem" data-radix-collection-item tabindex="-1">Cherry</div>
        </div>
      </template>
    </div>
  </template>
  <button id="outside">Outside</button>`;

// window.__controller(): the stand-in controller; every dispatch and requestOpen lands in its log.
const installController = (page) => page.evaluate(() => {
  window.__controller = () => {
    const element = document.getElementById("anchor");
    const log = [];
    return {
      element, log, root: null, modalValue: true, hasInteractedOutside: false, usingKeyboard: true, disconnecting: false,
      dirValue: "ltr", subOpenDelayValue: 0, pointerGraceTimeoutValue: 300, typeaheadTimeoutValue: 1000,
      requestOpen(next) { log.push(`requestOpen:${next}`) },
      dispatch(name, { target = element, detail, cancelable = true } = {}) {
        const event = new CustomEvent(`menu:${name}`, { bubbles: true, cancelable, detail });
        target.dispatchEvent(event);
        log.push(detail?.value !== undefined ? `${name}:${detail.value}` : detail?.open !== undefined ? `${name}:${detail.open}` : name);
        return event;
      },
    };
  };
});

const focusedText = (page) => page.evaluate(() => document.activeElement?.getAttribute("role") === "menuitem" ? document.activeElement.textContent.trim() : document.activeElement?.getAttribute("data-slot") ?? document.activeElement?.id);

primitiveTest("menu_level: the default behavior is the DropdownMenu root (modal, requestOpen, root cleared on teardown)", async (page) => {
  await installController(page);
  await page.evaluate(async () => {
    const { MenuLevel } = await import("chadcn/primitives/menu_level");
    const controller = (window.__ctl = window.__controller());
    const template = document.querySelector("template[data-chadcn--dropdown-menu-template=root]");
    controller.root = window.__level = new MenuLevel(controller, { anchor: controller.element, template });
    controller.root.mount();
  });
  await frames(page);
  const mounted = await page.evaluate(() => {
    const level = window.__level;
    return {
      portaled: level.content.closest("[data-radix-popper-content-wrapper]").parentElement === document.body,
      state: level.content.dataset.state,
      subs: level.subs.size,
      scrollLocked: getComputedStyle(document.body).overflow === "hidden",
      outsideHidden: document.getElementById("outside").getAttribute("aria-hidden"),
      log: [...window.__ctl.log],
    };
  });
  assert.deepEqual(mounted, { portaled: true, state: "open", subs: 1, scrollLocked: true, outsideHidden: "true", log: ["open-auto-focus"] });
  assert.equal(await focusedText(page), "Apple", "the keyboard entry focus moves to the first item");

  await page.keyboard.press("Escape");
  await page.evaluate(() => window.__level.content.querySelector("[role=menuitemradio]").click());
  await page.evaluate(() => window.__level.teardown());
  await frames(page); // FocusScope runs the unmount auto focus after the teardown
  const closed = await page.evaluate(() => ({ log: window.__ctl.log, root: window.__ctl.root, content: document.querySelectorAll("[data-slot=dropdown-menu-content]").length, overflow: document.body.style.overflow }));
  assert.deepEqual(closed.log, ["open-auto-focus", "escape-key-down", "requestOpen:false", "select", "value-change:banana", "requestOpen:false", "close-auto-focus"]);
  assert.deepEqual([closed.root, closed.content, closed.overflow], [null, 0, ""]);
}, { html: markup("chadcn--dropdown-menu", "dropdown-menu") });

primitiveTest("menu_level: a custom behavior sets the prefix, the sub trigger, modality and the root hooks, and sub levels inherit it", async (page) => {
  await installController(page);
  await page.evaluate(async () => {
    const { MenuLevel } = await import("chadcn/primitives/menu_level");
    const controller = (window.__ctl = window.__controller());
    const log = (window.__hooks = []);
    const name = (level) => (level.isRoot ? "root" : "sub");
    const behavior = {
      prefix: "x--menu",
      subTrigger: "[data-slot=x-sub-trigger]",
      modal: () => false,
      close: (level) => log.push(`close:${name(level)}`),
      detach: (level) => log.push(`detach:${name(level)}`),
      onCloseAutoFocus: (level) => log.push(`close-auto-focus:${name(level)}`),
      entryFocus: () => false,
      onKeyDown: (level, event) => log.push(`keydown:${name(level)}:${event.key}`),
    };
    const template = document.querySelector("template[data-x--menu-template=root]");
    window.__level = new MenuLevel(controller, { anchor: controller.element, template, behavior });
    window.__level.mount();
  });
  await frames(page);
  const mounted = await page.evaluate(() => ({
    scrollLocked: getComputedStyle(document.body).overflow === "hidden",
    outsideHidden: document.getElementById("outside").hasAttribute("aria-hidden"),
    subs: window.__level.subs.size,
  }));
  assert.deepEqual(mounted, { scrollLocked: false, outsideHidden: false, subs: 1 });
  assert.equal(await focusedText(page), "x-content", "entryFocus: false keeps the focus on the content");

  // Open the sub from its trigger with the keyboard, then select its item.
  await page.evaluate(() => window.__level.content.querySelector("[data-slot=x-sub-trigger]").focus());
  await page.keyboard.press("ArrowRight");
  await frames(page);
  const sub = await page.evaluate(() => {
    const level = [...window.__level.subs.values()][0].level;
    return { inherits: level.behavior === window.__level.behavior, rootLevel: level.rootLevel === window.__level, inPlace: window.__level.content.contains(level.content) };
  });
  assert.deepEqual(sub, { inherits: true, rootLevel: true, inPlace: true });
  await page.keyboard.press("ArrowDown");
  await page.evaluate(() => [...window.__level.subs.values()][0].level.content.querySelector("[role=menuitem]").click());
  await page.evaluate(() => window.__level.teardown());
  await frames(page);
  const { hooks, controller, subLevel } = await page.evaluate(() => ({ hooks: window.__hooks, controller: window.__ctl.log, subLevel: [...window.__level.subs.values()][0].level }));
  assert.deepEqual(hooks, ["keydown:root:ArrowRight", "keydown:sub:ArrowDown", "keydown:root:ArrowDown", "close:root", "detach:root", "close-auto-focus:root"]);
  assert.deepEqual(controller, ["open-auto-focus", "open-change:true", "select"]);
  assert.equal(subLevel, null, "a torn down sub level clears its SubMenu");
}, { html: markup("x--menu", "x") });

// Mounts the DropdownMenu root with the default behavior; `modal` is the controller's modalValue.
const mountDefault = async (page, modal = true) => {
  await installController(page);
  await page.evaluate(async (modalValue) => {
    const { MenuLevel } = await import("chadcn/primitives/menu_level");
    const controller = (window.__ctl = window.__controller());
    controller.modalValue = modalValue;
    const template = document.querySelector("template[data-chadcn--dropdown-menu-template=root]");
    controller.root = window.__level = new MenuLevel(controller, { anchor: controller.element, template });
    controller.root.mount();
  }, modal);
  await frames(page); // the dismissable layer listens to pointerdown from the next tick
};

// Real DOM events on #outside (the modal body has pointer-events: none, so the mouse cannot reach it).
const pointerDownOutside = (page, init) => page.evaluate((eventInit) => {
  document.getElementById("outside").dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, pointerType: "mouse", ...eventInit }));
  return window.__ctl.hasInteractedOutside;
}, init);
const focusOutside = (page) => page.evaluate(() => {
  document.getElementById("outside").dispatchEvent(new FocusEvent("focusin", { bubbles: true }));
  return [...window.__ctl.log];
});

primitiveTest("menu_level: the default onFocusOutside prevents the dismiss of a modal menu", async (page) => {
  await mountDefault(page, true);
  const log = await focusOutside(page);
  assert.ok(log.includes("focus-outside"), "the focus outside is forwarded as a public event");
  assert.ok(!log.includes("requestOpen:false"), "the default hook prevents the dismiss, the menu stays open");
}, { html: markup("chadcn--dropdown-menu", "dropdown-menu") });

primitiveTest("menu_level: control, a focus outside a non-modal menu dismisses it", async (page) => {
  await mountDefault(page, false);
  const log = await focusOutside(page);
  assert.ok(log.includes("focus-outside"));
  assert.ok(log.includes("requestOpen:false"), "without modality the default hook lets the layer dismiss");
}, { html: markup("chadcn--dropdown-menu", "dropdown-menu") });

primitiveTest("menu_level: the default onInteractOutside flags only a right-click on a modal menu", async (page) => {
  await mountDefault(page, true);
  assert.equal(await pointerDownOutside(page, { button: 0 }), false, "a left pointerdown outside a modal menu is not an outside interaction");
  assert.equal(await pointerDownOutside(page, { button: 2 }), true, "a right-click is");
  await page.evaluate(() => { window.__ctl.hasInteractedOutside = false; });
  assert.equal(await pointerDownOutside(page, { button: 0, ctrlKey: true }), true, "so is the macOS right-click (ctrl + left button)");
}, { html: markup("chadcn--dropdown-menu", "dropdown-menu") });

primitiveTest("menu_level: control, a left pointerdown outside a non-modal menu flags the interaction", async (page) => {
  await mountDefault(page, false);
  assert.equal(await pointerDownOutside(page, { button: 0 }), true);
}, { html: markup("chadcn--dropdown-menu", "dropdown-menu") });

const activeId = (page) => page.evaluate(() => document.activeElement?.id);
const closeMenu = async (page) => {
  await page.evaluate(() => window.__level.teardown());
  await frames(page); // FocusScope runs the unmount auto focus after the teardown
};

primitiveTest("menu_level: the default close auto focus returns the focus to the anchor", async (page) => {
  await mountDefault(page);
  assert.notEqual(await activeId(page), "anchor", "the focus starts inside the menu");
  await closeMenu(page);
  assert.equal(await activeId(page), "anchor");
}, { html: markup("chadcn--dropdown-menu", "dropdown-menu") });

primitiveTest("menu_level: control, a prevented close-auto-focus keeps the focus off the anchor", async (page) => {
  await mountDefault(page);
  await page.evaluate(() => document.addEventListener("menu:close-auto-focus", (event) => event.preventDefault()));
  await closeMenu(page);
  assert.notEqual(await activeId(page), "anchor");
}, { html: markup("chadcn--dropdown-menu", "dropdown-menu") });

primitiveTest("menu_level: control, the close auto focus after an outside interaction skips the anchor and resets the flag", async (page) => {
  await mountDefault(page);
  await page.evaluate(() => { window.__ctl.hasInteractedOutside = true; });
  await closeMenu(page);
  assert.notEqual(await activeId(page), "anchor");
  assert.equal(await page.evaluate(() => window.__ctl.hasInteractedOutside), false, "the flag is reset for the next open");
}, { html: markup("chadcn--dropdown-menu", "dropdown-menu") });

primitiveTest("menu_level: custom onFocusOutside and onInteractOutside replace the defaults", async (page) => {
  await installController(page);
  await page.evaluate(async () => {
    const { MenuLevel } = await import("chadcn/primitives/menu_level");
    const controller = (window.__ctl = window.__controller());
    const log = (window.__hooks = []);
    const behavior = {
      prefix: "x--menu",
      subTrigger: "[data-slot=x-sub-trigger]",
      modal: () => true,
      close: (level) => log.push(`close:${level.isRoot ? "root" : "sub"}`),
      onFocusOutside: () => log.push("focus-outside:root"),
      onInteractOutside: () => log.push("interact-outside:root"),
    };
    const template = document.querySelector("template[data-x--menu-template=root]");
    window.__level = new MenuLevel(controller, { anchor: controller.element, template, behavior });
    window.__level.mount();
  });
  await frames(page);
  await focusOutside(page);
  const { hooks, controller, interacted } = await page.evaluate(() => ({ hooks: window.__hooks, controller: window.__ctl.log, interacted: window.__ctl.hasInteractedOutside }));
  assert.deepEqual(hooks, ["focus-outside:root", "interact-outside:root", "close:root"], "modal menu: the default onFocusOutside would prevent the dismiss, so close:root proves the custom hook replaced it");
  assert.ok(controller.includes("focus-outside"));
  assert.equal(interacted, false, "the default onInteractOutside did not run");
  const before = await page.evaluate(() => window.__hooks.filter((entry) => entry === "interact-outside:root").length);
  assert.equal(await pointerDownOutside(page, { button: 2 }), false, "a right-click does not set the default flag");
  const after = await page.evaluate(() => window.__hooks.filter((entry) => entry === "interact-outside:root").length);
  assert.equal(after, before + 1, "the right-click reached the custom onInteractOutside");
}, { html: markup("x--menu", "x") });
