import test, { after } from "node:test";
import { assert, consoleErrors, launch, openPath, settle } from "./support.mjs";

// chadcn--form (dev/port/specs/form.md, Behavior): the browser's HTML5 validity mirrored into the Form::Field contract. Runs on
// dev/dummy's form-demo page (Turbo Drive on), not on a parity scenario: the React twin has no such behavior.
const ONE = "/design-system/form-demo/one";
const field = (name) => `[data-slot=field]:has(#user_${name}-form-item)`;
const input = (name) => `#user_${name}-form-item`;
const message = (name) => `#user_${name}-form-item-message`;
const submit = "button[type=submit]";

const browserPromise = launch();
after(async () => { await (await browserPromise).close(); });

async function withPage(fn) {
  const page = await openPath(await browserPromise, ONE);
  try {
    const errors = consoleErrors(page);
    await fn(page);
    assert.deepEqual(errors, []);
    assert.deepEqual(page.jsErrors, []);
  } finally {
    await page.context().close();
  }
}

const describedby = (page, name) => page.locator(input(name)).evaluate((el) => (el.getAttribute("aria-describedby") || "").split(/\s+/));

test("form: submitting with an empty required input mirrors the browser's validity into the field", () => withPage(async (page) => {
  assert.equal(await page.locator(field("email")).getAttribute("data-invalid"), null, "valid before the first submit");
  await page.locator(submit).click();
  await settle(page);

  assert.equal(await page.locator(field("email")).getAttribute("data-invalid"), "true");
  assert.equal(await page.locator(input("email")).getAttribute("aria-invalid"), "true");
  assert.equal(await page.locator(`${field("email")} [data-slot=field-label]`).getAttribute("data-error"), "true");
  const native = await page.locator(input("email")).evaluate((el) => el.validationMessage);
  assert.notEqual(native, "");
  assert.equal(await page.locator(message("email")).textContent(), native);
  assert.equal(await page.locator(message("email")).isVisible(), true);
  assert.ok((await describedby(page, "email")).includes("user_email-form-item-message"));
  assert.ok((await describedby(page, "email")).includes("user_email-form-item-description"), "existing tokens are kept");
  assert.equal(await page.locator(input("email")).evaluate((el) => document.activeElement === el), true, "the native focus of the first invalid control stays");
}));

test("form: typing a valid value clears the error and the aria links", () => withPage(async (page) => {
  await page.locator(submit).click();
  await settle(page);
  await page.locator(input("email")).fill("a@b.co");
  await settle(page);

  assert.equal(await page.locator(field("email")).getAttribute("data-invalid"), null);
  assert.equal(await page.locator(input("email")).getAttribute("aria-invalid"), "false");
  assert.equal(await page.locator(`${field("email")} [data-slot=field-label]`).getAttribute("data-error"), "false");
  assert.equal(await page.locator(message("email")).textContent(), "");
  assert.equal(await page.locator(message("email")).isHidden(), true);
  assert.equal((await describedby(page, "email")).includes("user_email-form-item-message"), false);
  assert.ok((await describedby(page, "email")).includes("user_email-form-item-description"));

  await page.locator(input("email")).fill("nope");
  await settle(page);
  assert.equal(await page.locator(field("email")).getAttribute("data-invalid"), "true", "an invalid edit after the attempt shows again");
}));

test("form: a server-rendered error stays until its own control is edited", () => withPage(async (page) => {
  assert.equal(await page.locator(field("username")).getAttribute("data-invalid"), "true");
  assert.equal(await page.locator(message("username")).isVisible(), true);

  await page.locator(input("name")).fill("Ada");
  await settle(page);
  assert.equal(await page.locator(field("username")).getAttribute("data-invalid"), "true", "editing another control leaves it");
  assert.equal(await page.locator(message("username")).isVisible(), true);

  await page.locator(input("username")).fill("ada");
  await settle(page);
  assert.equal(await page.locator(field("username")).getAttribute("data-invalid"), null, "its own edit hands it to the client");
  assert.equal(await page.locator(input("username")).getAttribute("aria-invalid"), "false");
  assert.equal(await page.locator(message("username")).textContent(), "");
  assert.equal(await page.locator(message("username")).isHidden(), true);
}));

