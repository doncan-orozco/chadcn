import { assert, primitiveTest } from "./primitives_support.mjs";

// date_grid is pure date math on native Date/Intl; these run in Chromium like the other primitives. `grid(page, fn, arg)` runs `fn(g, arg)`
// in the page with the module as `g`. `zone(page, id)` moves the page's time zone (DST days differ per zone).
const grid = (page, fn, arg) => page.evaluate(async ({ source, arg }) => {
  const g = await import("chadcn/primitives/date_grid");
  return (0, eval)(`(${source})`)(g, arg);
}, { source: fn.toString(), arg });

async function zone(page, timezoneId) {
  page.zoneSession ??= await page.context().newCDPSession(page);
  await page.zoneSession.send("Emulation.setTimezoneOverride", { timezoneId });
}

primitiveTest("date_grid: parseISO reads a LOCAL date in any zone and rejects everything that is not a real day", async (page) => {
  for (const timezoneId of ["Pacific/Kiritimati", "America/Los_Angeles", "UTC"]) {
    await zone(page, timezoneId);
    const result = await grid(page, (g) => {
      const date = g.parseISO("2026-03-15");
      return {
        local: [date.getFullYear(), date.getMonth(), date.getDate(), date.getHours(), date.getMinutes()],
        invalid: ["2026-02-30", "2026-13-01", "2026-3-5", "26-03-05", "2026-03-15T00:00", "", null, undefined, 20260315, "2026-00-10"].map((value) => g.parseISO(value)),
        leap: g.toISO(g.parseISO("2024-02-29")),
        notLeap: g.parseISO("2026-02-29"),
        padded: g.parseISO(" 2026-03-05 ") && g.toISO(g.parseISO(" 2026-03-05 ")),
      };
    });
    assert.deepEqual(result.local, [2026, 2, 15, 0, 0], timezoneId);
    assert.deepEqual(result.invalid, Array(10).fill(null), timezoneId);
    assert.equal(result.leap, "2024-02-29");
    assert.equal(result.notLeap, null);
    assert.equal(result.padded, "2026-03-05");
  }
});

primitiveTest("date_grid: toISO and makeDate handle years below 100 and overflowing months and days", async (page) => {
  const result = await grid(page, (g) => ({
    year5: g.toISO(g.makeDate(5, 0, 9)),
    overflowMonth: g.toISO(g.makeDate(2026, 12, 1)),
    underflowDay: g.toISO(g.makeDate(2026, 3, 0)),
    month: g.toMonthISO(g.makeDate(2026, 2, 31)),
    midnight: g.makeDate(2026, 5, 6).getHours(),
    roundTrip: g.toISO(g.parseISO("0099-12-31")),
  }));
  assert.deepEqual(result, { year5: "0005-01-09", overflowMonth: "2027-01-01", underflowDay: "2026-03-31", month: "2026-03", midnight: 0, roundTrip: "0099-12-31" });
});

primitiveTest("date_grid: month edges and leap years (daysInMonth, endOfMonth, startOfMonth, year bounds)", async (page) => {
  const result = await grid(page, (g) => ({
    feb: [2026, 2024, 1900, 2000, 2100].map((year) => g.daysInMonth(year, 1)),
    thirty: [3, 5, 8, 10].map((month) => g.daysInMonth(2026, month)),
    thirtyOne: [0, 2, 4, 6, 7, 9, 11].map((month) => g.daysInMonth(2026, month)),
    endLeap: g.toISO(g.endOfMonth(g.makeDate(2024, 1, 10))),
    endDec: g.toISO(g.endOfMonth(g.makeDate(2026, 11, 3))),
    start: g.toISO(g.startOfMonth(g.makeDate(2026, 4, 31))),
    year: [g.toISO(g.startOfYear(g.makeDate(2026, 6, 6))), g.toISO(g.endOfYear(g.makeDate(2026, 6, 6)))],
  }));
  assert.deepEqual(result.feb, [28, 29, 28, 29, 28]);
  assert.deepEqual(result.thirty, [30, 30, 30, 30]);
  assert.deepEqual(result.thirtyOne, Array(7).fill(31));
  assert.equal(result.endLeap, "2024-02-29");
  assert.equal(result.endDec, "2026-12-31");
  assert.equal(result.start, "2026-05-01");
  assert.deepEqual(result.year, ["2026-01-01", "2026-12-31"]);
});

