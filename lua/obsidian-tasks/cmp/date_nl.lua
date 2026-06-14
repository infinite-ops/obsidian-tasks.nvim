-- lua/obsidian-tasks/cmp/date_nl.lua
-- Natural-language date parser.
--
-- Accepted inputs (case-insensitive, surrounding whitespace stripped):
--   "today"                → today's local date
--   "tomorrow"             → today + 1 day
--   "yesterday"            → today - 1 day
--   "next monday" …        → next occurrence of weekday strictly after today
--                            (on that weekday → +7 days)
--   "this monday" …        → this week's occurrence (today if today is that day)
--   "monday" …             → same as "this monday"
--   "next week"            → today + 7 days
--   "in N days"            → today + N days
--   "in N weeks"           → today + N*7 days
--   "in N months"          → today + N months (calendar arithmetic)
--   "in the last N days"   → today - N days
--   "in the last N weeks"  → today - N*7 days
--   "in the last N months" → today - N months (calendar arithmetic)
--   "N days ago"           → today - N days
--   "N weeks ago"          → today - N*7 days
--   "N months ago"         → today - N months (calendar arithmetic)
--   "YYYY-MM-DD"           → pass-through (validated: month 1-12, day 1-31)
--
-- Returns nil for any unrecognised or invalid input.

local M = {}

--- Weekday name → 0-based index  (Sunday = 0 … Saturday = 6, matching %w).
local WEEKDAY_INDEX = {
  sunday = 0,
  monday = 1,
  tuesday = 2,
  wednesday = 3,
  thursday = 4,
  friday = 5,
  saturday = 6,
}

--- Default suggestions shown in the cmp date-field dropdown.
local DEFAULT_SUGGESTIONS = {
  "today",
  "tomorrow",
  "next monday",
  "next week",
  "in 3 days",
  "in the last 7 days",
  "7 days ago",
}

-- ── helpers ──────────────────────────────────────────────────────────────────

--- Today's local date as a table  { year, month, day, wday }.
--- `os.date("*t")` returns wday 1=Sun … 7=Sat; we normalise to 0=Sun … 6=Sat.
local function today_t()
  local t = os.date("*t") --[[@as osdate]]
  t.wday_0 = t.wday - 1 -- 0-based Sunday-origin
  return t
end

--- Format a time value as "YYYY-MM-DD".
--- @param  t number  seconds since epoch
--- @return string
local function fmt(t)
  return os.date("%Y-%m-%d", t) --[[@as string]]
end

--- Return today's epoch at midnight (local time).
--- We reconstruct midnight to avoid DST edge-cases with naive +86400 arithmetic.
local function today_midnight()
  local t = os.date("*t") --[[@as osdate]]
  t.hour = 0
  t.min = 0
  t.sec = 0
  return os.time(t)
end

--- Add `n` whole days to a midnight epoch.
--- @param  base number  midnight epoch
--- @param  n    number  days (may be negative)
--- @return number
local function add_days(base, n)
  -- Use calendar reconstruction to survive DST transitions.
  local t = os.date("*t", base) --[[@as osdate]]
  t.day = t.day + n
  return os.time(t)
end