test("form: Turbo's cache restore keeps the mirrored state and a working form", () => withPage(async (page) => {
  await page.locator(submit).click();
  await settle(page);

  await page.evaluate(() => window.Turbo.visit("/design-system/form-demo/two"));
  await page.waitForSelector("#form-demo-two");
  await page.goBack();
  await page.waitForSelector("#form-demo-one");
  await settle(page);

  assert.equal(await page.locator(field("email")).getAttribute("data-invalid"), "true", "mirrored state is in the snapshot");
  assert.equal(await page.locator(message("email")).isVisible(), true);

  await page.locator(input("email")).fill("a@b.co");
  await settle(page);
  assert.equal(await page.locator(field("email")).getAttribute("data-invalid"), null, "the restored form is live");
  assert.equal(await page.locator(message("email")).isHidden(), true);
  await page.locator(submit).click();
  await settle(page);
  assert.equal(await page.locator(field("name")).getAttribute("data-invalid"), "true", "a restored form reports invalid controls again");
}));

test("form: the attempt survives a Turbo cache restore", () => withPage(async (page) => {
  await page.locator(submit).click();
  await settle(page);
  assert.equal(await page.locator("form#signup").getAttribute("data-chadcn-form-attempted"), "true");

  await page.evaluate(() => window.Turbo.visit("/design-system/form-demo/two"));
  await page.waitForSelector("#form-demo-two");
  await page.goBack();
  await page.waitForSelector("#form-demo-one");
  await settle(page);

  await page.locator(input("name")).fill("Ada");
  await settle(page);
  assert.equal(await page.locator(field("name")).getAttribute("data-invalid"), null);
  await page.locator(input("name")).fill("");
  await settle(page);
  assert.equal(await page.locator(field("name")).getAttribute("data-invalid"), "true", "input re-evaluates without a change event");
}));

test("form: a field with two controls follows the aggregate, each control its own aria-invalid", () => withPage(async (page) => {
  const pair = `[data-slot=field]:has(#contact_a)`;
  const msg = "#user_contact-form-item-message";
  await page.locator(submit).click();
  await settle(page);
  assert.equal(await page.locator(pair).getAttribute("data-invalid"), "true");
  assert.equal(await page.locator(msg).isVisible(), true);

  await page.locator("#contact_a").fill("x");
  await settle(page);
  assert.equal(await page.locator(pair).getAttribute("data-invalid"), "true", "the other control is still invalid");
  assert.equal(await page.locator(msg).isVisible(), true);
  assert.equal(await page.locator("#contact_a").getAttribute("aria-invalid"), "false");
  assert.equal(await page.locator("#contact_b").getAttribute("aria-invalid"), "true", "left as it was");
  assert.notEqual(await page.locator(msg).textContent(), "");

  await page.locator("#contact_b").fill("y");
  await settle(page);
  assert.equal(await page.locator(pair).getAttribute("data-invalid"), null);
  assert.equal(await page.locator(msg).isHidden(), true);
  assert.equal(await page.locator("#contact_b").getAttribute("aria-invalid"), "false");
}));

test("form: a valid change leaves a caller's field.error block untouched", () => withPage(async (page) => {
  const block = message("nickname");
  assert.equal((await page.locator(block).textContent()).trim(), "Shown to everyone");
  await page.locator(input("nickname")).fill("ada");
  await settle(page);
  await page.locator(input("nickname")).fill("");
  await page.locator(input("nickname")).fill("bob");
  await settle(page);

  assert.equal(await page.locator(field("nickname")).getAttribute("data-invalid"), null);
  assert.equal((await page.locator(block).textContent()).trim(), "Shown to everyone", "the block is not erased");
  assert.equal(await page.locator(block).isVisible(), true);
  assert.equal(await page.locator(block).getAttribute("data-chadcn-form-message"), null);
  assert.equal((await describedby(page, "nickname")).includes("user_nickname-form-item-message"), false, "its id is not mirrored");
}));

test("form: reset clears the mirrored state and forgets the attempt", () => withPage(async (page) => {
  await page.locator(submit).click();
  await settle(page);
  assert.equal(await page.locator(field("email")).getAttribute("data-invalid"), "true");

  await page.locator("form#signup").evaluate((form) => form.reset());
  await page.waitForFunction(() => document.querySelector("form#signup").dataset.chadcnFormAttempted === undefined);
  await settle(page);

  for (const name of ["email", "username"]) {
    assert.equal(await page.locator(field(name)).getAttribute("data-invalid"), null);
    assert.equal(await page.locator(input(name)).getAttribute("aria-invalid"), "false");
    assert.equal(await page.locator(message(name)).textContent(), "");
    assert.equal(await page.locator(message(name)).isHidden(), true);
    assert.equal((await describedby(page, name)).includes(`user_${name}-form-item-message`), false);
  }
  assert.equal(await page.locator(`${field("email")} [data-slot=field-label]`).getAttribute("data-error"), "false");

  await page.locator(input("email")).fill("nope");
  await settle(page);
  assert.equal(await page.locator(field("email")).getAttribute("data-invalid"), null, "typing after reset is not revalidated as if submitted");
}));