primitiveTest("date_grid: addMonths/addYears clamp the day instead of overflowing like setMonth", async (page) => {
  const result = await grid(page, (g) => {
    const add = (iso, months) => g.toISO(g.addMonths(g.parseISO(iso), months));
    const years = (iso, amount) => g.toISO(g.addYears(g.parseISO(iso), amount));
    return {
      clamp: [add("2026-01-31", 1), add("2024-01-31", 1), add("2026-03-31", -1), add("2026-05-31", 1), add("2026-08-31", -2)],
      exact: [add("2026-01-15", 1), add("2026-12-15", 1), add("2026-01-15", -1), add("2026-01-31", 12), add("2026-01-31", 0)],
      far: [add("2026-01-31", 25), add("2026-01-31", -25), add("2026-11-30", 3)],
      years: [years("2024-02-29", 1), years("2024-02-29", 4), years("2024-02-29", -4), years("2026-03-15", 10)],
      native: (() => { const date = new Date(2026, 0, 31); date.setMonth(1); return g.toISO(date); })(),
    };
  });
  assert.deepEqual(result.clamp, ["2026-02-28", "2024-02-29", "2026-02-28", "2026-06-30", "2026-06-30"]);
  assert.deepEqual(result.exact, ["2026-02-15", "2027-01-15", "2025-12-15", "2027-01-31", "2026-01-31"]);
  assert.deepEqual(result.far, ["2028-02-29", "2023-12-31", "2027-02-28"]);
  assert.deepEqual(result.years, ["2025-02-28", "2028-02-29", "2020-02-29", "2036-03-15"]);
  assert.equal(result.native, "2026-03-03", "control: native setMonth overflows");
});

primitiveTest("date_grid: functions never mutate their arguments", async (page) => {
  const result = await grid(page, (g) => {
    const date = new Date(2026, 0, 31, 13, 45);
    const time = date.getTime();
    g.addDays(date, 3); g.addWeeks(date, 1); g.addMonths(date, 1); g.addYears(date, 1); g.startOfDay(date); g.startOfMonth(date);
    g.endOfMonth(date); g.startOfWeek(date, 1); g.endOfWeek(date, 1); g.getWeek(date, { weekStartsOn: 0, firstWeekContainsDate: 1 });
    return date.getTime() === time;
  });
  assert.equal(result, true);
});

primitiveTest("date_grid: day arithmetic is calendar based across DST changes in several zones", async (page) => {
  const cases = [
    ["America/New_York", "2026-03-07", "2026-03-10"], ["America/New_York", "2026-10-31", "2026-11-03"],
    ["Europe/London", "2026-03-28", "2026-03-31"], ["Europe/London", "2026-10-24", "2026-10-27"],
    ["Australia/Lord_Howe", "2026-04-03", "2026-04-07"], ["Australia/Sydney", "2026-10-03", "2026-10-06"],
    // Brazil's 2018 spring forward skipped local midnight itself: makeDate(2018, 10, 4) is 01:00.
    ["America/Sao_Paulo", "2018-11-02", "2018-11-06"],
  ];
  for (const [timezoneId, from, to] of cases) {
    await zone(page, timezoneId);
    const result = await grid(page, (g, [start, end]) => {
      const first = g.parseISO(start);
      const last = g.parseISO(end);
      const days = g.differenceInCalendarDays(last, first);
      return {
        days,
        walked: Array.from({ length: days + 1 }, (_, offset) => g.toISO(g.addDays(first, offset))),
        back: g.toISO(g.addDays(last, -days)),
        week: g.toISO(g.addWeeks(first, 1)),
        sameDay: g.isSameDay(g.makeDate(2026, 2, 8), new Date(2026, 2, 8, 23, 59)),
        before: g.isBefore(first, last),
      };
    }, [from, to]);
    assert.equal(result.walked.at(-1), to, timezoneId);
    assert.equal(result.walked.length, result.days + 1, timezoneId);
    assert.equal(new Set(result.walked).size, result.walked.length, `${timezoneId}: no repeated or skipped day`);
    assert.equal(result.back, from, timezoneId);
    assert.equal(result.sameDay, true);
    assert.equal(result.before, true);
  }
});

