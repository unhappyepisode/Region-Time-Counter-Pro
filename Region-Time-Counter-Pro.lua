-- Region Time Counter Pro (macOS-safe UI)
-- Author: 34birds
-- @version 2.2.1
-- @description Fixed 569x524. Total/Selected union, searchable checkbox list, shift range toggle, cmd additive toggle, arrows scroll, persistent checks, scrollbar.
-- @about
--   No js_ReaScriptAPI required.

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

-- Your preferred simple control:
local STATS_LINE_GAP = 5              -- расстояние между строками Total и Selected
local STATS_TO_CONTROLS_GAP = 18      -- расстояние между Selected и блоком кнопок/поиска

-- List inner padding (NEW)
local LIST_PAD_TOP = 6                -- отлепляет первую строку от верхней рамки списка

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
local COL_TOTAL   = {0.25, 0.95, 0.35, 1} -- green
local COL_SEL     = {0.98, 0.86, 0.25, 1} -- yellow

local COL_LIST_BG = {0.10, 0.10, 0.10, 1}
local COL_LIST_BR = {0.25, 0.25, 0.25, 1}
local COL_ROW_ALT = {0.12, 0.12, 0.12, 1}
local COL_ROW_HOV = {0.17, 0.17, 0.17, 1}

-- highlight checked rows
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

-- ===== State =====
local regions = {}
local region_by_id = {}

local checked = {}
local scroll = 0

local total_sec = 0.0
local selected_sec = 0.0

local last_refresh = 0

-- filtered list
local search_query = ""
local search_focus = false
local display = {}

-- mouse + wheel
local last_mouse_cap = 0
local last_mouse_wheel = 0

-- scrollbar
local sb_drag = false
local sb_drag_offset = 0
local sb_thumb_y = 0
local sb_thumb_h = 0
local sb_track_y = 0
local sb_track_h = 0
local sb_max_scroll = 0

-- shift anchor (display indices)
local last_clicked_disp_index = nil

-- ===== Helpers =====
local function setc(t) gfx.set(t[1], t[2], t[3], t[4] or 1) end
local function clamp(x, a, b) if x<a then return a elseif x>b then return b else return x end end
local function trim(s) if not s then return "" end return (tostring(s):gsub("^%s+",""):gsub("%s+$","")) end
local function in_rect(mx,my,x,y,w,h) return mx>=x and mx<(x+w) and my>=y and my<(y+h) end

local function format_hhmmss(sec)
  sec = math.max(0, math.floor(sec + 0.5))
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  return string.format("%02d:%02d:%02d", h, m, s)
end

local function union_length(intervals)
  if not intervals or #intervals == 0 then return 0.0 end
  table.sort(intervals, function(a,b)
    if a[1]==b[1] then return a[2] < b[2] end
    return a[1] < b[1]
  end)
  local total = 0.0
  local cur_s, cur_e = intervals[1][1], intervals[1][2]
  for i=2,#intervals do
    local s,e = intervals[i][1], intervals[i][2]
    if s <= cur_e then
      if e > cur_e then cur_e = e end
    else
      total = total + (cur_e - cur_s)
      cur_s, cur_e = s, e
    end
  end
  total = total + (cur_e - cur_s)
  return total
end

local function lower(s) return string.lower(tostring(s or "")) end
local function contains_ci(hay, needle)
  if needle == "" then return true end
  return lower(hay):find(lower(needle), 1, true) ~= nil
end