test("form: a novalidate form does not mirror on input or change", () => withPage(async (page) => {
  await page.locator("form#signup").evaluate((form) => { form.noValidate = true; });
  await page.locator(input("email")).fill("nope");
  await page.locator(input("email")).dispatchEvent("change");
  await settle(page);

  assert.equal(await page.locator(field("email")).getAttribute("data-invalid"), null);
  assert.equal(await page.locator(input("email")).getAttribute("aria-invalid"), "false", "still the server-rendered value");
  assert.equal(await page.locator(message("email")).isHidden(), true);
}));

test("form: a native sibling keeps its own aria-invalid, the label's target is not a proxy for it", () => withPage(async (page) => {
  const phone = "#user_phone-form-item";
  const pair = `[data-slot=field]:has(${phone})`;
  await page.locator(submit).click();
  await settle(page);
  assert.equal(await page.locator(phone).getAttribute("aria-invalid"), "true");

  await page.locator("#phone_ext").fill("12");
  await settle(page);
  assert.equal(await page.locator("#phone_ext").getAttribute("aria-invalid"), "false");
  assert.equal(await page.locator(phone).getAttribute("aria-invalid"), "true", "the label's target is native: left as it was");
  assert.ok((await describedby(page, "phone")).includes("user_phone-form-item-message"), "its message link stays");
  assert.equal(await page.locator(pair).getAttribute("data-invalid"), "true");
}));

test("form: two invalid controls in one field show the first control's message", () => withPage(async (page) => {
  await page.locator(submit).click();
  await settle(page);
  await page.locator("#contact_b").evaluate((el) => el.setCustomValidity("custom second"));
  await page.locator("#contact_b").fill("z");
  await settle(page);

  const first = await page.locator("#contact_a").evaluate((el) => el.validationMessage);
  const second = await page.locator("#contact_b").evaluate((el) => el.validationMessage);
  assert.notEqual(first, second);
  assert.equal(await page.locator("#user_contact-form-item-message").textContent(), first);
}));

test("form: a later preventDefault reset listener keeps the errors", () => withPage(async (page) => {
  await page.locator(submit).click();
  await settle(page);
  await page.locator("form#signup").evaluate((form) => {
    form.addEventListener("reset", (event) => event.preventDefault());
    form.reset();
  });
  await page.waitForTimeout(100);
  await settle(page);

  assert.equal(await page.locator(field("email")).getAttribute("data-invalid"), "true");
  assert.equal(await page.locator(input("email")).getAttribute("aria-invalid"), "true");
  assert.equal(await page.locator("form#signup").getAttribute("data-chadcn-form-attempted"), "true");
  assert.equal(await page.locator(message("email")).isVisible(), true);
}));

test("form: a readonly native label target is not a proxy, its required sibling is invalid", () => withPage(async (page) => {
  const code = "#user_code-form-item";
  await page.locator(submit).click();
  await settle(page);

  assert.equal(await page.locator(`[data-slot=field]:has(${code})`).getAttribute("data-invalid"), "true");
  assert.equal(await page.locator("#code_ext").getAttribute("aria-invalid"), "true");
  assert.equal(await page.locator(code).getAttribute("aria-invalid"), "false", "the readonly input is valid and not proxied");
}));

test("form: a required checkbox root gets aria-invalid and the message link without a focus error", () => withPage(async (page) => {
  const root = "[role=checkbox]#user_terms-form-item";
  await page.locator(submit).click();
  await settle(page);

  assert.equal(await page.locator(`[data-slot=field]:has(${root})`).getAttribute("data-invalid"), "true");
  assert.equal(await page.locator(root).getAttribute("aria-invalid"), "true");
  assert.ok((await describedby(page, "terms")).includes("user_terms-form-item-message"));
  assert.notEqual(await page.locator(message("terms")).textContent(), "");
}));
