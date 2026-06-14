-- tests/unit/test_cmp_date_nl.lua
-- Unit tests for cmp/date_nl.lua — natural-language date parser.
--
-- Tests cover:
--   • simple keywords: today, tomorrow, yesterday
--   • next week
--   • next <weekday> — including on-same-day edge case (+7)
--   • this <weekday> — including today, earlier-this-week, later-this-week
--   • bare <weekday> — same contract as "this <weekday>"
--   • in N days / in N weeks / in N months
--   • in the last N days / in the last N weeks / in the last N months
--   • N days ago / N weeks ago / N months ago
--   • ISO pass-through + validation
--   • nil / empty / garbage → nil
--   • M.suggestions() default + custom

local T = MiniTest.new_set()
local date_nl = require("obsidian-tasks.cmp.date_nl")

-- ── helpers ──────────────────────────────────────────────────────────────────

local function eq(a, b)
  MiniTest.expect.equality(a, b)
end

--- Return today's date rebuilt from its components (midnight, local tz).
local function today_str()
  return os.date("%Y-%m-%d") --[[@as string]]
end

--- Return a date N days from today (positive or negative).
local function days_from_today(n)
  local t = os.date("*t") --[[@as osdate]]
  t.hour = 0
  t.min = 0
  t.sec = 0
  t.day = t.day + n
  return os.date("%Y-%m-%d", os.time(t)) --[[@as string]]
end

--- Return a date N months from today.
local function months_from_today(n)
  local t = os.date("*t") --[[@as osdate]]
  t.hour = 0
  t.min = 0
  t.sec = 0
  t.month = t.month + n
  return os.date("%Y-%m-%d", os.time(t)) --[[@as string]]
end

--- 0-based weekday index of today (0 = Sunday).
local function today_wday0()
  return (os.date("*t") --[[@as osdate]]).wday - 1
end

--- Name for a 0-based weekday index.
local WDAY_NAMES = { "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday" }

--- Expected date for "next <weekday>" from today.
local function expected_next_weekday(target_0)
  local delta = target_0 - today_wday0()
  if delta <= 0 then
    delta = delta + 7
  end
  return days_from_today(delta)
end

--- Expected date for "this <weekday>" / bare <weekday> from today.
local function expected_this_weekday(target_0)
  local delta = target_0 - today_wday0()
  return days_from_today(delta)
end

-- ── simple keywords ───────────────────────────────────────────────────────────

T["today → today's date"] = function()
  eq(date_nl.parse("today"), today_str())
end

T["TODAY (uppercase) → today's date"] = function()
  eq(date_nl.parse("TODAY"), today_str())
end

T["  today  (padded) → today's date"] = function()
  eq(date_nl.parse("  today  "), today_str())
end

T["tomorrow → today + 1"] = function()
  eq(date_nl.parse("tomorrow"), days_from_today(1))
end

T["yesterday → today - 1"] = function()
  eq(date_nl.parse("yesterday"), days_from_today(-1))
end

T["next week → today + 7"] = function()
  eq(date_nl.parse("next week"), days_from_today(7))
end

-- ── in N days / weeks / months ────────────────────────────────────────────────

T["in 0 days → today"] = function()
  eq(date_nl.parse("in 0 days"), today_str())
end

T["in 1 day → tomorrow"] = function()
  eq(date_nl.parse("in 1 day"), days_from_today(1))
end

T["in 3 days → today + 3"] = function()
  eq(date_nl.parse("in 3 days"), days_from_today(3))
end

T["in 2 weeks → today + 14"] = function()
  eq(date_nl.parse("in 2 weeks"), days_from_today(14))
end

T["in 1 week → today + 7"] = function()
  eq(date_nl.parse("in 1 week"), days_from_today(7))
end

T["in 1 month → today + 1 month"] = function()
  eq(date_nl.parse("in 1 month"), months_from_today(1))
end

T["in 3 months → today + 3 months"] = function()
  eq(date_nl.parse("in 3 months"), months_from_today(3))
end

-- ── in the last N days / weeks / months ──────────────────────────────────────

T["in the last 0 days → today"] = function()
  eq(date_nl.parse("in the last 0 days"), today_str())