-- ===== Persistence =====
local function save_checked()
  local ids = {}
  for id,on in pairs(checked) do
    if on then ids[#ids+1] = tonumber(id) end
  end
  table.sort(ids)
  r.SetProjExtState(proj, EXT_SECTION, EXT_KEY_CHECKED, table.concat(ids, ","))
end

local function load_checked()
  local ret, s = r.GetProjExtState(proj, EXT_SECTION, EXT_KEY_CHECKED)
  if ret ~= 1 or not s or s == "" then return end
  checked = {}
  for token in tostring(s):gmatch("%d+") do
    checked[tonumber(token)] = true
  end
end

-- ===== Regions =====
local function rebuild_regions()
  local new_regions, new_by_id = {}, {}
  local _, numMarkers, numRegions = r.CountProjectMarkers(proj)
  for idx=0,(numMarkers+numRegions-1) do
    local retval, isRegion, startPos, endPos, name, markrgnindexnumber = r.EnumProjectMarkers3(proj, idx)
    if retval and isRegion and endPos > startPos then
      local id = tonumber(markrgnindexnumber)
      local reg = { id=id, start=startPos, ["end"]=endPos, name=name or "", len=(endPos-startPos) }
      new_regions[#new_regions+1] = reg
      new_by_id[id] = reg
    end
  end
  table.sort(new_regions, function(a,b)
    if a.id == b.id then return a.start < b.start end
    return a.id < b.id
  end)
  regions = new_regions
  region_by_id = new_by_id

  for id,_ in pairs(checked) do
    if not region_by_id[id] then checked[id] = nil end
  end
end

local function compute_total()
  local intervals = {}
  for _,reg in ipairs(regions) do
    intervals[#intervals+1] = {reg.start, reg["end"]}
  end
  total_sec = union_length(intervals)
end

local function compute_selected()
  local intervals = {}
  for id,on in pairs(checked) do
    if on then
      local reg = region_by_id[id]
      if reg then intervals[#intervals+1] = {reg.start, reg["end"]} end
    end
  end
  selected_sec = union_length(intervals)
end

local function rebuild_display(reset_anchor)
  display = {}
  local q = trim(search_query)
  for _,reg in ipairs(regions) do
    if q == "" or contains_ci(reg.name, q) or contains_ci(("R"..reg.id), q) then
      display[#display+1] = reg
    end
  end
  scroll = clamp(scroll, 0, math.max(0, #display - 1))
  if reset_anchor then
    last_clicked_disp_index = nil
  end
end

local function refresh(reset_anchor)
  rebuild_regions()
  compute_total()
  compute_selected()
  rebuild_display(reset_anchor)
  last_refresh = r.time_precise()
end

-- ===== UI atoms =====
local function draw_button(x,y,w,h,label,hot)
  setc(hot and COL_BTN_HOV or COL_BTN); gfx.rect(x,y,w,h,1)
  setc(COL_BTN_BR); gfx.rect(x,y,w,h,0)
  gfx.setfont(1, FONT_MAIN, LIST_SIZE)
  setc(COL_TITLE)
  local tw, th = gfx.measurestr(label)
  gfx.x = x + math.floor((w - tw)/2)
  gfx.y = y + math.floor((h - th)/2)
  gfx.drawstr(label)
end

local function draw_checkbox(x,y,on)
  setc(COL_CB_BG); gfx.rect(x,y,CHECK_W,CHECK_W,1)
  setc(COL_CB_BR); gfx.rect(x,y,CHECK_W,CHECK_W,0)
  if on then
    setc(COL_TITLE)
    gfx.x = x + 4
    gfx.y = y - 1
    gfx.drawstr("✓")
  end
end

local function draw_search_box(x,y,w,h,focused)
  setc(COL_SEARCH_BG); gfx.rect(x,y,w,h,1)
  setc(focused and {0.55,0.55,0.55,1} or COL_SEARCH_BR); gfx.rect(x,y,w,h,0)

  gfx.setfont(1, FONT_MAIN, SEARCH_SIZE)
  local text = search_query
  if text == "" and not focused then
    setc(COL_SEARCH_PH)
    gfx.x = x + 8; gfx.y = y + 5
    gfx.drawstr("Search regions by name…")
  else
    setc(COL_SEARCH_TX)
    gfx.x = x + 8; gfx.y = y + 5
    gfx.drawstr(text)
    if focused then
      local tw = select(1, gfx.measurestr(text))
      gfx.x = x + 8 + tw + 1
      gfx.y = y + 5
      gfx.drawstr("|")
    end
  end
end

-- ===== Scrollbar =====
local function compute_scrollbar(list_y, list_h, rows_visible)
  sb_max_scroll = math.max(0, #display - rows_visible)
  sb_track_y = list_y + SB_PAD
  sb_track_h = math.max(8, list_h - SB_PAD*2)

  local total_rows = math.max(1, #display)
  local visible_ratio = rows_visible / total_rows
  sb_thumb_h = math.floor(sb_track_h * visible_ratio)
  sb_thumb_h = clamp(sb_thumb_h, 18, sb_track_h)

  local track_range = sb_track_h - sb_thumb_h
  local t = (sb_max_scroll > 0) and (scroll / sb_max_scroll) or 0
  sb_thumb_y = math.floor(sb_track_y + track_range * t)
end

local function draw_scrollbar(sb_x, sb_y, sb_w, sb_h, hot)
  setc(COL_SB_TRK); gfx.rect(sb_x, sb_y, sb_w, sb_h, 1)
  setc(COL_SB_TRK_BR); gfx.rect(sb_x, sb_y, sb_w, sb_h, 0)

  if sb_max_scroll <= 0 then setc(COL_SB_THMB)
  else setc((sb_drag or hot) and COL_SB_THMB_HOT or COL_SB_THMB) end

  gfx.rect(sb_x+2, sb_thumb_y, sb_w-4, sb_thumb_h, 1)
  setc(COL_SB_THMB_BR); gfx.rect(sb_x+2, sb_thumb_y, sb_w-4, sb_thumb_h, 0)
end

local function scroll_by(delta_rows)
  scroll = clamp(scroll + delta_rows, 0, sb_max_scroll)
end

local function set_scroll_from_thumb_y(y)
  local track_range = sb_track_h - sb_thumb_h
  if track_range <= 0 or sb_max_scroll <= 0 then scroll = 0; return end
  local rel = clamp(y - sb_track_y, 0, track_range)
  local t = rel / track_range
  scroll = math.floor(t * sb_max_scroll + 0.5)
  scroll = clamp(scroll, 0, sb_max_scroll)
end

-- ===== Checking logic =====
local function set_check(id, on) if on then checked[id]=true else checked[id]=nil end end
local function toggle_check(id) if checked[id] then checked[id]=nil else checked[id]=true end end

local function set_all(on)
  if on then for _,reg in ipairs(regions) do checked[reg.id]=true end
  else checked = {} end
  compute_selected()
  save_checked()
end

local function apply_range(from_i, to_i, on)
  if from_i > to_i then from_i, to_i = to_i, from_i end
  for i=from_i, to_i do
    local reg = display[i]
    if reg then set_check(reg.id, on) end
  end
end

-- ===== Keys =====
local KEY_BACKSPACE = 8
local KEY_ENTER1    = 13
local KEY_ENTER2    = 10

local KEY_UP   = 30064
local KEY_DOWN = 1685026670

local function handle_key(ch)
  if ch == 0 then return end
  if ch == KEY_UP then scroll_by(-1); return end
  if ch == KEY_DOWN then scroll_by(1); return end

  if not search_focus then return end

  if ch == KEY_BACKSPACE then
    if #search_query > 0 then
      search_query = search_query:sub(1, #search_query-1)
      rebuild_display(true) -- search change => reset anchor
      scroll = 0
    end
    return
  elseif ch == KEY_ENTER1 or ch == KEY_ENTER2 then
    search_focus = false
    return
  end

  if ch >= 32 and ch <= 126 then
    search_query = search_query .. string.char(ch)
    rebuild_display(true) -- search change => reset anchor
    scroll = 0
  end
end

-- ===== Main loop =====
local function loop()
  if gfx.w ~= WIN_W or gfx.h ~= WIN_H then
    gfx.init(WINDOW_TITLE, WIN_W, WIN_H, 0)
  end

  local ch = gfx.getchar()
  if ch < 0 or ch == 27 then return end
  if ch > 0 then handle_key(ch) end

  -- refresh WITHOUT resetting shift anchor
  if AUTO_REFRESH then
    local now = r.time_precise()
    if (now - last_refresh) >= REFRESH_INTERVAL_SEC then
      local keep_query = search_query
      refresh(false)                 -- <- ключевое: не сбрасываем last_clicked_disp_index
      search_query = keep_query
      rebuild_display(false)
    end
  end

  local mx, my = gfx.mouse_x, gfx.mouse_y
  local cap = gfx.mouse_cap
  local lmb_down = (cap & 1) == 1
  local lmb_click = (lmb_down and (last_mouse_cap & 1) == 0)
  local lmb_release = ((cap & 1) == 0 and (last_mouse_cap & 1) == 1)

  -- modifiers:
  local shift = (cap & 8) == 8
  -- Cmd bit can vary; accept several common bits as "additive modifier"
  local cmd = ((cap & 16) == 16) or ((cap & 32) == 32) or ((cap & 4) == 4)

  -- BG
  setc(COL_BG); gfx.rect(0,0,gfx.w,gfx.h,1)

  -- Title
  gfx.setfont(1, FONT_MAIN, TITLE_SIZE)
  setc(COL_TITLE)
  gfx.x = PAD; gfx.y = PAD
  gfx.drawstr(WINDOW_TITLE)
  local _, title_h = gfx.measurestr(WINDOW_TITLE)

  -- Stats (simple fixed rhythm, as you wanted)
  local right_edge = gfx.w - PAD
  local line1_y = PAD + title_h + GAP
  local line2_y = line1_y + VALUE_SIZE + STATS_LINE_GAP

  local function draw_right_pair(y, label, value, value_color)
    gfx.setfont(1, FONT_MAIN, LABEL_SIZE)
    local lw = select(1, gfx.measurestr(label))
    gfx.setfont(1, FONT_MAIN, VALUE_SIZE)
    local vw = select(1, gfx.measurestr(value))

    local gap = 10
    local x_label = right_edge - (lw + gap + vw)
    local x_value = right_edge - vw

    gfx.setfont(1, FONT_MAIN, LABEL_SIZE)
    setc(COL_LABEL)
    gfx.x = x_label; gfx.y = y
    gfx.drawstr(label)

    gfx.setfont(1, FONT_MAIN, VALUE_SIZE)
    setc(value_color)
    gfx.x = x_value; gfx.y = y
    gfx.drawstr(value)
  end

  draw_right_pair(line1_y, "Total:", format_hhmmss(total_sec), COL_TOTAL)
  draw_right_pair(line2_y, "Selected:", format_hhmmss(selected_sec), COL_SEL)

  -- Controls row (Variant B spacing)
  local controls_y = line2_y + VALUE_SIZE + STATS_TO_CONTROLS_GAP

  local all_x = PAD
  local clr_x = PAD + BTN_W + BTN_GAP
  local hot_all = in_rect(mx,my,all_x,controls_y,BTN_W,BTN_H)
  local hot_clr = in_rect(mx,my,clr_x,controls_y,BTN_W,BTN_H)

  draw_button(all_x, controls_y, BTN_W, BTN_H, "All", hot_all)
  draw_button(clr_x, controls_y, BTN_W, BTN_H, "Clear", hot_clr)

  local search_w = 260
  local search_x = gfx.w - PAD - search_w
  local hot_search = in_rect(mx,my,search_x,controls_y,search_w,SEARCH_H)
  draw_search_box(search_x, controls_y, search_w, SEARCH_H, search_focus)

  if lmb_click then
    if hot_all then
      set_all(true)
    elseif hot_clr then
      set_all(false)
    elseif hot_search then
      search_focus = true
    else
      search_focus = false
    end
  end

  -- List rect
  local list_y = controls_y + math.max(BTN_H, SEARCH_H) + GAP
  local list_x = PAD
  local list_w = gfx.w - PAD*2
  local list_h = gfx.h - list_y - PAD

  setc(COL_LIST_BG); gfx.rect(list_x, list_y, list_w, list_h, 1)
  setc(COL_LIST_BR); gfx.rect(list_x, list_y, list_w, list_h, 0)

  gfx.setfont(1, FONT_MAIN, LIST_SIZE)

  -- Content area (NEW: top padding so first row is not glued to border)
  local content_w = list_w - SB_W - 8
  local content_x = list_x
  local content_y = list_y + LIST_PAD_TOP
  local content_h = list_h - LIST_PAD_TOP

  local rows_visible = math.max(1, math.floor(content_h / ROW_H))
  compute_scrollbar(list_y, list_h, rows_visible)
  scroll = clamp(scroll, 0, sb_max_scroll)

  -- wheel scroll (within content)
  if in_rect(mx,my,content_x,content_y,content_w,content_h) and gfx.mouse_wheel ~= last_mouse_wheel then
    local delta = gfx.mouse_wheel - last_mouse_wheel
    if delta ~= 0 then
      local notch = (delta > 0) and 1 or -1
      scroll_by(-notch * SCROLL_STEP)
    end
    last_mouse_wheel = gfx.mouse_wheel
  else
    last_mouse_wheel = gfx.mouse_wheel
  end

  -- rows
  local right_pad = 10
  for i=0, rows_visible-1 do
    local disp_index = scroll + i + 1
    if disp_index > #display then break end

    local reg = display[disp_index]
    local row_y = content_y + i*ROW_H
    local row_hot = in_rect(mx,my,content_x,row_y,content_w,ROW_H)
    local is_checked = (checked[reg.id] == true)

    if row_hot then
      setc(COL_ROW_HOV); gfx.rect(content_x,row_y,content_w,ROW_H,1)
    elseif is_checked then
      setc(COL_ROW_CHECKED); gfx.rect(content_x,row_y,content_w,ROW_H,1)
    elseif (i%2)==1 then
      setc(COL_ROW_ALT); gfx.rect(content_x,row_y,content_w,ROW_H,1)
    end

    local cb_x = content_x + 8
    local cb_y = row_y + math.floor((ROW_H - CHECK_W)/2)
    draw_checkbox(cb_x, cb_y, is_checked)

    local text_x = cb_x + CHECK_W + 10
    local label = string.format("R%d  %s", reg.id, trim(reg.name))
    local len_str = format_hhmmss(reg.len)

    setc(COL_TEXT)
    gfx.x = text_x
    gfx.y = row_y + math.floor((ROW_H - LIST_SIZE)/2) - 1
    gfx.drawstr(label)

    local lw = select(1, gfx.measurestr(len_str))
    setc(COL_TEXT_DIM)
    gfx.x = content_x + content_w - lw - right_pad
    gfx.y = row_y + math.floor((ROW_H - LIST_SIZE)/2) - 1
    gfx.drawstr(len_str)

    if lmb_click and row_hot then
      local desired = not is_checked
      if shift and last_clicked_disp_index then
        apply_range(last_clicked_disp_index, disp_index, desired)
      else
        toggle_check(reg.id)
      end
      last_clicked_disp_index = disp_index
      compute_selected()
      save_checked()
    end
  end

  -- scrollbar last
  local sb_x = list_x + list_w - SB_W - 2
  local sb_y = list_y + 1
  local sb_h = list_h - 2
  local sb_hot = in_rect(mx,my,sb_x,sb_y,SB_W,sb_h)
  draw_scrollbar(sb_x, sb_y, SB_W, sb_h, sb_hot)

  local thumb_x = sb_x + 2
  local thumb_w = SB_W - 4
  local thumb_y = sb_thumb_y
  local thumb_h = sb_thumb_h

  local over_thumb = in_rect(mx,my,thumb_x,thumb_y,thumb_w,thumb_h)
  local over_sb = in_rect(mx,my,sb_x,sb_y,SB_W,sb_h)

  if lmb_click and over_thumb and sb_max_scroll > 0 then
    sb_drag = true
    sb_drag_offset = my - thumb_y
  elseif lmb_click and over_sb and sb_max_scroll > 0 then
    if my < thumb_y then scroll_by(-rows_visible)
    elseif my > (thumb_y + thumb_h) then scroll_by(rows_visible) end
  end

  if sb_drag then
    if lmb_down and sb_max_scroll > 0 then
      local new_thumb_y = my - sb_drag_offset
      new_thumb_y = clamp(new_thumb_y, sb_track_y, sb_track_y + (sb_track_h - sb_thumb_h))
      set_scroll_from_thumb_y(new_thumb_y)
      compute_scrollbar(list_y, list_h, rows_visible)
    end
    if lmb_release then sb_drag = false end
  end

  gfx.update()
  last_mouse_cap = cap
  r.defer(loop)
end

-- ===== Init =====
gfx.init(WINDOW_TITLE, WIN_W, WIN_H, 0)
load_checked()
refresh(true) -- first build resets anchor
loop()