primitiveTest("date_grid: a month grid keeps 28-35 distinct consecutive days on DST days of New York and Sao Paulo", async (page) => {
  for (const [timezoneId, year, month] of [["America/New_York", 2026, 2], ["America/New_York", 2026, 10], ["America/Sao_Paulo", 2018, 10], ["Europe/London", 2026, 9]]) {
    await zone(page, timezoneId);
    const isos = await grid(page, (g, [y, m]) => {
      const [month] = g.buildMonths({ first: g.makeDate(y, m, 1), numberOfMonths: 1, navEnd: null, weekStartsOn: 0, firstWeekContainsDate: 1 });
      return month.weeks.flatMap((week) => week.days.map((day) => day.iso));
    }, [year, month]);
    assert.equal(isos.length % 7, 0, timezoneId);
    assert.equal(new Set(isos).size, isos.length, timezoneId);
    const days = isos.map((iso) => Date.UTC(...iso.split("-").map(Number).map((n, i) => (i === 1 ? n - 1 : n))) / 86400000);
    assert.ok(days.every((day, i) => i === 0 || day - days[i - 1] === 1), `${timezoneId}: consecutive`);
  }
});

primitiveTest("date_grid: startOfWeek/endOfWeek for every first weekday, including across a month and a year", async (page) => {
  const result = await grid(page, (g) => {
    const friday = g.parseISO("2027-01-01");
    return Array.from({ length: 7 }, (_, weekStartsOn) => [g.toISO(g.startOfWeek(friday, weekStartsOn)), g.toISO(g.endOfWeek(friday, weekStartsOn))]);
  });
  assert.deepEqual(result, [
    ["2026-12-27", "2027-01-02"], ["2026-12-28", "2027-01-03"], ["2026-12-29", "2027-01-04"], ["2026-12-30", "2027-01-05"],
    ["2026-12-31", "2027-01-06"], ["2027-01-01", "2027-01-07"], ["2026-12-26", "2027-01-01"],
  ]);
});

primitiveTest("date_grid: getWeek follows date-fns for the en-US, es and ISO settings", async (page) => {
  const result = await grid(page, (g) => {
    const week = (iso, settings) => g.getWeek(g.parseISO(iso), settings);
    const en = { weekStartsOn: 0, firstWeekContainsDate: 1 };
    const es = { weekStartsOn: 1, firstWeekContainsDate: 1 };
    const iso = { weekStartsOn: 1, firstWeekContainsDate: 4 };
    return {
      en: ["2026-01-01", "2026-01-03", "2026-01-04", "2026-03-01", "2026-03-08", "2026-12-26", "2026-12-27", "2027-01-02", "2027-01-03"].map((d) => week(d, en)),
      es: ["2027-01-01", "2026-12-28", "2026-12-27", "2026-03-01", "2026-03-02"].map((d) => week(d, es)),
      iso: ["2026-01-01", "2025-12-29", "2021-01-03", "2021-01-04", "2024-12-30", "2026-12-31", "2027-01-01"].map((d) => week(d, iso)),
    };
  });
  assert.deepEqual(result.en, [1, 1, 2, 10, 11, 52, 1, 1, 2]);
  assert.deepEqual(result.es, [1, 1, 52, 9, 10]);
  assert.deepEqual(result.iso, [1, 1, 53, 1, 1, 53, 53]);
});

primitiveTest("date_grid: weekInfo reads Intl.Locale (getWeekInfo or weekInfo) and falls back to Sunday where the browser has none", async (page) => {
  const result = await grid(page, (g) => {
    const real = Object.fromEntries(["en-US", "en-GB", "de", "es-ES", "es-MX", "ar-EG", "fr", "pt-BR", "ja", null, undefined].map((tag) => [String(tag), g.weekInfo(tag).firstDay]));
    const original = Intl.Locale;
    const withLocale = (impl, tag) => { Intl.Locale = impl; try { return g.weekInfo(tag); } finally { Intl.Locale = original; } };
    return {
      real,
      legacy: withLocale(class { get weekInfo() { return { firstDay: 7, minimalDays: 4 }; } }, "xx"),
      modern: withLocale(class { getWeekInfo() { return { firstDay: 1, minimalDays: 4 }; } get weekInfo() { return { firstDay: 5, minimalDays: 1 }; } }, "xx"),
      missing: withLocale(class {}, "de"),
      partial: withLocale(class { getWeekInfo() { return { firstDay: 6 }; } }, "xx"),
      invalidTag: g.weekInfo("not a tag!!"),
      throwing: withLocale(class { constructor() { throw new RangeError("nope"); } }, "de"),
    };
  });
  assert.deepEqual(result.real, { "en-US": 0, "en-GB": 1, de: 1, "es-ES": 1, "es-MX": 0, "ar-EG": 6, fr: 1, "pt-BR": 0, ja: 0, null: 0, undefined: 0 });
  assert.deepEqual(result.legacy, { firstDay: 0, minimalDays: 4 }, "Intl firstDay 7 (Sunday) becomes 0");
  assert.deepEqual(result.modern, { firstDay: 1, minimalDays: 4 }, "getWeekInfo wins over the legacy property");
  assert.deepEqual(result.missing, { firstDay: 0, minimalDays: null });
  assert.deepEqual(result.partial, { firstDay: 6, minimalDays: null });
  assert.deepEqual(result.invalidTag, { firstDay: 0, minimalDays: null });
  assert.deepEqual(result.throwing, { firstDay: 0, minimalDays: null });
});