end

T["in the last 1 day → yesterday"] = function()
  eq(date_nl.parse("in the last 1 day"), days_from_today(-1))
end

T["in the last 7 days → today - 7"] = function()
  eq(date_nl.parse("in the last 7 days"), days_from_today(-7))
end

T["in the last 2 weeks → today - 14"] = function()
  eq(date_nl.parse("in the last 2 weeks"), days_from_today(-14))
end

T["in the last 1 week → today - 7"] = function()
  eq(date_nl.parse("in the last 1 week"), days_from_today(-7))
end

T["in the last 1 month → today - 1 month"] = function()
  eq(date_nl.parse("in the last 1 month"), months_from_today(-1))
end

T["in the last 3 months → today - 3 months"] = function()
  eq(date_nl.parse("in the last 3 months"), months_from_today(-3))
end

-- ── N days / weeks / months ago ──────────────────────────────────────────────

T["0 days ago → today"] = function()
  eq(date_nl.parse("0 days ago"), today_str())
end

T["1 day ago → yesterday"] = function()
  eq(date_nl.parse("1 day ago"), days_from_today(-1))
end

T["7 days ago → today - 7"] = function()
  eq(date_nl.parse("7 days ago"), days_from_today(-7))
end

T["2 weeks ago → today - 14"] = function()
  eq(date_nl.parse("2 weeks ago"), days_from_today(-14))
end

T["1 week ago → today - 7"] = function()
  eq(date_nl.parse("1 week ago"), days_from_today(-7))
end

T["1 month ago → today - 1 month"] = function()
  eq(date_nl.parse("1 month ago"), months_from_today(-1))
end

T["3 months ago → today - 3 months"] = function()
  eq(date_nl.parse("3 months ago"), months_from_today(-3))
end

-- ── next <weekday> ────────────────────────────────────────────────────────────

T["next monday → correct date"] = function()
  eq(date_nl.parse("next monday"), expected_next_weekday(1))
end

T["next friday → correct date"] = function()
  eq(date_nl.parse("next friday"), expected_next_weekday(5))
end

T["next sunday → correct date"] = function()
  eq(date_nl.parse("next sunday"), expected_next_weekday(0))
end

-- Edge case: if today is that weekday, "next X" → +7 days (strictly after).
T["next <today's weekday> → +7 days"] = function()
  local today_wd = today_wday0()
  local name = WDAY_NAMES[today_wd + 1]
  eq(date_nl.parse("next " .. name), days_from_today(7))
end

T["NEXT MONDAY (uppercase) → same as next monday"] = function()
  eq(date_nl.parse("NEXT MONDAY"), expected_next_weekday(1))
end

-- ── this <weekday> ────────────────────────────────────────────────────────────

T["this <today's weekday> → today"] = function()
  local today_wd = today_wday0()
  local name = WDAY_NAMES[today_wd + 1]
  eq(date_nl.parse("this " .. name), today_str())
end

T["this monday → this week's monday"] = function()
  eq(date_nl.parse("this monday"), expected_this_weekday(1))
end

T["this tuesday → this week's tuesday"] = function()
  eq(date_nl.parse("this tuesday"), expected_this_weekday(2))
end

T["this saturday → this week's saturday"] = function()
  eq(date_nl.parse("this saturday"), expected_this_weekday(6))
end

-- ── bare <weekday> ────────────────────────────────────────────────────────────

T["monday (bare) → same as 'this monday'"] = function()
  eq(date_nl.parse("monday"), expected_this_weekday(1))
end

T["friday (bare) → same as 'this friday'"] = function()
  eq(date_nl.parse("friday"), expected_this_weekday(5))
end

T["sunday (bare) → same as 'this sunday'"] = function()
  eq(date_nl.parse("sunday"), expected_this_weekday(0))
end

T["WEDNESDAY (bare uppercase) → same as 'this wednesday'"] = function()
  eq(date_nl.parse("WEDNESDAY"), expected_this_weekday(3))
end

-- ── ISO pass-through ──────────────────────────────────────────────────────────

T["ISO 2026-12-31 → pass-through"] = function()
  eq(date_nl.parse("2026-12-31"), "2026-12-31")
