# Home HQ UI spec (from Wes Bos's prototype)

Source: `~/Work/photo-frame-dashboard/dashboard/` (vanilla JS + CSS, Vite). Every behavior below
must exist in the Rails version. Line refs are to that prototype. Read alongside `plan.md`.

## 0. Shell and global systems

- **Stage:** fixed 1280×800 `#stage` (base.css:41), 76px left rail + content. `fit()` (app.js:310)
  scales with a CSS transform (desktop preview only). Overlay z-order: banners 40, sheet 50,
  toasts 60, ambient 65, night 66, takeover 70, demo 90, diag 100.
- **Rail** (index.html:26): Today `#home`, Calendar `#calendar`, Chores `#tasks`, Shopping
  `#shopping`, Photos `#photos`, Home `#control`, Agents `#agents`. Switches on **pointerdown**
  for instant feel. Rail clock at the bottom (H:MM + AM/PM, per minute); **hold 700 ms opens the
  demo drawer**.
- **Router** `App.go` (app.js:171): `history.replaceState` hash routes, unknown → home. All views
  are built once and kept in the DOM (`content-visibility:hidden` when hidden). `data`/`time`
  events mark views dirty; hidden views rebuild in the background (1500 ms, then 400 ms apart).
  Hooks: show/resume/hide. Full rebuilds cost 350-500 ms on the tablet: **one page, all views warm,
  granular patches; never a page visit per tab.**
- **Keyboard:** D demo drawer, A ambient, N night, Esc closes drawer/sheet, 1-7 views; ignored
  while an input has focus.
- **Toasts** `App.toast(html,{ms,icon,tone,undo})`: one at a time, 5 s default, `tone:'error'`
  red, optional **Undo**.
- **Sheets** `App.sheet`: single centred modal, 620 px (`--wide` 900, camera 1000), max 720 high,
  scrim/X closes.
- **Hold** `App.hold(el, ms, {enabled, done, cancel})`: `.is-holding` while pressed; early release
  → `cancel` (used for "keep holding" hints).
- **Modes** (`stage[data-mode]`): `day`, `ambient` (photo frame), `night` (dim red clock),
  `nightdash` (full UI through a red CSS filter).
- **Idle machine** (app.js:293), 1 s tick, any pointerdown resets: day + 60 s on a non-home view →
  close sheet, go home; day + 120 s → home, then night if hour ≥22 or <6 else ambient; nightdash +
  20 s → night. Takeovers block idle. Ambient/night persist until touched. No brightness control.
- **Demo clock:** `App.now()` = real time + offset; prototype forces 15:18 at start. **Rails uses
  real time**; offset stays as a dev tool. Startup tip toast at 1.2 s. `index.html:59` reloads if
  the app hasn't booted in 10 s (wall self-heal).
- **Tick:** `second` every second, `minute` on rollover.
- **Diagnostics** (`?diag`, persisted in localStorage `hq-diag`): UA, viewport, DPR, fps, jank,
  DOM nodes, image MP, heap, per-tab-switch timings. `?exp=font,scale,has,shadow,img,noframe`
  strips features. Keep as a debug flag.

## 1. Views

### 1.1 Today / home (home.js) - never scrolls
12-col grid; row 1 (184 px): clock 1-4, weather 5-9, presence 10-12. Row 2: main 1-7 (hero 232 px
+ person lanes), side 8-12 (photo tile, chores card 142 px, shopping + home-status cards 150 px).

- **Clock:** time, AM/PM, weekday, date. Tap → calendar.
- **Weather** (`App.weatherNow`): icon, temp, condition, hi/lo. Advice: raining now (≥50%) →
  "Rain until X" + "Umbrella weather"; rain later → "Rain from X" + **"Pack a rain jacket for
  soccer"** if a remaining event today matches /soccer/i, else "Grab a rain jacket"; dry and <12° →
  "Clear and cool" + "Jacket weather"; else "Dry all day" + "Light layers". 7 hourly cells (Now, 4p,
  5p...), icon raised up to 8 px by temp, wet cells blue.