primitiveTest("date_grid: ordinalSuffix gives the English ordinals of a day number", async (page) => {
  const result = await grid(page, (g) => Array.from({ length: 31 }, (_, index) => `${index + 1}${g.ordinalSuffix(index + 1)}`));
  assert.deepEqual(result, [
    "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th", "11th", "12th", "13th", "14th", "15th", "16th", "17th", "18th",
    "19th", "20th", "21st", "22nd", "23rd", "24th", "25th", "26th", "27th", "28th", "29th", "30th", "31st",
  ]);
});

primitiveTest("date_grid: navigation bounds, initial month and the previous/next months", async (page) => {
  const result = await grid(page, (g) => {
    const day = (iso) => g.parseISO(iso);
    const iso = (date) => (date ? g.toISO(date) : null);
    const bounds = (options) => { const { navStart, navEnd } = g.navMonths({ today: day("2026-03-15"), ...options }); return [iso(navStart), iso(navEnd)]; };
    const initial = (options) => iso(g.initialMonth({ today: day("2026-03-15"), numberOfMonths: 1, navStart: null, navEnd: null, ...options }));
    const step = (fn, options) => iso(fn({ numberOfMonths: 1, ...options }));
    return {
      none: bounds({}),
      explicit: bounds({ startMonth: day("2026-02-17"), endMonth: day("2026-04-02") }),
      yearDropdown: bounds({ yearDropdown: true }),
      yearDropdownExplicit: bounds({ yearDropdown: true, startMonth: day("2020-05-05") }),
      initialToday: initial({}),
      initialDefault: initial({ defaultMonth: day("2026-09-20") }),
      initialMonthWins: initial({ month: day("2026-05-02"), defaultMonth: day("2026-09-20") }),
      initialEndShift: initial({ defaultMonth: day("2026-09-01"), numberOfMonths: 2, navEnd: g.endOfMonth(day("2026-06-01")) }),
      initialStartPush: initial({ defaultMonth: day("2025-01-01"), navStart: day("2025-06-01") }),
      previous: step(g.previousMonth, { first: day("2026-03-01"), navStart: null }),
      previousAtStart: step(g.previousMonth, { first: day("2026-03-01"), navStart: day("2026-03-01") }),
      previousPaged: step(g.previousMonth, { first: day("2026-03-01"), navStart: null, numberOfMonths: 2, pagedNavigation: true }),
      previousDisabled: step(g.previousMonth, { first: day("2026-03-01"), navStart: null, disableNavigation: true }),
      next: step(g.nextMonth, { first: day("2026-03-01"), navEnd: null }),
      nextAtEnd: step(g.nextMonth, { first: day("2026-03-01"), navEnd: g.endOfMonth(day("2026-03-01")) }),
      nextTwoMonthsAtEnd: step(g.nextMonth, { first: day("2026-03-01"), navEnd: g.endOfMonth(day("2026-04-01")), numberOfMonths: 2 }),
      nextPaged: step(g.nextMonth, { first: day("2026-03-01"), navEnd: null, numberOfMonths: 3, pagedNavigation: true }),
    };
  });
  assert.deepEqual(result.none, [null, null]);
  assert.deepEqual(result.explicit, ["2026-02-01", "2026-04-30"]);
  assert.deepEqual(result.yearDropdown, ["1926-01-01", "2026-12-31"]);
  assert.deepEqual(result.yearDropdownExplicit, ["2020-05-01", "2026-12-31"]);
  assert.equal(result.initialToday, "2026-03-01");
  assert.equal(result.initialDefault, "2026-09-01");
  assert.equal(result.initialMonthWins, "2026-05-01");
  assert.equal(result.initialEndShift, "2026-05-01", "two months ending at June");
  assert.equal(result.initialStartPush, "2025-06-01");
  assert.equal(result.previous, "2026-02-01");
  assert.equal(result.previousAtStart, null);
  assert.equal(result.previousPaged, "2026-01-01");
  assert.equal(result.previousDisabled, null);
  assert.equal(result.next, "2026-04-01");
  assert.equal(result.nextAtEnd, null);
  assert.equal(result.nextTwoMonthsAtEnd, null);
  assert.equal(result.nextPaged, "2026-06-01");
});

