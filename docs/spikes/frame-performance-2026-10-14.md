# Milestone 1 spike: can the frame run full Hotwire? (2026-10-14)

**Verdict: the "full Hotwire, server-rendered, Turbo Stream patches" gate PASSES, with two rules
attached: patch granularly and never patch on a fast clock (no per-second streams; no bursts).**
Tab switches are identical to Wes's prototype, a hero-sized Turbo Stream replace lands in
~120-140 ms, a hidden full-view replace in ~170-300 ms, memory is flat (~3.5 MB/h), and the page ran
70 minutes with 4,521 stream patches and zero JS errors. The one hard limit found: *any* DOM patch,
even a 2-node text replace, costs one long frame (~60-100 ms) on this device, so the frequency of
patches matters more than their size.

## Setup

| Item | Value |
| --- | --- |
| Frame | AiMOR PF1007L, Android 6.0.1, Android System WebView 106.0.5249.126, 1280×800 DPR 1 |
| Transport | USB, `adb reverse tcp:4173` (prototype) and `adb reverse tcp:3000` (spike); the kiosk app `com.wesbos.homehq`, launched with a VIEW intent (saved URL untouched, remote debugging off) |
| Baseline | Wes's prototype, `vite preview` on 4173, opened with `?diag` (his overlay: fps, jank, DOM, heap, per-switch js/layout/paint/total) |
| Spike app | Throwaway Rails 8.1.4 (Ruby 3.4.5), Propshaft + importmap + Turbo 8 (turbo-rails 2.0.23) + Stimulus 3, Action Cable `async` adapter, development mode, Puma on 3000. Code lives in the session scratchpad (`scratchpad/spike/`), not in this repo |
| Spike page | One page: Wes's real rendered DOM captured from the prototype with headless Chromium (`--dump-dom --virtual-time-budget=12000`, after his prebuild) and split into 7 ERB partials (`home`, `calendar`, `tasks`, `shopping`, `photos`, `control`, `agents`; agents kept for DOM parity). Wes's CSS copied verbatim (`tokens.css`, `base.css`, `views/*.css`, Propshaft, no minification). Fonts self-hosted (Google Fonts CSS fetched with a Chrome UA, 7 woff2 files served from `/public/fonts`) |
| DOM weight | Prototype 1772-1785 elements (with overlay) vs spike 1798-1816 (Turbo adds `turbo-cable-stream-source`, templates, the overlay) |
| Tabs | Stimulus `tabs` controller: `pointerdown` on `[data-go]` toggles `is-active` on the `.view` and rail button (Wes's `App.go` minus the rebuild). Boot warm = his `prebuild`: `is-warming` + `offsetHeight` per hidden view, 400 ms apart |
| Streams | `turbo_stream_from "house"` (Turbo::StreamsChannel over Action Cable). A server thread broadcasts on a schedule set by `/sched?clock=&hero=&large=&large_view=`: `replace` of `#railClock` (2 nodes, 190 B), `replace` of `#hero` (12 nodes, 879 B), `update` of `#view-calendar` (172 nodes, 10.5 KB) or `#view-shopping` (442 nodes, 26.6 KB). Rendered content carries a timestamp so every patch really changes text |
| Instrumentation | `diag.js` mirrors Wes's: rAF frame sampler (fps, jank = frames > 50 ms), DOM count, `performance.memory`, tab switch = js / forced layout / double-rAF paint / total. Turbo patches: wrap `event.detail.render` on `turbo:before-stream-render` and time js (DOM patch) / forced layout / re-warm (hidden views only) / double-rAF paint / total. Every 5 s the page POSTs everything to `/metrics` (JSONL on the laptop); an on-screen overlay like Wes's for screenshots |
| Driving | `adb shell input tap 38 Y` on the rail (Y = 116 calendar, 188 chores, 260 shopping, 332 photos, 404 home-control, 44 today), 2.5 s apart, screenshots via `screencap` |
| Memory | `dumpsys meminfo com.wesbos.homehq` TOTAL PSS every 2 min (normal run) / 1 min (burst), joined with the page's heap and DOM count |

Raw data (scratchpad, not committed): `spike/log/metrics.jsonl` (836 reports), `spike/log/broadcasts.jsonl`,
`mem-normal.csv`, `mem-burst.csv`, `phases.log`, screenshots in `shots/`.

Server side for reference: rendering + broadcasting a clock patch took 1.3 ms median, hero 1.1 ms,
calendar 1.5 ms, shopping 2.4 ms (dev mode, laptop). The frame is the bottleneck, not Rails.

## Baseline: Wes's prototype on the frame

Per-switch timings read off his overlay over 4 tap cycles (ms; js / layout / paint / TOTAL):

| View | c1 | c2 | c3 | c4 | TOTAL median | TOTAL max |
| --- | --- | --- | --- | --- | --- | --- |
| home | 8/35/132/175 | 11/17/130/158 | 7/32/108/150 | 8/18/134/160 | **159** | 175 |
| calendar | 7/13/90/113 | 6/14/120/141 | 9/14/116/140 | 10/12/110/132 | **136** | 141 |
| tasks | 15/20/132/167 | 10/23/132/167 | 8/22/155/185 | 5/26/96/127 | **167** | 185 |
| shopping | 8/16/149/174 | 6/29/158/194 | 8/16/149/174 | 9/16/166/192 | **183** | 194 |
| photos | 7/13/84/104 | 11/14/83/109 | 8/17/79/104 | 13/12/67/92 | **104** | 109 |
| control | 12/19/108/139 | 17/14/125/156 | 10/11/130/152 | 19/10/105/133 | **146** | 156 |

- JS is 5-19 ms; the cost is paint (raster of the stage layer): 70-165 ms per switch. The 350-500 ms
  rebuild never showed up because his prebuild keeps hidden views laid out; one idle-machine
  `go('home')` with a rebuild showed 218 ms (paint 214).
- Idle on the home view with the overlay: fps 55, jank ~63/min (27 → 117 in 85 s). In ambient mode:
  fps 50-54, ~55-85 jank/min. Much of this is the overlay itself rewriting its innerHTML twice a
  second (see below).
- DOM 1772-1785, JS heap 10 MB, TOTAL PSS 100.6-101.3 MB idle (91.6 MB right after a fresh load;
  118.5 MB was the reading of the kiosk as found at the start of the session).

## Hotwire spike on the frame

### Boot

Page load + import map + Turbo + Stimulus: cable connected within the first 5 s report, no JS
errors in logcat or `window.onerror` for the whole run. Import maps resolve natively (logcat shows
`modulator_impl_base` mapping each pin); no shim needed. Boot warm (first layout of each hidden
view, the price Wes's prebuild pays once): calendar 219 ms, tasks 304, shopping 211, photos 47,
control 218, agents 221.

### Tab switch (TOTAL ms, median / max over n taps)

| View | Wes median | Streams off (n=4) | Normal schedule, first drive (n=5-6) | Normal, later drives (n=2 each) | Burst calendar (n=2) | Burst shopping (n=2) |
| --- | --- | --- | --- | --- | --- | --- |
| home | 159 | 147 / 157 | 149 / 157 | 158 / 167 | 153 / 166 | 177 / 184 |
| calendar | 136 | 135 / 158 | 117 / 193 | 160 / 163 | 176 / 178 | 176 / 178 |
| tasks | 167 | 170 / 192 | 176 / 192 | 157 / 167 | 246 / 247 | 154 / 154 |
| shopping | 183 | 169 / 181 | 167 / 180 | 146 / 146 | 179 / 190 | 213 / 262 |
| photos | 104 | 101 / 136 | 102 / 126 | 101 / 119 | 103 / 111 | 123 / 143 |
| control | 146 | 152 / 155 | 146 / 218 | 138 / 158 | 164 / 195 | 267 / 392 |

js is 1-2 ms (class toggles), layout 11-26 ms, paint 85-150 ms: the same shape and the same numbers
as the prototype (within noise, well inside ±20%). Streams at the normal schedule do not move the
medians; the maxes rise only when a tap lands in the same frame as a patch. Bursts (a large patch
every 2 s) push some switches to 250-400 ms. Nothing reaches 120 ms except photos (30 nodes), on
either stack: the floor on this device is the stage raster, not the framework.

### Turbo Stream patch cost (ms; js = DOM patch, layout = forced, warm = re-layout of a hidden view, paint = to the next painted frame)

| Phase | Target (nodes) | n | js | layout | warm | paint | TOTAL median | p90 | max |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Normal 1 s/10 s/60 s, overlay on, taps | clock (2) | 228 | 2 | 11 | 0 | 73 | **86** | 162 | 389 |
| | hero (12) | 22 | 3 | 26 | 0 | 81 | **119** | 241 | 306 |
| | calendar hidden (172) | 2 | 13-21 | 3-16 | 89-96 | 79 | **198** | | |
| | calendar visible (172) | 1 | 14 | 110 | 0 | 153 | **277** | | |
| Same, overlay hidden, no taps | clock | 199 | 3 | 12 | 0 | 82 | **94** | 146 | 432 |
| | hero | 20 | 3 | 29 | 0 | 107 | **139** | 206 | 312 |
| | calendar hidden | 3 | 12 | 3 | 108 | 76 | **178** | 280 | 280 |
| Same + `will-change: transform` on clock and hero | clock | 194 | 3 | 13 | 0 | 59 | **75** | 166 | 386 |
| | hero | 20 | 3 | 26 | 0 | 97 | **125** | 215 | 242 |
| Normal, 10 min window with 3 tap drives | clock | 579 | 3 | 14 | 0 | 74 | **98** | 180 | 568 |
| | hero | 58 | 3 | 27 | 0 | 97 | **131** | 270 | 496 |
| | calendar hidden | 10 | 13 | 3 | 100 | 64 | **182** | 464 | 464 |
| Burst: calendar every 2 s (+ clock 1 s, hero 10 s) | calendar hidden (172) | 131 | 13 | 4 | 92 | 61 | **172** | 339 | 493 |
| | calendar visible | 6 | 13-16 | 87-137 | 0 | 57-323 | 160-451 | | |
| | hero | 27 | 3 | 24 | 0 | 227 | **268** | 376 | 430 |
| | clock | 278 | 4 | 24 | 0 | 114 | **153** | 354 | 566 |
| Burst: shopping every 2 s | shopping hidden (442) | 142 | 29 | 4 | 180 | 78 | **296** | 388 | 534 |
| | shopping visible | 5 | 28-41 | 183-258 | 0 | 113-241 | 329-534 | | |
| | hero | 30 | 4 | 25 | 0 | 366 | **409** | 480 | 558 |
| | clock | 299 | 5 | 24 | 0 | 97 | **125** | 466 | 616 |
| Realistic: clock 60 s, hero 10 s, calendar 60 s, overlay hidden, idle | hero | 18 | 6 | 29 | 0 | 138 | **175** | 232 | 278 |
| | calendar hidden | 3 | 16 | 3 | 104 | 80 | **198** | 251 | 251 |
| | clock (same second as the calendar patch) | 3 | 4 | 24 | 0 | 349 | 375 | | 436 |

Reading it:

- **The floor is ~60-90 ms per patch, whatever its size.** The 2-node clock replace costs 75-95 ms
  end to end (js 3 ms); the hero (12 nodes) 120-140 ms. The time is in paint/raster of the stage,
  the same cost that makes a tab switch 100-180 ms. `will-change: transform` on the patched element
  (own compositing layer) shaves ~20% (clock 94 → 75, hero 139 → 125, jank 34 → 18/min). It is the
  frequency of patches, not their byte size, that the frame cares about.
- **Hidden-view replaces are cheap to apply (js 13-30 ms) but the subtree loses its cached layout**
  under `content-visibility: hidden`. Re-warming right after the patch (the spike does this in the
  render hook) costs 90-110 ms for the calendar and 180-250 ms for shopping, plus a ~60-80 ms
  repaint, off the interaction path. Without the re-warm the next tap on that view would pay it
  instead (Wes's 350-500 ms rebuild territory). Visible full-view replaces cost 280-530 ms: avoid.
- **Bursts cascade.** With a large patch every 2 s the hero patch tripled (268-409 ms), clock patches
  doubled, fps fell to 42-45 (min 30) and switches hit 250-400 ms. The page stayed correct (no
  errors, no missed patches, screenshots after the burst match the expected state) but it is
  visibly sluggish. A large patch every 60 s was invisible in the numbers.
- **Idle at the realistic schedule** (clock per minute, hero every 10 s, calendar per minute, overlay
  hidden): fps 57.6 median (min 46.7), jank 15/min, all of it the hero's 10 s patch. With a 1 s
  clock patch and the overlay on: fps 49-52, jank 108-125/min (about one long frame per patch plus
  the overlay's own two innerHTML rewrites per second; Wes's prototype with the same overlay idles
  at ~63/min). Nothing animates on the page, so these long frames are not visible as such; they
  only matter when they coincide with a tap.

### Memory over time

Normal schedule (clock 1 s, hero 10 s, calendar 60 s), 3 tap drives during the run:

| Time | PSS (MB) | JS heap (MB) | DOM | Notes |
| --- | --- | --- | --- | --- |
| 13:45:48 | 97.8 | 10 | 1811 | 3 min after load, streams start |
| 13:51:51 | 99.5 | 10 | 1815 | |
| 13:57:54 | 99.6 | 10 | 1814 | |
| 14:03:56 | 101.5 | 10 | 1813 | |
| 14:09:59 | 102.0 | 10 | 1813 | |
| 14:16:02 | 101.9 | 10 | 1813 | |
| 14:22:05 | 102.8 | 10 | 1813 | |
| 14:28:08 | 102.5 | 10 | 1813 | |
| 14:34:11 | 103.0 | 10 | 1813 | 2,000+ patches so far |

Burst (large every 2 s, 10 min): 102.9 → 107.4-107.8 MB (plateaus after 2 min), heap 10, DOM 1813.
Realistic schedule after the burst: 105.4 MB. Final: 70 min uptime, 4,521 patches received.

Trend: **+3.5 MB/h** at the normal schedule (100.3 at 13:47 → 103.0 at 14:34), heap and DOM flat.
The burst adds a one-off ~5 MB that does not keep growing. The prototype idles at 100.6-101.3 MB, so
the spike sits within 1-7 MB of it. At this rate a nightly reload is a formality: 24 h would be
~+85 MB on a 1 GB device, under the 20 MB/h criterion.

### Correctness and surprises

- **Rails 8.1's default `allow_browser versions: :modern` returns 406 to WebView 106.** The first
  launch on the frame showed "Your browser is not supported". Must be removed (or given explicit
  versions) in Home HQ's `ApplicationController`.
- **The frame's clock is wrong** (it reported `Date.now()` ≈ 14,000,000 ms, i.e. January 1970; the
  prototype showed "Thursday January 1"). Any client-side timestamps are useless; the spike used
  server time for everything. This also means TLS certificate validity checks can fail on the frame
  until it gets NTP time (relevant to the HTTPS work).
- **Action Cable over `adb reverse` was solid:** connected within seconds, one ~5-10 s disconnect at
  13:50:56 (cause unknown; nothing was done to the frame at that moment) after which Turbo's cable
  source reconnected on its own and patches resumed. 4,550 broadcasts sent vs 4,521 received: the
  ~26 missing fall in the disconnect and before the first subscription. Patches arriving while
  disconnected are simply lost (Turbo Streams have no replay), so anything that matters must also be
  recoverable by a refresh/full render on reconnect.
- **Turbo's `nextRepaint()` before each stream render** adds a frame of latency (the `wait` column:
  3-6 ms when the frame is idle, 30-36 ms for large patches queued behind others). Fine.
- **Import maps, Turbo 8 and Stimulus 3 run as-is on WebView 106**; no polyfills, no build.
- **The diag overlay costs more than the clock patch**: its 500 ms innerHTML rewrite is itself two
  DOM patches per second. Keep the beacon (POST metrics to the server; it was the only way to read
  numbers off the frame) and drop the on-screen panel in production.
- **Fonts:** self-hosted copies of Archivo/Instrument Serif rendered slightly wider than the
  prototype's Google-served ones (the `wdth` axis may differ in the fetched files). Layout numbers
  are unaffected (same DOM, same CSS); it is a cosmetic thing to get right in M1 by downloading the
  variable fonts properly.
- **Images:** `picsum.photos` fails on the frame on both stacks (Let's Encrypt chain), so the photo
  card is a broken image in both. Same as the prototype's `imgs 0`.

## Pass criteria

| Criterion | Result | Verdict |
| --- | --- | --- |
| Tab switch ≤ Wes's on the same frame (±20%), ideally ≤ 120 ms | Identical to Wes (101-176 ms medians vs his 104-183); nobody gets ≤ 120 ms except photos, the raster floor is ~100-150 ms | **Pass** (parity) |
| Hero-sized replace ≤ 150 ms, no dropped-frame cascade | 119-139 ms median (125 with `will-change`); one long frame per patch, no cascade unless patches burst | **Pass** |
| Full-view replace ≤ 500 ms, only while hidden or rarely | Hidden: 172-198 ms (calendar), 296 ms (shopping, 442 nodes) incl. re-warm; visible: 280-530 ms | **Pass** (hidden only) |
| fps steady during 1 s clock patches | 49-52 fps, ~1 long frame per patch; at a 60 s clock: 57-58 fps, 15 jank/min | **Pass with a rule**: do not stream every second |
| Memory flat or ≤ 20 MB/h | +3.5 MB/h, heap/DOM flat, bursts plateau | **Pass** |
| Stability | 70 min, 4,521 patches, 0 JS errors, auto-reconnect worked | **Pass** |

**Gate: PASSES.** Full Hotwire (server-rendered views kept warm in one page, Stimulus tab switch,
Turbo Streams over Action Cable) runs as well as Wes's client-side prototype on this frame. No
fallback to client-side rendering is needed. The failure mode that exists is self-inflicted
patch frequency, not the stack.

## Recommendations for Milestone 1

1. **Remove `allow_browser` from `ApplicationController`** (or `allow_browser versions: { chrome: 106 }`
   plus a system test with the WebView UA) and add it to the `bin/ci` WebView-106 check.
2. **Patch granularly, at the smallest stable id.** One target per changed thing: the clock `<b>`,
   a single hero card, a single calendar event/chore row/shopping item, the three home-status
   lines. Each patch costs ~80 ms regardless of size, so coalesce: one Turbo Stream message carrying
   several `<turbo-stream>` elements per server tick rather than several messages.
3. **No per-second streams.** The rail clock and countdowns ("27 min", "Leave in 15 min") should be
   Stimulus controllers ticking locally from a `data-deadline`/server-time attribute; the server
   only pushes when the underlying event changes. A per-minute clock stream is fine if preferred.
4. **Whole-view replaces only while the view is hidden**, and re-warm the view right after
   (`is-warming` + `offsetHeight` in a `turbo:before-stream-render` hook / Stimulus callback). Cost
   is ~170-300 ms off the interaction path. If the target view is visible, prefer row-level patches,
   or defer the full replace until the view is hidden (keep a "dirty" flag, like Wes does).
5. **Rate-limit broadcasts server-side**: debounce per target (e.g. coalesce HA state changes for
   250 ms), and cap large replaces to about one per 10 s. Never let a data refresh fan out into
   dozens of patches at once; during the 2 s burst the hero patch went from 125 to 400 ms and the
   screen felt sluggish.
6. **Give the hottest targets their own layer**: `will-change: transform` on `.rail-clock` and the
   hero card (and probably the home-status card) is a free ~20%. Do not spray it everywhere
   (memory on a 1 GB device).
7. **Keep the boot warm** (one hidden view every ~400 ms after load) and keep `content-visibility:
   hidden` as the hide mechanism; this is what keeps switches at ~150 ms instead of 350-500.
8. **Server time everywhere.** The frame's clock is at epoch; render times and "updated at" on the
   server, send `data-server-now` so Stimulus timers can offset.
9. **Reconnect = refresh.** Turbo Streams do not replay. On `turbo-cable-stream-source` reconnect
   (or every N minutes), request a full re-render of the current view's data (a Turbo Frame
   reload or a `fetch` + `update`) so a patch lost during a disconnect cannot leave stale data.
10. **Ship the metrics beacon, not the overlay.** Keep a `?diag` overlay for the frame but off by
    default; keep the 5 s POST to a metrics endpoint (a JSONL/Solid table) so frame performance is
    observable without DevTools.
11. **Nightly reload stays** (the plan already has it); memory does not require it but it is cheap.
12. **System tests** (Capybara + headless Chrome) cannot reproduce these timings (the laptop is
    ~20× faster); use them for behaviour and keep the real-frame check per milestone, driven the
    way this spike did it (`adb reverse`, VIEW intent, `input tap`, the beacon).

## Not measured / caveats

- Development-mode Rails on a laptop over USB; production (Solid Cable, Kamal, HTTPS over Wi-Fi)
  adds network latency but no client-side cost. WebSocket over `adb reverse` behaved like a LAN.
- Turbo Drive navigations (none happen in this design), Stimulus-heavy interactions (sheets, hold,
  dimmer drag, swipe), Solid Cable's polling cadence, and HTTPS/cert behaviour were out of scope.
- The spike's agents view and Wes's demo data were kept for DOM parity; the real app will have a
  People view instead and real data of similar weight.
- Screenshots are in the session scratchpad (`shots/`), not committed.