--- Add `n` months to a midnight epoch using calendar arithmetic.
--- @param  base number  midnight epoch
--- @param  n    integer months (may be negative)
--- @return number
local function add_months(base, n)
  local t = os.date("*t", base) --[[@as osdate]]
  t.month = t.month + n
  return os.time(t) -- os.time normalises overflow automatically
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Parse a natural-language date string into YYYY-MM-DD.
---
--- @param  arg string|nil  raw input (may contain surrounding whitespace)
--- @return string|nil      "YYYY-MM-DD" on success, nil on failure
function M.parse(arg)
  if not arg or arg == "" then
    return nil
  end

  local trimmed = vim.trim(arg)
  if trimmed == "" then
    return nil
  end
  local lower = trimmed:lower()

  -- Number-word substitution: `in two weeks` → `in 2 weeks`.  Upstream covers
  -- one..ten.  Run before any "in N <unit>" pattern matches.
  local NUMBER_WORDS = {
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
  }
  -- Handle "in two weeks" pattern
  local nw_word, nw_unit = lower:match("^in (%a+) (%a+)$")
  if nw_word and NUMBER_WORDS[nw_word] then
    lower = "in " .. NUMBER_WORDS[nw_word] .. " " .. nw_unit
  end
  -- Handle "in the last two weeks" pattern
  local ntlw_word, ntlw_unit = lower:match("^in the last (%a+) (%a+)$")
  if ntlw_word and NUMBER_WORDS[ntlw_word] then
    lower = "in the last " .. NUMBER_WORDS[ntlw_word] .. " " .. ntlw_unit
  end
  -- Handle "two weeks ago" pattern
  local nwa_word, nwa_unit = lower:match("^(%a+) (%a+) ago$")
  if nwa_word and NUMBER_WORDS[nwa_word] then
    lower = NUMBER_WORDS[nwa_word] .. " " .. nwa_unit .. " ago"
  end

  -- ── relative keywords ──────────────────────────────────────────────────────
  if lower == "today" then
    return fmt(today_midnight())
  end

  if lower == "tomorrow" then
    return fmt(add_days(today_midnight(), 1))
  end

  if lower == "yesterday" then
    return fmt(add_days(today_midnight(), -1))
  end

  if lower == "next week" then
    return fmt(add_days(today_midnight(), 7))
  end

  -- ── in N days / weeks / months ─────────────────────────────────────────────
  local n_days = lower:match("^in (%d+) days?$")
  if n_days then
    return fmt(add_days(today_midnight(), tonumber(n_days)))
  end

  local n_weeks = lower:match("^in (%d+) weeks?$")
  if n_weeks then
    return fmt(add_days(today_midnight(), tonumber(n_weeks) * 7))
  end

  local n_months = lower:match("^in (%d+) months?$")
  if n_months then
    return fmt(add_months(today_midnight(), tonumber(n_months)))
  end

  -- ── in the last N days / weeks / months ────────────────────────────────────
  local last_n_days = lower:match("^in the last (%d+) days?$")
  if last_n_days then
    return fmt(add_days(today_midnight(), -tonumber(last_n_days)))
  end

  local last_n_weeks = lower:match("^in the last (%d+) weeks?$")
  if last_n_weeks then
    return fmt(add_days(today_midnight(), -tonumber(last_n_weeks) * 7))
  end

  local last_n_months = lower:match("^in the last (%d+) months?$")
  if last_n_months then
    return fmt(add_months(today_midnight(), -tonumber(last_n_months)))
  end

  -- ── N days / weeks / months ago ────────────────────────────────────────────
  local ago_n_days = lower:match("^(%d+) days? ago$")
  if ago_n_days then
    return fmt(add_days(today_midnight(), -tonumber(ago_n_days)))
  end

  local ago_n_weeks = lower:match("^(%d+) weeks? ago$")
  if ago_n_weeks then
    return fmt(add_days(today_midnight(), -tonumber(ago_n_weeks) * 7))
  end

  local ago_n_months = lower:match("^(%d+) months? ago$")
  if ago_n_months then
    return fmt(add_months(today_midnight(), -tonumber(ago_n_months)))
  end

  -- ── next <weekday> ─────────────────────────────────────────────────────────
  -- Strictly after today: if today IS that weekday, returns +7 days.
  local next_wd = lower:match("^next (%a+)$")
  if next_wd and WEEKDAY_INDEX[next_wd] ~= nil then
    local target = WEEKDAY_INDEX[next_wd]
    local today = today_t()
    local delta = target - today.wday_0
    if delta <= 0 then
      delta = delta + 7
    end
    return fmt(add_days(today_midnight(), delta))
  end

  -- ── this <weekday>  /  bare <weekday> ─────────────────────────────────────
  -- Returns today if today is that weekday; otherwise the most recent past
  -- occurrence in the same ISO week is NOT used — instead we walk backward in
  -- the *current calendar week* (Sun–Sat).  Spec: "this week's occurrence
  -- (today if today is that day)".  For days already past in the week we
  -- return the negative-delta day (e.g. "this monday" on Tuesday = yesterday).
  local this_wd = lower:match("^this (%a+)$")
  local bare_wd = WEEKDAY_INDEX[lower] ~= nil and lower or nil
  local wd_name = this_wd or bare_wd
  if wd_name and WEEKDAY_INDEX[wd_name] ~= nil then
    local target = WEEKDAY_INDEX[wd_name]
    local today = today_t()
    local delta = target - today.wday_0
    -- delta may be negative (past this week) or zero (today) or positive (later this week)
    return fmt(add_days(today_midnight(), delta))
  end

  -- ── ISO YYYY-MM-DD pass-through ────────────────────────────────────────────
  if trimmed:match("^%d%d%d%d%-%d%d%-%d%d$") then
    local month = tonumber(trimmed:sub(6, 7))
    local day = tonumber(trimmed:sub(9, 10))
    if month >= 1 and month <= 12 and day >= 1 and day <= 31 then
      return trimmed
    end
    return nil
  end

  return nil