primitiveTest("date_grid: buildMonths lays out weeks, outside days, fixed weeks and week numbers", async (page) => {
  const result = await grid(page, (g) => {
    const settings = { weekStartsOn: 0, firstWeekContainsDate: 1, navEnd: null };
    const shape = (options) => {
      const months = g.buildMonths({ first: g.parseISO(options.first), numberOfMonths: 1, ...settings, ...options.settings });
      return months.map((month) => ({
        id: month.id,
        weeks: month.weeks.map((week) => week.weekNumber),
        first: month.weeks[0].days[0].iso,
        last: month.weeks.at(-1).days.at(-1).iso,
        count: month.weeks.reduce((sum, week) => sum + week.days.length, 0),
        outside: month.weeks.flatMap((week) => week.days).filter((day) => day.outside).length,
      }));
    };
    const march = g.buildMonths({ first: g.parseISO("2026-03-01"), numberOfMonths: 1, ...settings })[0];
    return {
      march: shape({ first: "2026-03-01" }),
      monday: shape({ first: "2026-03-01", settings: { weekStartsOn: 1 } }),
      february: shape({ first: "2026-02-01" }),
      februaryFixed: shape({ first: "2026-02-01", settings: { fixedWeeks: true } }),
      twoFixed: shape({ first: "2026-02-01", settings: { fixedWeeks: true, numberOfMonths: 2 } }),
      december: shape({ first: "2026-12-01" }),
      esJanuary: shape({ first: "2027-01-01", settings: { weekStartsOn: 1 } }),
      clamped: shape({ first: "2026-03-01", settings: { numberOfMonths: 3, endMonth: g.parseISO("2026-04-15"), navEnd: g.endOfMonth(g.parseISO("2026-04-01")) } }),
      ids: march.weeks[0].days.slice(0, 2).map((day) => [day.id, day.monthId, day.outside]),
      aprilCopy: g.buildMonths({ first: g.parseISO("2026-03-01"), numberOfMonths: 2, ...settings }).map((month) => month.weeks.flatMap((week) => week.days).find((day) => day.iso === "2026-04-01").id),
    };
  });
  assert.deepEqual(result.march, [{ id: "2026-03", weeks: [10, 11, 12, 13, 14], first: "2026-03-01", last: "2026-04-04", count: 35, outside: 4 }]);
  assert.equal(result.monday[0].first, "2026-02-23");
  assert.equal(result.monday[0].last, "2026-04-05");
  assert.equal(result.monday[0].count, 42, "March 2026 starts on a Sunday: with Monday first it spans six weeks");
  assert.equal(result.monday[0].outside, 11);
  assert.deepEqual(result.february, [{ id: "2026-02", weeks: [6, 7, 8, 9], first: "2026-02-01", last: "2026-02-28", count: 28, outside: 0 }]);
  assert.equal(result.februaryFixed[0].count, 42);
  assert.equal(result.februaryFixed[0].last, "2026-03-14");
  assert.deepEqual(result.twoFixed.map((month) => month.count), [42, 42]);
  assert.deepEqual(result.december[0].weeks.slice(-2), [52, 1], "Dec 27 2026 - Jan 2 2027 is week 1 in en-US");
  assert.equal(result.december[0].last, "2027-01-02");
  assert.equal(result.esJanuary[0].weeks[0], 1);
  assert.deepEqual(result.clamped.map((month) => month.id), ["2026-03", "2026-04"], "stops after the navigation end");
  assert.equal(result.clamped[1].last, "2026-05-02", "the grid ends with the week of the end month");
  assert.deepEqual(result.ids, [["2026-03-01_2026-03", "2026-03", false], ["2026-03-02_2026-03", "2026-03", false]]);
  assert.deepEqual(result.aprilCopy, ["2026-04-01_2026-03", "2026-04-01_2026-04"], "an outside day is a different day than the same date in its own month");
});

