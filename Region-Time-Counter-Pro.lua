-- Region Time Counter Pro
-- 34dev.tools
--
-- Author: 34dev — Audio Tools by Alexey Vorobyov (34birds)
-- Version: 2.2.1
--
-- Description:
--   Advanced region time calculator for REAPER.
--   Shows total and selected region duration using union logic
--   (no double-counting of overlapping regions).
--
-- Features:
--   - Total (union): duration of all regions
--   - Selected (union): duration of checked regions
--   - Searchable checkbox list with per-region duration
--   - Shift-click range selection
--   - Mouse wheel + draggable scrollbar
--   - Keyboard scrolling (↑ / ↓)
--   - Persistent selection stored in project
--   - No js_ReaScriptAPI required (pure gfx UI)
--
-- License: MIT

local r = reaper
local proj = 0

-- ===== Fixed window (BASE) =====
local WINDOW_TITLE = "Region Time Counter Pro"
local WIN_W, WIN_H = 569, 524

-- ===== Typography (BASE) =====
local FONT_MAIN  = "Helvetica"
local TITLE_SIZE = 24
local LABEL_SIZE = 24
local VALUE_SIZE = 24
local LIST_SIZE  = 16
local SEARCH_SIZE= 16

-- ===== Layout =====
local PAD = 14
local GAP = 10

local ROW_H = 22
local CHECK_W = 18

local BTN_W = 90
local BTN_H = 26
local BTN_GAP = 10

local SEARCH_H = 26

local STATS_LINE_GAP = 5
local STATS_TO_CONTROLS_GAP = 18

local LIST_PAD_TOP = 6

-- Scroll
local SCROLL_STEP = 3
local SB_W = 12
local SB_PAD = 3

-- Refresh
local AUTO_REFRESH = true
local REFRESH_INTERVAL_SEC = 0.5

-- Persistence (in project)
local EXT_SECTION = "RTCPro"
local EXT_KEY_CHECKED = "checked_ids"

-- ===== Colors =====
local COL_BG      = {0.07, 0.07, 0.07, 1}
local COL_TITLE   = {0.95, 0.95, 0.95, 1}
local COL_LABEL   = {0.85, 0.85, 0.85, 1}
local COL_TOTAL   = {0.25, 0.95, 0.35, 1}
local COL_SEL     = {0.98, 0.86, 0.25, 1}

local COL_LIST_BG = {0.10, 0.10, 0.10, 1}
local COL_LIST_BR = {0.25, 0.25, 0.25, 1}
local COL_ROW_ALT = {0.12, 0.12, 0.12, 1}
local COL_ROW_HOV = {0.17, 0.17, 0.17, 1}
local COL_ROW_CHECKED = {0.14, 0.14, 0.10, 1}

local COL_TEXT    = {0.92, 0.92, 0.92, 1}
local COL_TEXT_DIM= {0.85, 0.85, 0.85, 1}

local COL_BTN     = {0.14, 0.14, 0.14, 1}
local COL_BTN_HOV = {0.20, 0.20, 0.20, 1}
local COL_BTN_BR  = {0.35, 0.35, 0.35, 1}

local COL_CB_BG   = {0.12, 0.12, 0.12, 1}
local COL_CB_BR   = {0.35, 0.35, 0.35, 1}

local COL_SB_TRK  = {0.09, 0.09, 0.09, 1}
local COL_SB_TRK_BR = {0.30, 0.30, 0.30, 1}
local COL_SB_THMB = {0.26, 0.26, 0.26, 1}
local COL_SB_THMB_HOT = {0.32, 0.32, 0.32, 1}
local COL_SB_THMB_BR = {0.38, 0.38, 0.38, 1}

local COL_SEARCH_BG = {0.12, 0.12, 0.12, 1}
local COL_SEARCH_BR = {0.35, 0.35, 0.35, 1}
local COL_SEARCH_TX = {0.92, 0.92, 0.92, 1}
local COL_SEARCH_PH = {0.55, 0.55, 0.55, 1}

-- ===== Helpers =====
local function setc(t) gfx.set(t[1], t[2], t[3], t[4] or 1) end
local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end
local function trim(s) if not s then return "" end return (tostring(s):gsub("^%s+",""):gsub("%s+$","")) end

local function format_hhmmss(sec)
  sec = math.max(0, math.floor(sec + 0.5))
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  return string.format("%02d:%02d:%02d", h, m, s)
end

local function union_length(intervals)
  if not intervals or #intervals == 0 then return 0 end
  table.sort(intervals, function(a,b) return a[1] < b[1] end)
  local total, s, e = 0, intervals[1][1], intervals[1][2]
  for i=2,#intervals do
    local cs, ce = intervals[i][1], intervals[i][2]
    if cs <= e then
      if ce > e then e = ce end
    else
      total = total + (e - s)
      s, e = cs, ce
    end
  end
  return total + (e - s)
end

-- ===== Init =====
gfx.init(WINDOW_TITLE, WIN_W, WIN_H, 0)
reaper.defer(function() end)