end

--- Parse a backward-looking NL date phrase into an inclusive [start, end] range.
---
--- Recognised patterns (case-insensitive):
---   "in the last N days/weeks/months"  → { today-N, today }
---   "the last N days/weeks/months"     → { today-N, today }  (without leading "in")
---   "N days/weeks/months ago"          → { today-N, today }
---
--- Number words (one..ten) are supported in all forms.
--- Returns nil for unrecognised input.
---
--- @param  arg string|nil  raw input
--- @return string|nil      start ISO date
--- @return string|nil      end ISO date (always today)
function M.parse_range(arg)
  if not arg or arg == "" then
    return nil, nil
  end
  local trimmed = vim.trim(arg)
  if trimmed == "" then
    return nil, nil
  end
  local lower = trimmed:lower()

  local NUMBER_WORDS = {
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
  }

  local n_val, unit

  local d1, u1 = lower:match("^in the last (%a+) (%a+)$")
  if d1 and NUMBER_WORDS[d1] then
    n_val = tonumber(NUMBER_WORDS[d1])
    unit = u1
  end

  if not n_val then
    local d2, u2 = lower:match("^the last (%a+) (%a+)$")
    if d2 and NUMBER_WORDS[d2] then
      n_val = tonumber(NUMBER_WORDS[d2])
      unit = u2
    end
  end

  if not n_val then
    n_val, unit = lower:match("^in the last (%d+) (%a+)$")
    if n_val then
      n_val = tonumber(n_val)
    end
  end

  if not n_val then
    n_val, unit = lower:match("^the last (%d+) (%a+)$")
    if n_val then
      n_val = tonumber(n_val)
    end
  end

  if not n_val then
    local a1, a2 = lower:match("^(%a+) (%a+) ago$")
    if a1 and NUMBER_WORDS[a1] then
      n_val = tonumber(NUMBER_WORDS[a1])
      unit = a2
    end
  end

  if not n_val then
    n_val, unit = lower:match("^(%d+) (%a+) ago$")
    if n_val then
      n_val = tonumber(n_val)
    end
  end

  if not n_val then
    return nil, nil
  end

  local today = today_midnight()
  local start_date

  if unit == "day" or unit == "days" then
    start_date = fmt(add_days(today, -n_val))
  elseif unit == "week" or unit == "weeks" then
    start_date = fmt(add_days(today, -n_val * 7))
  elseif unit == "month" or unit == "months" then
    start_date = fmt(add_months(today, -n_val))
  else
    return nil, nil
  end

  return start_date, fmt(today)
end

--- Return a list of suggestion strings for the date cmp dropdown.
---
--- @param  opts table|nil  { date_input = { suggestions = { ... } } }
--- @return string[]
function M.suggestions(opts)
  if opts and opts.date_input and opts.date_input.suggestions then
    return opts.date_input.suggestions
  end
  return vim.deepcopy(DEFAULT_SUGGESTIONS)
end

return M