primitiveTest("date_grid: weekdays lists the week of the reference day from the first weekday", async (page) => {
  const result = await grid(page, (g) => [0, 1, 6].map((first) => g.weekdays(g.parseISO("2026-03-15"), first).map((date) => g.toISO(date).slice(8))));
  assert.deepEqual(result, [
    ["15", "16", "17", "18", "19", "20", "21"], ["09", "10", "11", "12", "13", "14", "15"], ["14", "15", "16", "17", "18", "19", "20"],
  ]);
});

primitiveTest("date_grid: rangeIncludes handles inverted, one-sided and exclusive ends", async (page) => {
  const result = await grid(page, (g) => {
    const day = (iso) => g.parseISO(iso);
    const inside = (range, iso, exclude) => g.rangeIncludes(range, day(iso), exclude);
    const range = { from: day("2026-03-10"), to: day("2026-03-14") };
    const inverted = { from: day("2026-03-14"), to: day("2026-03-10") };
    return {
      ends: ["2026-03-09", "2026-03-10", "2026-03-12", "2026-03-14", "2026-03-15"].map((iso) => inside(range, iso)),
      exclusive: ["2026-03-10", "2026-03-11", "2026-03-13", "2026-03-14"].map((iso) => inside(range, iso, true)),
      inverted: ["2026-03-10", "2026-03-12", "2026-03-14", "2026-03-15"].map((iso) => inside(inverted, iso)),
      fromOnly: [inside({ from: day("2026-03-10") }, "2026-03-10"), inside({ from: day("2026-03-10") }, "2026-03-11"), inside({ from: day("2026-03-10") }, "2026-03-10", true)],
      toOnly: [inside({ to: day("2026-03-10") }, "2026-03-10"), inside({ to: day("2026-03-10") }, "2026-03-09")],
      sameDay: [inside({ from: day("2026-03-10"), to: day("2026-03-10") }, "2026-03-10"), inside({ from: day("2026-03-10"), to: day("2026-03-10") }, "2026-03-10", true)],
      empty: inside({}, "2026-03-10"),
    };
  });
  assert.deepEqual(result.ends, [false, true, true, true, false]);
  assert.deepEqual(result.exclusive, [false, true, true, false]);
  assert.deepEqual(result.inverted, [true, true, true, false]);
  assert.deepEqual(result.fromOnly, [true, false, false]);
  assert.deepEqual(result.toOnly, [true, false]);
  assert.deepEqual(result.sameDay, [true, false]);
  assert.equal(result.empty, false);
});