- **Presence:** per person avatar (outlined when away), name, "Home" | **"ETA N min"** | free-text
  status. Display only.
- **Hero "Next up"** (`App.nextEvent`): today's upcoming timed events **sorted by leave-by**
  (start − travel). Card in the person's colour (black for family): "Next up · names|Everyone",
  title, time, location, dots. Big number = minutes to start if <100, else start time. Leave pill
  only with travel: **"Leave now"** (red, pulsing) ≤0, "Leave in N min" (dark) ≤15, else plain.
  Tap → event sheet. Nothing left: "Nothing else scheduled. Enjoy the quiet." + "Tomorrow starts
  with X at T" (tap → calendar).
- **Lanes:** 4 person columns, up to 3 remaining timed events today; current = "Now", filled;
  "+N more" → calendar; empty "Free the rest of the day"; tap → event sheet.
- **Photo tile:** slideshow (cover, 12 s) + caption "On this day · N years ago today" / "N years
  ago" + place. Tap → photos.
- **Chores card:** "Chores · {routine}", 64 px ring per person + Anyone (done/total, ✓ when
  complete; people with none omitted). Tap → chores.
- **Shopping card:** open count + last 3 open items. Tap → shopping.
- **Home card:** lights on, security ("All locked" | "Garage open" | "{lock} unlocked", amber when
  insecure), inside temp. Tap → home control.
- Refresh: clock + hero every minute (even hidden); weather + lanes hourly; full repaint on data
  if visible; slideshow paused when hidden.

### 1.2 Calendar (calendar.js)
- **Header:** prev/next (1, 3 or 7 days; a month in month mode), title + kicker ("Monday 12",
  "October 2026 · Today/Tomorrow"), **Today** button (hidden when already there), mode toggle
  Today / 3 Day / Week / Month, **+** add.
