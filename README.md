# Region Time Counter Pro

**34dev.tools**

Advanced region time calculator for REAPER with union-based totals, searchable checkbox list, and persistent selections.

Built by **34dev — Audio Tools by Alexey Vorobyov (34birds)**.


A small REAPER ReaScript that shows:
- **Total**: unique (union) length of all regions (no double-counting overlaps)
- **Selected**: unique (union) length of regions you mark via **checkboxes** inside the script UI

Includes a searchable region list, checkboxes, shift-range toggling, scrolling, and persistent selection.

✅ **No js_ReaScriptAPI required** (pure `gfx` UI).

---

## Features

- **Total (union):** sums region time without double-counting overlaps
- **Selected (union):** sums only checked regions, also without overlap double-counting
- **Checkbox list** with per-region duration
- **Search** by region name (also matches `R<ID>`)
- **All / Clear** buttons
- **Mouse wheel scrolling**
- **Scrollbar** with dragging
- **Keyboard:** ↑ / ↓ scroll
- **Shift-click range** toggle for checkboxes
- **Persistent checks** saved in the project (ProjExtState)

---

## Requirements

- REAPER 6+ (should work on 7+ as well)
- No extensions needed (works without js_ReaScriptAPI)

> Note: UI uses the `gfx` library, so it’s cross-platform.  
> On Windows, `Helvetica` may fall back to a system font (visuals may differ slightly).

---

## Installation

### Option A — Manual (recommended)
1. Download the script file:
   `ReaScripts/34birds_Region Time Counter Pro.lua`
2. In REAPER:  
   `Actions → Show action list… → ReaScript → Load…`
3. Select the `.lua` file.
4. Run it from the Action List.

(Optional) assign a shortcut or add it to a toolbar.

### Option B — As a Git clone
1. Clone the repo anywhere on your machine.
2. Load the `.lua` file into REAPER via `ReaScript → Load…`.

---

## Usage

1. Create regions in your project (`Insert → Region…` or Region/Marker Manager).
2. Run **Region Time Counter Pro**.
3. Check regions in the list:
   - click a row to toggle its checkbox
   - **Shift-click** to toggle a range
4. Use **Search** to filter regions by name.
5. **Total** and **Selected** update automatically (every 0.5s by default).

---

## Notes / Behavior

- **Selected** is driven by the script’s own checkbox list (not by Region/Marker Manager selection).
- Checkbox state is stored per-project via `SetProjExtState`, so it persists between runs.
- Total and Selected use **union logic**:
  overlapping regions are only counted once.

---

## Customization

Inside the script:

- Window size:
  `WIN_W, WIN_H = 569, 524`
- Typography:
  `TITLE_SIZE`, `LABEL_SIZE`, `VALUE_SIZE`, `LIST_SIZE`, `SEARCH_SIZE`
- Spacing:
  - `STATS_LINE_GAP`
  - `STATS_TO_CONTROLS_GAP`
  - `LIST_PAD_TOP`
- Refresh:
  - `AUTO_REFRESH`
  - `REFRESH_INTERVAL_SEC`

---

## Screenshots

![UI](screenshots/ui.png)

---

## License

MIT — see [LICENSE](LICENSE).

---

## Author

34birds