primitiveTest("date_grid: dateMatches follows react-day-picker's matcher precedence", async (page) => {
  const result = await grid(page, (g) => {
    const day = (iso) => g.parseISO(iso);
    const matches = (iso, json) => g.dateMatches(day(iso), g.reviveMatcher(json));
    return {
      booleans: [matches("2026-03-10", true), matches("2026-03-10", false)],
      date: [matches("2026-03-10", "2026-03-10"), matches("2026-03-11", "2026-03-10")],
      dates: [matches("2026-03-11", ["2026-03-10", "2026-03-11"]), matches("2026-03-12", ["2026-03-10", "2026-03-11"]), matches("2026-03-12", [])],
      range: [matches("2026-03-12", { from: "2026-03-10", to: "2026-03-14" }), matches("2026-03-15", { from: "2026-03-10", to: "2026-03-14" }), matches("2026-03-14", { from: "2026-03-14", to: "2026-03-10" })],
      fromOnly: [matches("2026-03-10", { from: "2026-03-10", to: null }), matches("2026-03-11", { from: "2026-03-10", to: null })],
      toOnly: [matches("2026-03-10", { from: null, to: "2026-03-10" }), matches("2026-03-09", { from: null, to: "2026-03-10" })],
      dayOfWeek: [matches("2026-03-15", { dayOfWeek: 0 }), matches("2026-03-16", { dayOfWeek: 0 }), matches("2026-03-21", { dayOfWeek: [0, 6] }), matches("2026-03-18", { dayOfWeek: [0, 6] })],
      closed: ["2026-03-10", "2026-03-11", "2026-03-19", "2026-03-20"].map((iso) => matches(iso, { after: "2026-03-10", before: "2026-03-20" })),
      open: ["2026-03-09", "2026-03-10", "2026-03-20", "2026-03-21"].map((iso) => matches(iso, { before: "2026-03-10", after: "2026-03-20" })),
      after: [matches("2026-03-20", { after: "2026-03-20" }), matches("2026-03-21", { after: "2026-03-20" })],
      before: [matches("2026-03-20", { before: "2026-03-20" }), matches("2026-03-19", { before: "2026-03-20" })],
      mixed: [matches("2026-03-21", [{ after: "2026-03-25" }, { dayOfWeek: [0, 6] }]), matches("2026-03-26", [{ after: "2026-03-25" }, { dayOfWeek: [0, 6] }]), matches("2026-03-24", [{ after: "2026-03-25" }, { dayOfWeek: [0, 6] }])],
      unknown: [matches("2026-03-10", {}), matches("2026-03-10", "not a date"), matches("2026-03-10", null)],
    };
  });
  assert.deepEqual(result.booleans, [true, false]);
  assert.deepEqual(result.date, [true, false]);
  assert.deepEqual(result.dates, [true, false, false]);
  assert.deepEqual(result.range, [true, false, true]);
  assert.deepEqual(result.fromOnly, [true, false]);
  assert.deepEqual(result.toOnly, [true, false]);
  assert.deepEqual(result.dayOfWeek, [true, false, true, false]);
  assert.deepEqual(result.closed, [false, true, true, false], "closed interval: strictly between");
  assert.deepEqual(result.open, [true, false, false, true], "open interval: strictly before or strictly after");
  assert.deepEqual(result.after, [false, true]);
  assert.deepEqual(result.before, [false, true]);
  assert.deepEqual(result.mixed, [true, true, false]);
  assert.deepEqual(result.unknown, [false, false, false]);
});

primitiveTest("date_grid: rangeContainsMatch finds disabled days inside a complete range", async (page) => {
  const result = await grid(page, (g) => {
    const range = { from: g.parseISO("2026-03-10"), to: g.parseISO("2026-03-16") };
    const contains = (json) => g.rangeContainsMatch(range, g.reviveMatcher(json));
    return {
      date: [contains("2026-03-12"), contains("2026-03-20"), contains(["2026-03-01", "2026-03-16"])],
      booleans: [contains(true), contains(false)],
      overlap: [contains({ from: "2026-03-15", to: "2026-03-30" }), contains({ from: "2026-03-17", to: "2026-03-30" }), contains({ from: "2026-03-01", to: "2026-03-30" })],
      dayOfWeek: [contains({ dayOfWeek: 3 }), contains({ dayOfWeek: [1, 2, 3, 4, 5, 6, 0] })],
      shortRange: g.rangeContainsMatch({ from: g.parseISO("2026-03-10"), to: g.parseISO("2026-03-11") }, { dayOfWeek: 5 }),
      after: [contains({ after: "2026-03-15" }), contains({ after: "2026-03-16" })],
      before: [contains({ before: "2026-03-11" }), contains({ before: "2026-03-10" })],
      closed: [contains({ after: "2026-03-01", before: "2026-03-12" }), contains({ after: "2026-03-16", before: "2026-03-20" })],
      open: [contains({ before: "2026-03-11", after: "2026-03-01" }), contains({ before: "2026-03-01", after: "2026-03-20" })],
    };
  });
  assert.deepEqual(result.date, [true, false, true]);
  assert.deepEqual(result.booleans, [true, false]);
  assert.deepEqual(result.overlap, [true, false, true]);
  assert.deepEqual(result.dayOfWeek, [true, true]);
  assert.equal(result.shortRange, false, "Mar 10-11 2026 are Tuesday and Wednesday");
  assert.deepEqual(result.after, [true, false]);
  assert.deepEqual(result.before, [true, false]);
  assert.deepEqual(result.closed, [true, false]);
  assert.deepEqual(result.open, [true, false]);
});