- **Swipe** |dx|>90, |dy|<60, <700 ms, outside header → next/prev (the app's only swipe).
- **Time grid** (Today, 3-Day): 6 AM-11 PM, 72 px/hour, "Noon". Auto-scroll to now − 170 px; scroll
  kept across re-renders, reset on navigation. Red now-line with label, updated in place each minute.
- **Today:** one column per person; family events (everyone) as black full-width blocks; all-day
  row per person, family spans all; multi-day "Day N of M", continuation arrow + square corners.
  Empty: "Nothing on the calendar. A rare, quiet day."
- **3-Day:** day columns (date, Today/Tomorrow/weekday, month), today shaded, all-day bars span with
  ←/→ when continuing, now-line on today only.
- **Overlap** `layout()`: clusters, greedy columns, **max 2**; 3+ → column 0 kept, rest collapse
  into a dashed **"+N more"** block → "Overlapping" sheet.
- **Event block** `evBlock()`: first person's colour (black family); past 38% opacity; current
  ringed; <45 min compact; meta = time + **"🚗 Leave H:MM"** with travel; **hatched travel block**
  above the event (height = travel minutes); attendee dots.
- **Week:** rolling 7 days from the selected date; all-day chips, then up to 7 − allDay timed events
  (dot, time, 2-line title), "+N more", "Free". Tap column/+N → Today mode on that date.
- **Month:** Monday-start 6×7; out-of-month faded; today inverted; up to 5 coloured dots + "+N";
  tap → Today mode.
- **Event sheet** `App.eventSheet`: colour band (day label, title, time or "All day"); rows:
  **"Leave by H:MM AM" / "{travel} min drive in current traffic"** (if travel); **location / "Tap to
  send directions to phone"** (prototype has no handler; Rails implements it); people chips;
  notes as serif quote.
- **Add sheet:** title + idea chips (Soccer, Playdate, Dentist, Dinner out, Swim, Birthday party);
  Who (multi-select + Everyone); When (today..+4); Time (8 AM, Noon, 3:30, 4:30, 6, 7:30 PM);
  Length (30m/1h/2h). Save: empty title → "New event", nobody → default person; jump to that day;
  toast with **Undo** (deletes). Prototype has no location/travel/notes/all-day/edit (Rails may add).
- Client state: mode, date, scroll. `time` event resets date to today.

### 1.3 Chores (tasks.js)
- **Routines:** Morning (0-11, label "6 - 11 AM"), After school (11-17), Evening (17-24);
  `App.currentRoutine` by hour.
- **Header:** "Right now · {range}" when current, routine name, routine toggle (selecting current
  clears override; `time` clears it), progress done/total + bar.
- **Lanes:** one per person + **Anyone**. Header: avatar, name; kids = star total; adults "N of M" /
  "Nothing"; Anyone "Up for grabs"; ring or ✓.
- **Rows:** not-done first, then overdue; emoji tile, title, red "Overdue" | "★N · {doneBy}" |
  "by {name}". "All done!" / "Nothing this morning/afternoon/evening". Kids: **"This week" Mon-Sun
  hit/miss strip** (Rails derives it from history).
- **Tap not-done:** 350 ms check animation → done; stars to the owner (kid) or the `doneBy` kid;
  toast "X done · +N★ Name" with **Undo** (reverses stars). Whole routine done → "{Routine} routine
  complete! Everyone crushed it." (no undo).
- **Tap Anyone chore:** **"Who did it?"** sheet with big avatars → complete with doneBy.
- **Tap done chore:** un-complete, deduct stars, no toast. Taps during the animation ignored.

### 1.4 Shopping (shopping.js)
- Header: "Shared list / Groceries", "N to get", store filter with counts (All + each store).
- List grouped by category in **per-store aisle order** (`catOrder[store]`), "Other" last, counts.
  Row: checkbox, name, note, store badge (in All), qty − / + (min 1). Empty: "All stocked up.
  Nothing left to buy."
- **Check:** strikethrough + pending, toast with **Undo**; commits after 1200 ms and the row leaves;
  re-tap in the window cancels.
- **"Got it (N)" drawer:** checked items with "Add back"; **"Clear N checked items"** with Undo.
- **Side panel:** "Add an item…" (Enter adds). Typing → up to 5 catalogue suggestions (prefix then
  substring) with "On list · ×qty" or category, + "Add '{text}'" with auto category. Empty input →
  **"Usuals · tap to add"** 3×4 tiles ("On list ×N" inverted).
- **Add:** existing open → qty+1 ("Already on the list · now ×N"); previously checked → revive qty 1;
  else create with catalogue name or capitalised text, `categorize()` (exact → substring → word >3
  chars → Other), store = current filter (or default), empty note; flash 1.2 s, scroll into view,
  toast. Prototype can't edit note/store/category or delete one item (phone UI should).

### 1.5 Photos (photos.js, slideshow.js)
- Full bleed. Layout toggle Auto / Cover / Pair / Collage / Polaroid. Buttons prev / ♥ / next.
  Tap zones: left 22% prev, centre 56% "loud" captions, right 22% next.
- **Favourite** toggles `fav`: "Added to favourites · it'll show up more often"; favourites queued
  twice per cycle.
- **Slideshow** `App.Slideshow(el,{layout,interval,captions,onChange})`: shuffle with
  **on-this-day first**; auto: portrait → pair with same-`tag` portrait else polaroid; landscape:
  slide 3 of 5 collage (3 photos), 4 of 5 polaroid, else cover. Captions: "On this day · N years ago
  today · Place" + date. Waits ≤2.5 s for the next image; failed images hidden. Intervals: photos
  15 s, home tile 12 s, ambient 14 s. No crossfades/Ken Burns (removed for tablet perf).

### 1.6 Home control (control.js)
- Left: summary cards, scenes, scrolling rooms. Right (360 px): climate, cameras, now playing.
- **Summary:** Lights "N on in M rooms" (→ Lights sheet), Security "Locked / All doors + garage" or
  count + names, amber (→ Security sheet), Climate temp + "Heating/Cooling/Holding to X°" / "System
  off" (pulses panel), Media Playing/Paused + "{room} speaker" (pulses panel).
- **Scenes** Morning, Dinner, Movie, Away, Goodnight: per-device levels (0 = off), blind positions;
  Away/Goodnight lock all locks; active scene highlighted until a manual change; toast **Undo**
  restores a full snapshot.
- **Room tiles** (4-col): **light** tap toggles (restore last level or 100), **horizontal drag =
  dimmer** (>10 px starts; 0 = off; "N%"/"Off"); **blind** same gesture / tap 0↔100 ("Closed",
  "Open", "N% open"); **lock** **hold 1 s to unlock** with progress ring, early release hint toast,
  tap locks, taps within 800 ms of a hold ignored, unlocked amber; **garage** tap → **slide-to-
  confirm sheet** → opening/closing (stripes) → open/closed, direction-specific copy.
- **Optimistic contract** `App.setDevice(id, patch)`: apply immediately + pending dot → confirm, or
  fail → revert + red toast "Couldn't reach X · it may be offline". **The real bridge must drive
  exactly this.**
- **Lights sheet:** all lights (on first), live tiles, "Turn everything off" with Undo.
- **Security sheet:** locks + garage, "Lock all doors".
- **Climate:** setpoint −/+ 0.5°, clamped; adjusting while off → heat; "{current}° inside",
  Heating/Cooling/Holding/Off badge, humidity; mode Heat / Cool / Auto / Off.
- **Cameras:** "Snapshots every 20 s", first two cameras, "Ns ago" age; tap → large camera sheet
  ("LIVE", "Snapshot · Ns ago").
- **Now playing:** art, room, title, artist, play/pause.

### 1.7 Agents (agents.js) - display only
3×2 grid: provider cards + summary. "Updated N min ago" + refresh. Card: swatch, name, plan,
Operational / Degraded, incident strip or "Near the session limit" (any meter ≥85%). Meters:
label, used %, bar (red ≥85), **pace marker** at (1 − left/win), footer detail · "Resets in 2h
14m" · "On pace" / "N% over/under pace". Footer: tokens today, "$X API cost" / "Incl. in plan",
7-day sparkline. Summary: 7-day tokens, $ today, stacked 7-day bars, legend.

### 1.8 Ambient and night (ambient.js)
- **Ambient:** full-screen slideshow (14 s), big time + date, weather, next-event pill (colour dot,
  title, time), presence avatars. Tap → day + home.
- **Night:** red clock on black; weather · "First up today/tomorrow: **Title** time · Person" or
  "Nothing early tomorrow" (after 6 AM looks at the next day); "House locked · alarm armed"
  (Rails derives from real state). Tap → nightdash.
- **Burn-in:** info block shifted ±4 px every 60 s.

### 1.9 Alerts (system.js)
- **Doorbell takeover:** full-screen porch image, "LIVE · Front Porch", "Doorbell · time",
  "Someone's at the front door"; Talk toggle; **hold to unlock** → "Front door unlocked · relocks in
  2 min" (Rails implements the relock); Dismiss; auto-close 45 s. Any takeover forces day mode,
  closes sheets.
- **Water-leak takeover:** red, "WATER LEAK", sensor text; **hold 1.2 s to shut off water**;
  Acknowledge → "Leak acknowledged by the kitchen display".
- **Banners** (stacked, action + dismiss, optional auto-dismiss): **Garage open** "open for 15 min
  · No one is in the garage · Wes is 12 min away" (Rails derives) → "Close garage" (slide sheet) /
  "Leave open"; **Package delivered** "Front porch · time", auto 9 s, "View camera".
- **Demo drawer:** time presets, Ambient/Night, fast idle, alert triggers, calendar Normal / Empty
  / Overloaded. Keep as an admin/dev tool.

## 2. Data model implied by the prototype

| Entity | Fields | Written by UI? |
|---|---|---|
| Person | name, color, rgb, ink, kid (implicit via stars), home, status, eta | presence is external |
| Event | title, start, end, all_day (exclusive end, multi-day), people[], loc, travel (min), notes | create, delete (undo) |
| Routine | name, range label, from/to hour | config |
| Chore | routine, who (person or any), title, emoji, stars, done, done_by, overdue | complete/uncomplete; needs daily reset |
| Stars | per kid total (mutated) | ledger recommended |
| Week strip | per kid Mon-Sun hit/miss (static in prototype) | derive from history |
| Store | name; catOrder per store (aisle order) | config |
| Grocery item | name, cat, qty ≥1, store, done, note | create, qty, check, revive, bulk delete |
| Catalog / usuals | [name, category]; 12 usual names | config / derived |
| Room / Device | room, type light/blind/lock/garage, name; on+level / pos / locked / state | via smart-home bridge |
| Scene | name, icon, device levels; Away/Goodnight lock all | apply via bridge |
| Climate | current, set, mode, humidity | set + mode via bridge |
| Media | room, title, artist, playing, art | play/pause via bridge |
| Camera | name, snapshot + time, live stream | read |
| Weather | hourly temp/condition/precip, hi, lo | external |
| Photo | url, orientation, date, place, uploader, tag (album), fav | fav |
| Agent | name, plan, colour, status, incident, meters (window, used %, reset at), tokens, cost, 7-day | external |

Derived: family event (everyone), event colour, leave-by, next event, routine, rings,
on-this-day, pace.

## 3. Mocked pieces that need real integrations
1. Calendar sync (read; write for Add), calendar → person mapping.
2. Travel time from home (traffic-aware), geocoded locations; drives leave-by, hero order, hatched
   blocks.
3. "Send directions to phone": push with a maps link to the right person's phone.
4. Presence/ETA (home, status, eta; also feeds banner copy).
5. Weather (hourly + hi/lo, mapped to sun/moon/partly/cloud/rain).
6. Smart home (lights, blinds, locks, garage, thermostat, scenes, media) with command ack/fail and
   push updates.
7. Cameras (snapshots ~20 s, doorbell live view).
8. Alerts (doorbell, leak, garage-open duration, package) pushed to the frame; auto-relock; valve.
9. Night line derived from locks/alarm.
10. Photo library (date, place, orientation, uploader, album; on-this-day; resized variants).
11. AI agent usage (meters, resets, tokens, cost, history, incidents).
12. Chore daily reset and history.

## 4. Timing
1 s tick; minute rollover repaints; hourly weather/lanes; camera age per second while visible;
pixel shift 60 s; slideshows 12/14/15 s; idle 60 s / 120 s / 20 s; toasts 5 s; package banner 9 s;
doorbell 45 s; chore check 350 ms; grocery commit 1200 ms; device confirm 600 ms; garage 4 s;
prebuild 1500 + 400 ms; self-heal 10 s. Backend refresh targets: calendar ~5 min, weather ~30 min,
presence/ETA ~1 min, cameras 20 s, agents a few min, devices pushed.

## 5. Screen and phone
Hard-coded 1280×800 at density 160, `width=1280` viewport, px fonts 14-260 px, **no media
queries**, fixed grids, 620-1000 px sheets, 64 px targets, landscape fullscreen manifest. Phone
needs: responsive viewport, bottom tab bar, stacked home, agenda/person-filtered calendar, stacked
or picker chores, input-first shopping, 2-col control tiles, full-screen sheets, no
ambient/night/idle/takeover on phones, click instead of pointerdown, `touch-action` care for drags.

## 6. Android WebView 106 rules
- Vite JS target chrome106; **CSS target chrome61 on purpose**: the WebView rejects 4/8-digit hex
  colours. The Rails pipeline must not minify to `#rrggbbaa`.
- No CSS nesting, `color-mix()`, `oklch()`, `dvh`, `inset`. Uses `:has()` once, `translate:`,
  `content-visibility`, `aspect-ratio`, space-separated `rgb(var(--x) / a)`, variable Archivo `wdth`.
  Almost no transitions/animations (performance).
- **Tailwind v4 is out** (oklch, color-mix, @property). Plain CSS (port as-is) or Tailwind v3.
- JS is ES5-style IIFEs; Turbo 8, Stimulus, importmaps are fine on 106; avoid ES2023+ (`toSorted`,
  RegExp `v`).