end

T["ISO 2026-01-01 → pass-through"] = function()
  eq(date_nl.parse("2026-01-01"), "2026-01-01")
end

T["ISO invalid month (13) → nil"] = function()
  eq(date_nl.parse("2026-13-01"), nil)
end

T["ISO invalid day (00) → nil"] = function()
  eq(date_nl.parse("2026-06-00"), nil)
end

-- ── invalid / garbage → nil ───────────────────────────────────────────────────

T["nil → nil"] = function()
  eq(date_nl.parse(nil), nil)
end

T["empty string → nil"] = function()
  eq(date_nl.parse(""), nil)
end

T["whitespace-only → nil"] = function()
  eq(date_nl.parse("   "), nil)
end

T["garbage 'not a date' → nil"] = function()
  eq(date_nl.parse("not a date"), nil)
end

T["invalid weekday 'mooday' → nil"] = function()
  eq(date_nl.parse("mooday"), nil)
end

T["'next mooday' (invalid weekday) → nil"] = function()
  eq(date_nl.parse("next mooday"), nil)
end

T["'this mooday' (invalid weekday) → nil"] = function()
  eq(date_nl.parse("this mooday"), nil)
end

T["'in abc days' (non-integer) → nil"] = function()
  eq(date_nl.parse("in abc days"), nil)
end

T["'next week extra' (extra token) → nil"] = function()
  eq(date_nl.parse("next week extra"), nil)
end

-- ── M.suggestions() ──────────────────────────────────────────────────────────