primitiveTest("date_grid: addToRange implements react-day-picker's click rules", async (page) => {
  const result = await grid(page, (g) => {
    const day = (iso) => (iso ? g.parseISO(iso) : undefined);
    const show = (range) => (range ? [range.from ? g.toISO(range.from) : null, range.to ? g.toISO(range.to) : null] : null);
    const click = (iso, from, to, limits) => show(g.addToRange(day(iso), from || to ? { from: day(from), to: day(to) } : null, limits));
    return {
      empty: [click("2026-03-10"), click("2026-03-10", null, null, { min: 3 })],
      fromOnly: [click("2026-03-14", "2026-03-10"), click("2026-03-05", "2026-03-10"), click("2026-03-10", "2026-03-10"), click("2026-03-10", "2026-03-10", null, { min: 2 }),
        click("2026-03-10", "2026-03-10", null, { min: 2, required: true })],
      complete: [click("2026-03-12", "2026-03-10", "2026-03-14"), click("2026-03-20", "2026-03-10", "2026-03-14"), click("2026-03-05", "2026-03-10", "2026-03-14"),
        click("2026-03-10", "2026-03-10", "2026-03-14"), click("2026-03-14", "2026-03-10", "2026-03-14")],
      sameDay: [click("2026-03-10", "2026-03-10", "2026-03-10"), click("2026-03-10", "2026-03-10", "2026-03-10", { required: true })],
      minOnEnds: [click("2026-03-10", "2026-03-10", "2026-03-14", { min: 3 }), click("2026-03-14", "2026-03-10", "2026-03-14", { min: 3 })],
      max: [click("2026-03-22", "2026-03-20", null, { max: 3 }), click("2026-03-24", "2026-03-20", null, { max: 3 })],
      min: [click("2026-03-11", "2026-03-10", null, { min: 3 }), click("2026-03-15", "2026-03-10", null, { min: 3 })],
      toOnly: click("2026-03-10", null, "2026-03-12"),
    };
  });
  assert.deepEqual(result.empty, [["2026-03-10", "2026-03-10"], ["2026-03-10", null]]);
  assert.deepEqual(result.fromOnly, [["2026-03-10", "2026-03-14"], ["2026-03-05", "2026-03-10"], ["2026-03-10", "2026-03-10"], null, ["2026-03-10", null]]);
  assert.deepEqual(result.complete, [["2026-03-10", "2026-03-12"], ["2026-03-10", "2026-03-20"], ["2026-03-05", "2026-03-14"], ["2026-03-10", "2026-03-10"], ["2026-03-14", "2026-03-14"]]);
  assert.deepEqual(result.sameDay, [null, ["2026-03-10", "2026-03-10"]]);
  assert.deepEqual(result.minOnEnds, [["2026-03-10", null], ["2026-03-14", null]]);
  assert.deepEqual(result.max, [["2026-03-20", "2026-03-22"], ["2026-03-24", null]]);
  assert.deepEqual(result.min, [["2026-03-11", null], ["2026-03-10", "2026-03-15"]]);
  assert.equal(result.toOnly, null, "a range with only `to` is not a range for react-day-picker");
});

primitiveTest("date_grid: reviveMatcher parses ISO strings as local dates and keeps keys that are present with a null value", async (page) => {
  const result = await grid(page, (g) => {
    const revived = g.reviveMatcher([{ from: "2026-03-10", to: null }, "2026-03-12", { dayOfWeek: [0, 6] }, true, { before: "2026-13-40" }, ["2026-03-01"]]);
    return {
      first: [g.toISO(revived[0].from), revived[0].to, "to" in revived[0]],
      second: [revived[1].getFullYear(), revived[1].getMonth(), revived[1].getDate(), revived[1].getHours()],
      dayOfWeek: revived[2].dayOfWeek,
      boolean: revived[3],
      invalid: revived[4].before,
      nested: revived[5].map((date) => g.toISO(date)),
    };
  });
  assert.deepEqual(result, { first: ["2026-03-10", null, true], second: [2026, 2, 12, 0], dayOfWeek: [0, 6], boolean: true, invalid: false, nested: ["2026-03-01"] });
});

primitiveTest("date_grid: before/after matchers with an unparsable date never match", async (page) => {
  const result = await grid(page, (g) => {
    const date = g.parseISO("2026-03-15");
    const range = { from: g.parseISO("2026-03-10"), to: g.parseISO("2026-03-20") };
    return [{ before: "2026-13-40" }, { after: "bad" }, { before: "bad", after: "2026-03-01" }, { before: "2026-03-20", after: "bad" }]
      .map((json) => [g.dateMatches(date, g.reviveMatcher(json)), g.rangeContainsMatch(range, g.reviveMatcher(json))]);
  });
  assert.deepEqual(result, Array(4).fill([false, false]));
});