T["suggestions: default list returned when no opts"] = function()
  local s = date_nl.suggestions(nil)
  MiniTest.expect.equality(type(s), "table")
  MiniTest.expect.equality(#s > 0, true)
  -- Must include at least "today" and "tomorrow".
  local has_today, has_tomorrow = false, false
  for _, v in ipairs(s) do
    if v == "today" then
      has_today = true
    end
    if v == "tomorrow" then
      has_tomorrow = true
    end
  end
  MiniTest.expect.equality(has_today, true)
  MiniTest.expect.equality(has_tomorrow, true)
end

T["suggestions: custom list from opts"] = function()
  local custom = { "today", "in 5 days" }
  local s = date_nl.suggestions({ date_input = { suggestions = custom } })
  eq(s, custom)
end

T["suggestions: default list is a copy (mutation-safe)"] = function()
  local s1 = date_nl.suggestions(nil)
  local s2 = date_nl.suggestions(nil)
  -- Mutate one; should not affect the other.
  s1[#s1 + 1] = "extra"
  MiniTest.expect.equality(#s1 ~= #s2, true)
end

-- ── Number-words: "one"..."ten" map to digits 1...10 ─────────────────────

T["number_word: 'in two days' equals 'in 2 days'"] = function()
  eq(date_nl.parse("in two days"), date_nl.parse("in 2 days"))
end

T["number_word: 'in three weeks' equals 'in 3 weeks'"] = function()
  eq(date_nl.parse("in three weeks"), date_nl.parse("in 3 weeks"))
end

T["number_word: 'in ten months' equals 'in 10 months'"] = function()
  eq(date_nl.parse("in ten months"), date_nl.parse("in 10 months"))
end

T["number_word: covers one..ten"] = function()
  for word, digit in pairs({
    one = "1",
    two = "2",
    three = "3",
    four = "4",
    five = "5",
    six = "6",
    seven = "7",
    eight = "8",
    nine = "9",
    ten = "10",
  }) do
    eq(date_nl.parse("in " .. word .. " days"), date_nl.parse("in " .. digit .. " days"))
  end
end

T["number_word: 'in eleven days' is NOT supported (number > 10)"] = function()
  -- Upstream supports 1-10.  Beyond that, users write digits.
  eq(date_nl.parse("in eleven days"), nil)
end

T["number_word: 'in the last two days' equals 'in the last 2 days'"] = function()
  eq(date_nl.parse("in the last two days"), date_nl.parse("in the last 2 days"))
end

T["number_word: 'in the last three weeks' equals 'in the last 3 weeks'"] = function()
  eq(date_nl.parse("in the last three weeks"), date_nl.parse("in the last 3 weeks"))
end

T["number_word: 'two days ago' equals '2 days ago'"] = function()
  eq(date_nl.parse("two days ago"), date_nl.parse("2 days ago"))
end

T["number_word: 'three weeks ago' equals '3 weeks ago'"] = function()
  eq(date_nl.parse("three weeks ago"), date_nl.parse("3 weeks ago"))
end

T["number_word: 'two months ago' equals '2 months ago'"] = function()
  eq(date_nl.parse("two months ago"), date_nl.parse("2 months ago"))
end

-- ── parse_range ───────────────────────────────────────────────────────────────

T["parse_range: 'in the last 7 days' → {today-7, today}"] = function()
  local s, e = date_nl.parse_range("in the last 7 days")
  eq(s, days_from_today(-7))
  eq(e, today_str())
end

T["parse_range: 'the last 7 days' (no leading 'in') → {today-7, today}"] = function()
  local s, e = date_nl.parse_range("the last 7 days")
  eq(s, days_from_today(-7))
  eq(e, today_str())
end

T["parse_range: '7 days ago' → {today-7, today}"] = function()
  local s, e = date_nl.parse_range("7 days ago")
  eq(s, days_from_today(-7))
  eq(e, today_str())
end

T["parse_range: 'in the last 2 weeks' → {today-14, today}"] = function()
  local s, e = date_nl.parse_range("in the last 2 weeks")
  eq(s, days_from_today(-14))
  eq(e, today_str())
end

T["parse_range: '2 weeks ago' → {today-14, today}"] = function()
  local s, e = date_nl.parse_range("2 weeks ago")
  eq(s, days_from_today(-14))
  eq(e, today_str())
end

T["parse_range: 'in the last 1 month' → {today-1month, today}"] = function()
  local s, e = date_nl.parse_range("in the last 1 month")
  local t = os.date("*t") --[[@as osdate]]
  t.hour = 0
  t.min = 0
  t.sec = 0
  t.month = t.month - 1
  local expected = os.date("%Y-%m-%d", os.time(t)) --[[@as string]]
  eq(s, expected)
  eq(e, today_str())
end

T["parse_range: '3 months ago' → {today-3months, today}"] = function()
  local s, e = date_nl.parse_range("3 months ago")
  local t = os.date("*t") --[[@as osdate]]
  t.hour = 0
  t.min = 0
  t.sec = 0
  t.month = t.month - 3
  local expected = os.date("%Y-%m-%d", os.time(t)) --[[@as string]]
  eq(s, expected)
  eq(e, today_str())
end

T["parse_range: number words 'in the last two days' → same as '2 days'"] = function()
  local s1, e1 = date_nl.parse_range("in the last two days")
  local s2, e2 = date_nl.parse_range("in the last 2 days")
  eq(s1, s2)
  eq(e1, e2)
end

T["parse_range: number words 'three weeks ago' → same as '3 weeks ago'"] = function()
  local s1, e1 = date_nl.parse_range("three weeks ago")
  local s2, e2 = date_nl.parse_range("3 weeks ago")
  eq(s1, s2)
  eq(e1, e2)
end

T["parse_range: 'the last three weeks' (no 'in') → same as 'in the last 3 weeks'"] = function()
  local s1, e1 = date_nl.parse_range("the last three weeks")
  local s2, e2 = date_nl.parse_range("in the last 3 weeks")
  eq(s1, s2)
  eq(e1, e2)
end

T["parse_range: unrecognised input → nil, nil"] = function()
  local s, e = date_nl.parse_range("tomorrow")
  eq(s, nil)
  eq(e, nil)
end

T["parse_range: empty/nil → nil, nil"] = function()
  local s1, e1 = date_nl.parse_range(nil)
  eq(s1, nil)
  eq(e1, nil)
  local s2, e2 = date_nl.parse_range("")
  eq(s2, nil)
  eq(e2, nil)
end

T["parse_range: 'in the last 0 days' → {today, today}"] = function()
  local s, e = date_nl.parse_range("in the last 0 days")
  eq(s, today_str())
  eq(e, today_str())
end

return T
