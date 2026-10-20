# Home HQ: build plan

Status: **Every milestone built and deployed (2026-10-19); what remains is in `private/next.md`, kept out of the repository.** Last updated 2026-10-19.
The code was developed in a private repository and published here as one first commit; PR numbers
(#1–#37) in these notes refer to that history.
Companion: `ui-spec.md` (every behavior of Wes's UI that must be kept).

## Goal

Wes Bos's Home HQ dashboard, identical look and behavior, made real:
- the wall frame (PF1007L, Android 6, WebView 106, 1280×800) shows it full screen;
- phones get the same app in a small-screen layout, from anywhere;
- chores, stars, shopping, favourites and events persist and sync live between all screens;
- calendars, weather, travel times, presence, smart home, cameras, alerts and photos are real;
- when the server or internet is down, screens show the last data with a "stale" notice;
- $0 running cost (one-time $5 Google Device Access fee for Nest cameras accepted).

## Working agreement (how this gets built)
- **Red, green, refactor for every behavior:** write a failing test first; run it and confirm it
  fails **for the expected reason**; make it pass in the thinnest way; then refactor without
  changing behavior (tests stay green).
- **Rails conventions whenever possible**, including the Active suite (Record, Job, Storage,
  Model, Support, Record Encryption...), Action Cable/Mailer, the Solid suite and Hotwire (Turbo +
  Stimulus), including for Wes's UI (unless the frame performance gate forces the fallback).
- **Commit after each green and after each refactor.** No Claude attribution in commits, ever.
- **Alert the owner about any meaningful deviation from this plan** before taking it.
- **Keep going until the plan is complete; verify along the way and at the end** (tests, `bin/ci`,
  and checks on the real frame and a phone at each milestone).
- **Hotwire all the way, gated on frame performance:** Rails renders every view (ERB partials
  ported from Wes's templates) into one page kept warm; tabs switch with Stimulus (no page loads);
  live updates arrive as Turbo Streams; every interaction (hold, dimmer drag, swipe, sheets, toasts,
  idle machine, slideshow, clocks/countdowns) is a Stimulus controller. **Milestone 1 starts with a
  performance spike on the real frame** (tab switch, Turbo Stream patch, memory over hours) against
  Wes's numbers. If the frame can't keep up, fall back to Wes's client-side rendering with his
  interactions rewritten as Stimulus controllers, and tell the owner.
- **UI tests:** Rails system tests (Capybara + headless Chrome) written from `ui-spec.md`, failing
  before each piece is ported; a `bin/ci` check that rejects CSS/JS WebView 106 can't run (8-digit
  hex, `oklch`, `color-mix`, nesting, ES2023+); a manual check on the real frame each milestone.
- **Git:** a branch and a PR per milestone (owner reviews and merges); commits use the owner's
  normal git identity; **never any Claude/AI attribution**. Pushes run local CI (`~/Work/ci-template`
  pre-push `bin/ci`, `gh signoff`).
- **When something needs the owner** (credentials, server/home access, physical frame steps, mockup
  approval, a meaningful deviation): **pause and ask in the session**, and meanwhile continue other
  work that doesn't depend on the answer (in parallel with subagents where feasible).
- **Conventions:** the CLAUDE.md that rails-now generates (delegated types, concerns, entities not
  values, tokenized shares, read through `Current.household`, defer until needed) plus the home
  `CLAUDE.md` rules. Active Storage → **Cloudflare R2** (S3-compatible) so uploads are backed up
  with the app data (rails-now's default is Hetzner Object Storage; R2 is free at this size).

## Architecture (decided 2026-10-14: web-hosted Rails, home bridge)

```
 phones (anywhere) ──https──┐
 wall frame (home Wi-Fi) ──https──┤
                                  v
              Rails 8 app on a VPS (Kamal; our 8 GB Hetzner box in Germany)
              SQLite, Solid Queue/Cache/Cable, Litestream backups
                                  │ Tailscale (private tailnet, no open router ports)
                                  v
              home server (Docker): Home Assistant + Immich + Tailscale
              HA <── Hue, Kasa/Tapo, WiZ, Matter, Nest, Ring, Ecobee, locks...
              Immich <── phones' camera-roll backup
```

- **Rails is a normal public HTTPS web app.** Frame and phones use the same URL; the service worker
  (offline mode) works because the site is HTTPS.
- **The home server only runs the things that must be at home:** Home Assistant (local device
  control) and Immich (the photo library). The Rails server reaches them over **Tailscale**;
  nothing at home is reachable from the internet.
- HA → Rails events (doorbell, state changes) go over HA's outbound webhooks/WebSocket client to
  Rails, or Rails holds a WebSocket subscription to HA over Tailscale.
- If the home internet drops: phones keep working (except device control and new photos); the
  frame shows its last data with the stale notice; devices still work from Google/Apple Home.

### Rails app
- **Rails 8, SQLite**, Solid Queue (jobs + recurring schedules), Solid Cable (WebSockets), Solid
  Cache. Propshaft + importmap; no Node build in production.
- **Front end: Hotwire, Wes's look kept exactly** (decided; see Working agreement). His CSS is
  ported as plain CSS; his view templates become ERB partials rendered into one page with all views
  kept warm (no page loads between tabs); Stimulus controllers replace his interaction code; Turbo
  Streams over Action Cable (`HouseChannel`) patch only what changed. Writes go through normal
  Rails controllers (Turbo-friendly). **Gate:** a performance spike on the real frame at the start
  of milestone 1; fallback = his client-side rendering + Stimulus behaviors.
- **WebView 106 rules** from `ui-spec.md` §6 apply to every asset: no Tailwind v4, no CSS nesting,
  no 8-digit hex, no ES2023+.
- **Admin / settings pages** (plain Rails + Hotwire, phone-friendly): people, colours, calendar →
  person mapping, chores and routines, stores and aisle order, catalogue and usuals, device and room
  mapping, scenes, cameras.

### Small screens (phones)
Same app, same JS, a responsive layer added (Wes's CSS has no media queries):
- `<= 700px` wide: bottom tab bar instead of the rail; Today stacked (clock + weather, hero,
  per-person agenda, chores rings, shopping, home status); Calendar defaults to agenda / one-person
  day with a person filter, month view kept; Chores as stacked lanes with a person picker; Shopping
  input-first; Control as 2-column tiles with climate/cameras stacked; sheets full-screen.
- Frame-only behaviors off on phones: ambient, night, idle auto-return, takeovers (phones get push
  notifications instead), demo drawer.
- `click` instead of `pointerdown` navigation on phones; `touch-action` set so dimmer/slider drags
  don't fight scrolling.
- Installable as a PWA (home-screen icon, Web Push for "directions to phone" and alerts).

### Persistence (SQLite)
| Model | Notes |
|---|---|
| Person | name, colours, kid?, nicknames, avatar, Identity (email, adults), PIN (adults), phone push subscription, HA person entity |
| Screen | name, device session, night mode + hours, default view, brightness, reload time |
| Calendar, Event | synced events + locally created ones; people via join table; travel cache |
| Routine, Chore, ChoreCompletion | completions per day → daily reset is automatic; "This week" strip derived |
| StarEntry | ledger (+/-), totals summed; undo = delete entry |
| Store, Category order, CatalogItem, GroceryItem | qty, done_at; usuals derived from frequency |
| Room, Device, Scene | mapping to HA entity ids; state cached from HA |
| Camera | HA entity, snapshot cache |
| Photo (index only) | Immich asset id, taken_at, place, orientation, album/tag, fav |
| Todo | person or Anyone, title, due, stars (kids), done_at, created_by |
| Setting | home address, units, weather location, frame options |

Writes follow Wes's optimistic contract: UI updates instantly with a pending state → server
confirms (broadcast to all screens) or fails → revert + error toast.

### Offline and stale data
- **Service worker** (supported on WebView 106 and phones) caches the app shell, fonts and icons, so
  the frame can boot even if the server is down.
- The service worker keeps the **last rendered page** (and its data timestamp); on load failure or
  a dropped Action Cable connection the app shows that page with a banner **"Offline · showing data
  from 9:42 AM"**, and retries with backoff.
- Writes while offline: blocked with a toast ("Can't save while offline") in v1; an outbox queue
  can come later.
- Each data source also carries its own `fetched_at` so a stale calendar or weather feed is flagged
  even when the server itself is up.

## Integrations (all free unless noted)

| Feature | Source | How | Cost |
|---|---|---|---|
| Calendars | read-only ICS/webcal feeds via `CalendarSource` (Google secret iCal address, HEY, Outlook, school) | recurring job every 5 min; people rules; RRULE expansion; no writes for now | free |
| Travel time, "Leave by" | **Home Assistant Waze Travel Time** (traffic-aware) | throttled refresh for today's upcoming events with a location; cached per event | free |
| "Send directions to phone" | v1: QR code on the frame; later: Web Push to the person's phone | scan or notification opens Apple/Google Maps with the address | free |
| Presence, ETA | Home Assistant Companion app on each phone → HA `person` + zones | Rails subscribes to HA; ETA = HA Waze travel time from the phone's location when away | free |
| Weather | **Home Assistant weather entity** (e.g. its Open-Meteo/Met.no integration) | refresh every 30 min; map conditions → sun/moon/partly/cloud/rain | free |
| Lights, plugs, scenes | Home Assistant: Hue (local), Kasa/Tapo (local), WiZ (local), Matter, GE Cync | Rails ↔ HA WebSocket API (state subscription + service calls) | free |
| Locks, Ecobee thermostat | HA (lock integration per brand; Ecobee integration or HomeKit/Matter) | garage/blind/leak features hidden until mapped | free |
| Media "Now playing" | HA media players (Apple TV, Chromecast/Nest, Echo/Spotify) | play/pause via HA | free |
| Nest cameras | HA Nest integration via Google Device Access | snapshots every 20 s, live view on tap | **$5 one-time** |
| Ring doorbell | HA Ring integration | doorbell press → takeover; snapshots | free |
| Alerts | HA automations → webhook → Rails → ActionCable (frame takeover/banner) + Web Push (phones) | doorbell, garage-open timer, package (camera events), leak if a sensor exists | free |
| Photos | **Immich** on the home server; phones' Immich app backs up camera rolls (Apple + Google) | Rails reads Immich API: albums, "memories" (on this day), thumbnails; favourites sync | free |
| Other found devices | Rachio, Ting, Bosch Home Connect, Synology | available in HA for later tiles | free |

**Photos note:** Google Photos' Library API (since March 2025) only sees photos the app itself
uploaded, and Apple Photos has no web API, so neither can feed "on this day" directly. Options:
1. **Immich** (recommended): self-hosted Google-Photos-style app; its iOS/Android app backs up each
   phone's library in the background; has a real API and built-in "memories". Storage can live on
   the Synology NAS.
2. iCloud **shared album with "Public Website" on**: unofficial feed of one album, no "on this day"
   across years.
3. `icloudpd` syncing the iCloud library to the server: works, but needs Apple ID 2FA re-auth
   every ~2 months.

## Hosting and access
- **Rails: at home, behind a Cloudflare Tunnel (decided 2026-10-16).** The always-on box runs the
  app (Kamal, kamal-proxy on plain HTTP), Home Assistant and later Immich; a `cloudflared`
  accessory gives the family the public hostname over HTTPS with no VPN and no open ports.
  Reasons: one machine; the app and the hub on the same box (no Tailscale link); the VPS was
  tight on memory and the camera work should stay home; a home outage takes the frame down
  anyway. The app is one image plus one replicated volume, so it moves between machines in an
  hour (`bin/restore-db`, README "Moving to another machine"). Interim host while the home box is
  set up: the owner's laptop. The VPS config stays valid as a fallback destination
  (`HOME_DASHBOARD_TLS=true`, root over SSH). Until 2026-10-16 the app ran on the 8 GB Hetzner box.
- **Logins:** rails-now magic-link auth (decided; passkeys deferred). Each screen signs in once as a named
  **screen device** with a long-lived session (no LAN allow-lists or IP trust).
- **Frame:** points the kiosk at the public URL; needs the ISRG Root X1 certificate added once (we
  have root) since Android 6 lacks it. No kiosk code change.
- **Home bridge:** the same box runs Home Assistant (`ops/home-assistant/compose.yml`, host
  network) and later Immich; the app reaches them on the LAN. Tailscale only for admin SSH.
- **Backups:** Litestream streams SQLite (and app uploads) to Cloudflare R2 (free 10 GB). Photo
  library not backed up.
- GitHub: private for now, **open source later** (see "Open-source readiness").

## Milestones
Each ends with something visible on the frame and a phone.

**Status (2026-10-17): every milestone's software is built, merged and deployed** (0–8, plus the
per-screen settings, members-only sign-in, the audit log and the grocery edit from the reviews).
Production runs on the owner's laptop behind a Cloudflare Tunnel until the home box is ready
(Hosting and access). What remains is the owner's: ISRG Root X2 on the frame and its saved URL and
boot fixes; Home Assistant on the home box with Nest, Ring and the Ecobee and its token in the
credentials; Immich on the box and its key; the household's routines, chores, to-dos, calendar
feeds and PINs entered in Settings; the move to the box. Milestones 5–7 light up as each of those
lands; nothing in the app changes.

0. **Foundations:** private GitHub repo, Kamal deploy of an empty Rails app to the VPS with the
   dashboard hostname and HTTPS, Rails authentication + screen devices, ISRG root on the frame,
   Litestream → R2, Telegram alerts.
1. **Wes's UI on Rails, mock data:** frame performance spike first, then views ported to ERB +
   Stimulus with his sample data as seeds, real
   clock (no forced 15:18); frame points at the public URL; parity check against the prototype on the
   frame. Service worker + stale banner.
2. **Phone layout:** clickable mockups approved first, then the responsive layer, bottom tabs,
   Add to Home Screen, logins.
3. **Real household data:** people, chores/routines/stars ledger with daily reset, shopping
   (stores, aisle order, catalogue, usuals), all writes + live sync via ActionCable, admin pages.
4. **Calendars + weather + travel:** read-only ICS feeds, people rules + override, travel times and
   leave-by and weather from Home Assistant, directions QR code.
5. **Home bridge + Home Assistant:** Docker on the home server, Tailscale to the Rails server; install HA, adopt devices (Hue, Kasa/Tapo, WiZ, Matter shares from
   Google/Apple Home, Nest, Ring), map rooms/devices/scenes, climate, media, presence.
6. **Cameras + alerts:** Nest ($5) and Ring snapshots, doorbell takeover, garage/package banners,
   phone push, auto-relock.
7. **Photos:** Immich + phone backup, slideshow, on-this-day, favourites.
8. **People view** (kids' My day, adults' schedule + to-dos, `Todo` model) and polish; frame boot fixes (2 A charger, Wi-Fi defer, fixed MAC,
   clock) done whenever the frame moves to the wall.

## Decisions (2026-10-14)

### Simplifications (2026-10-14) - these override anything else in this file
1. **Home bridge over Tailscale** (not Cloudflare Tunnel/Access): the VPS joins the tailnet and
   reaches Home Assistant and Immich on the home server directly. No Zero Trust setup or tokens.
2. **Home Assistant is the hub** for everything at home **and** for weather (an HA weather entity)
   and **travel times (HA Waze Travel Time, free, traffic-aware)**: devices, presence (HA companion
   app), cameras, doorbell/alerts. No Mapbox, no weather API code in Rails. Travel refresh stays
   throttled (often only within ~2 h of leave-by).
3. **Calendars are read-only feeds (ICS)**: the shared Google calendar via its secret iCal address,
   HEY/Outlook/others the same way. **No adding, editing or deleting events from the frame or
   phones for now.** Wes's "+" Add sheet stays in the code but is **hidden**. The **"who's it for"
   override stays** (app-only metadata; the calendar item is untouched). No Google OAuth.
   The source/adapter design stays so write-capable sources can be added later.
4. **Passkeys deferred:** email-code login with year-long sessions; PIN for unlocking.
5. **No offline edits in v1:** phones show "Can't save while offline". (Offline *viewing* with the
   stale banner stays.)
6. **Four person lanes** for now (fits our family); variable family size before open-sourcing.
7. **Chore schedules: two types** - **daily** (in its routine) and **specific weekdays** (e.g.
   Mon/Wed). No "N times per week" or monthly. Weekend routines and the vacation pause stay.
8. **One kiosk change:** a small JavaScript bridge in the kiosk app (set brightness / screen off,
   PIN prompt for the Settings/Launcher menu); the logic lives in the web app.
9. **Milestones stay at nine** smaller steps (owner preferred more checkpoints over merging).

### Frame performance gate: passed (2026-10-14)
The milestone-1 spike ran full Hotwire on the real frame next to Wes's prototype
(`docs/spikes/frame-performance-2026-10-14.md`). Tab switches were identical (the ~100-150 ms
floor is the GPU raster, same on both stacks), a hero-sized Turbo Stream replace landed in
~125 ms, a hidden whole-view replace in ~170-300 ms, memory grew ~3.5 MB/h, and 70 minutes with
4,500 patches produced no errors. **Full Hotwire it is; the fallback is dropped.** Rules that
come with it: every DOM patch costs one ~80 ms frame regardless of size, so patch the smallest
stable id, coalesce patches per server tick, never stream on a fast clock (clocks and countdowns
tick locally in Stimulus from server time), replace whole views only while hidden and re-warm
them, debounce broadcasts server-side (about one large patch per 10 s at most), and refresh the
current view on cable reconnect because streams do not replay. The frame's clock sits at epoch
until it has network, so the server is the only source of time. Rails' default `allow_browser`
answers WebView 106 with 406 and must stay out (guarded by a test).

### Milestone 1: built (2026-10-14)
Wes's six views, the ambient/night/nightdash modes, the takeovers and banners, the demo drawer
and the `?diag` overlay are ported to ERB + Stimulus on his demo data as seeds, with the real
clock (server time + household zone, ticking locally). Chores, shopping, favourites, devices,
scenes, climate and media persist and answer with Turbo Streams. Side-by-side screenshots
against the Vite prototype (headless Chromium and the real frame over USB) match; the only
differences are intended (People in the Agents slot, no "+" button). What is **not** in it:

- **Live sync between screens** (`turbo_stream_from` broadcasts on writes, refresh on cable
  reconnect): milestone 3 with the real household data; today a write updates the screen that
  made it.
- **The Add-event sheet** is not ported (plan: Simplifications hides it; the button is there,
  hidden). It comes back with a writable calendar source.
- **People view** is the four avatars only; the person pages are milestone 8.
- **Sheets are fetched on tap** (one small request each) rather than pre-rendered; on the frame
  that is a ~150 ms open. Shopping suggestions are computed in the browser from the catalogue so
  typing never waits on the network.
- **Demo-only pieces kept as such:** the mock bridge finishes a garage move after 4 s; the
  doorbell "relocks in 2 min" and the water-main valve are copy only until Home Assistant.
- **Units:** the demo data is in °C like Wes's; °F and the thresholds become settings with the
  real data (Our instance).
- **Frame pointed at the public URL** is the owner's step (the kiosk's saved URL), after the
  deploy that follows the review; `db:seed` on the server gives the frame the demo data until
  milestone 3.

### Milestone 2: built (2026-10-15)
The approved phone mockups, as the same page with a responsive layer. **Who is signed in picks
the layout:** an enrolled screen is the frame (fixed 1280×800 stage, pointerdown taps, idle
machine, modes, demo drawer); a person gets the device-width app, where `dashboard/phone.css`
applies under 700 px and the frame-only behaviours stay off. The rail is a five-tab bar (Today,
Calendar, Chores, Shopping, Home); Photos opens from the Today tile and "Me" from the avatar.
Today stacks with one "Rest of today" agenda; Calendar gains Agenda mode, person chips and a
one-column Day; Chores gets person chips over stacked lanes; Shopping is input-first; Home
control is two columns; Photos and sheets are full screen; the login pages wear the same look;
the manifest installs as a standalone app (`?layout=frame` keeps the frame's fullscreen
landscape one). What is **not** in it:

- **To-dos on Me** and completing chores from Me: milestone 8 (the Me page shows the person's
  presence, what needs them next, the next seven days and their chores, read-only).
- **Linking a login to a person** (`people.user_id`) has no settings UI yet (milestone 3 admin
  pages); until then Me opens on the first person and the Today avatar is a generic one.
- **An "Add to Home Screen" prompt**: the manifest and iOS tags are there; installing is the
  phone's own Share → Add to Home Screen.
- **Push notifications** stay out of v1 (plan: Gap review answers).

### Milestone 3: built (2026-10-15)
**Live sync between screens.** A write names the dashboard pieces it changed (stable DOM ids,
collected for the request and broadcast once as a `pieces` stream action to the household); every
other screen fetches those pieces from `/pieces`, rendered for itself (its layout, its session,
its clock). The writer skips its own broadcast by a page token; a cable reconnect refreshes the
active view, since streams do not replay. Spike rules kept: smallest ids, coalesced, never the
page.

**Chore schedules.** Daily, or specific weekdays (a bitmask on chores and on routines, so a
weekend-only routine stays off weekdays); the vacation pause (`chores_paused_until`). "Overdue"
is computed, not stored: due today in a routine already over and not done, and such chores are
carried into the current routine's lanes first (they return to their own routine once done). The
week strip counts only what was due each day; a paused day, a rest day or no chores is "off", not
a miss.

**Units, clock and week** are household settings: °F gives 1° thermostat steps between 60 and 82 and
a 54 °F "cool" threshold; the 24-hour clock applies to every time on the server and in the browser;
the week starts on Monday or Sunday (month view, chores week strip). Changing the zone, units,
clock or week start broadcasts a `reload` to every screen, since the page bakes them in.

**Settings** (adults only, the plain-page look): the household (name, zone, units, clock, week, pause),
people (colour with automatic ink, kid, the login they use), routines (hours, label, days),
chores (routine, person or Anyone, stars, days), stores with per-store aisle order, categories
(the All order), the catalogue with usuals; every list reorders with up/down.

**Starting fresh** (`bin/rails household:fresh_start`) clears the demo people-bound data, keeps
logins and screens, and reseeds the generic catalogue; the real people, routines, chores and
stores are then entered in Settings. Home control, photos and weather keep their demo data until
milestones 5, 7 and 4.

The dashboard page loads the household's chores once per request (routines and today's completions
with them) and the home status from one load of the devices; a test holds the page under 130
queries (99 on the test data, from 367).

What is **not** in it: drag-and-drop ordering (up/down buttons instead), avatar uploads, and a
settings UI for presence (status lines are edited on the person until Home Assistant brings
presence in milestone 5). Decided in the review (2026-10-15):
- **Lane counts follow the people** (chores 5 columns, Today and People 4, Calendar 4 or 3 are
  fixed in CSS today; the plan's rule is 1 to ~8 people): milestone 8, with the People view.
- **Audit log** of settings changes, completions and unlocks (second gap review): milestone 5,
  when unlocks become real, so one log covers all three.
- **Per-screen settings** (night hours, default view, the 3 AM nightly reload; today night mode
  sticks on the frame until touched): a short follow-up branch **before milestone 4**.

Second review, after the fresh start on production (2026-10-16):
- The dashboard **raised on a household with no routines** (fixed: the Chores view has an empty
  state; a route sweep now renders every page for the frame, an adult and a kid right after a
  fresh start).
- The **demo tools** (drawer, time presets, fake alerts, the startup tip) are for a **demo household**
  only (`households.demo`, set by the seeds, cleared by a fresh start). A real household's frame has
  none of it to find.
- **Stars stay totals** for now: no manual adjustments or rewards until we know what stars are for.
- **Groceries: edit and delete one item** from the phone (name, note, store, category) is wanted;
  it waits for a small branch after milestone 4.
- Removing a person detaches their chores to Anyone and deletes their star history; the confirm
  stays as is for now.

### Per-screen settings: built (2026-10-15)
Each screen (`/screens`, adults only) has its own **night hours** (default 10 PM – 6 AM; the same
hour twice turns night off) and **night style**: the screen goes dark (the gap review's default; a
tap wakes it to the red-filtered dashboard, which returns to dark after 20 s idle) or shows Wes's
red clock; a **default view** it boots on and idles back to (the frame is a
kiosk with a fixed URL, so the hash no longer picks its view; the app still follows the hash), and
a **nightly reload hour** (default 3 AM, or never) that reloads the page onto the default view to
keep the old WebView healthy. Night now **ends with the hours** instead of sticking until touched,
and an idle ambient screen becomes night when they begin; the check runs on the minute. Changing a
screen's settings reloads that screen (its own stream, next to the household's). Not in it:
brightness, and a true backlight-off (no browser control; "screen off" is a black page, which is
what the frame's LCD shows anyway until the kiosk app learns to cut the backlight).

### Milestone 4: built (2026-10-16)
**Calendars** are `CalendarSource` rows (Settings → Calendars): an ICS/webcal address, the people it
is for (none = everyone), a refresh interval and an on/off switch, with "Sync now" and the last
status and error on the list. `CalendarSyncJob` runs every 5 minutes and syncs the sources that are
due, in each household's zone: the feed becomes `Event` rows for a window of 7 days back to 60
ahead, recurrence expanded (RRULE, EXDATE, moved occurrences), cancelled events dropped, all-day
events from midnight to an exclusive midnight end, floating times read in the household's zone,
timed events with no end lasting an hour; events gone from the feed go. **Who an event is for**
follows the decided rules: a manual override (the people chips on the event sheet are buttons:
tap to add or drop, Everyone, "Back to the calendar's"), else names in the title (whole word,
nicknames from the person's settings included, in the order written), else the calendar's people,
else everyone. The calendar view is a live-sync piece (fetched with its mode, date and person), so
every screen follows a sync or an override.

**Home Assistant** is a client (`HomeAssistant`), off until `home_assistant.url` / `.token` are in
the credentials (or `HOME_ASSISTANT_URL` / `_TOKEN`), so the app keeps running with no
integrations. **Weather** (`WeatherSyncJob`, every 30 minutes): the household's weather entity
(Settings → Integrations) gives today's report in the household's unit, hourly from now, the day's
high and low, conditions mapped to Wes's five; until then the demo weather stays. **Drive times**
(`TravelSyncJob`, every 10 minutes): Home Assistant's Waze service, from the home address to
today's upcoming synced events with a location, every ten minutes within two hours of leaving and
hourly otherwise; the leave-by, the hero's pill and the calendar's travel block follow.
**Directions**: the sheet's location row opens a QR code of an Apple Maps link (Google Maps on
Android) for a phone camera.

Not in it: the HA entities themselves (milestone 5 brings the hub), travel cached per destination
(it is per event today), push to a phone (the QR is v1), writing to calendars.

### Getting started, in order (2026-10-17)
Settings opens with a **Getting started** list in the order that works: People, Routines, Chores,
Calendars, Stores, PINs, Screen, each with its status and a link; it folds to one line once all
are done. The one hard dependency is codified: **a chore lives in a routine**, so Chores is blocked
in the list and the chore form redirects to Routines until one exists. The rest of the order is
advice, not enforcement.

### Milestone 8: built (2026-10-17); the frame's boot fixes wait for the wall
**The People view.** On the frame the big avatars are links into the "people" frame. A **kid's page
is "My day"**: a ring for the whole day and one per active routine, the stars earned today and in
total, today's chores to tap (the Chores view's rows and rules), **to-dos** to tick off or add, today's
schedule with leave-by times, and the week strip. An **adult's page**: what needs them next, the next
seven days, their to-dos and their chores. The phone's Me panels share the same sections. The view
is a live-sync piece fetched with its person. **To-dos** are a `Todo`: for a person or Anyone, due
on a day, at a time, or whenever, worth stars for a kid; done is a timestamp and undo takes the
stars back; added from the frame, a phone or Settings → To-dos. **To-dos due today appear on the
Today view** in that person's lane: timed ones with the events in time order, open untimed ones
(due today, overdue, undated) as a compact "To do" group; Anyone's sit with the Anyone chores.
**Lane counts follow the people** (Simplifications 6 lifted): the Today lanes, the Chores lanes (plus
Anyone), the calendar's day columns and the People grid take one column per person and go compact
past five.

Still the owner's: the frame boot fixes (2 A supply, Wi-Fi defer, fixed MAC, clock) when the frame
moves to the wall, and ISRG Root X2 on the frame for the Cloudflare chain (docs/private).

### Milestone 7: the Rails side built (2026-10-17); the library arrives with Immich
**Immich** is a client like the hub's (`immich.url` / `immich.api_key` in the credentials, off until
set; `ops/immich/compose.yml` runs it beside the app). `PhotoSyncJob` (every 6 hours, or "Sync
photos now") turns the household's **chosen albums** (Settings → Integrations, ticked from Immich's
list) plus **"on this day"** across the last fifteen years into the `Photo` rows the slideshow
already knows: date, orientation (from the EXIF size and rotation), place (city, state), album and
favourite. Photos gone from Immich go, the pool stays under three hundred, the demo photos stay
until "Clear the demo photos". **Images** come through us (`/photos/:id/image`, preview or
thumbnail, a day of browser caching), since the frame never holds the Immich key. **Favourites**
toggled on the frame are favourites in Immich. The slideshow, the Today tile and the ambient screen
are unchanged: on-this-day first, favourites twice (ui-spec §1.5).

Not in it: the phones' backup (the Immich app, owner's step; the plan's iOS caveats apply),
Immich's "memories" endpoint (the date search gives the same across years without depending on it),
albums per person.

### Milestone 6: the Rails side built (2026-10-17); cameras and alerts arrive with the hub
**Snapshots.** A mapped camera's image comes through us from Home Assistant's camera proxy (the
frame never holds the hub token), cached for fifteen seconds so a wall of screens is one request to
the camera; the Home control tiles and the camera sheet refresh mapped images every twenty seconds;
real cameras come before demo ones; demo cameras keep their placeholders. **Alerts** are
`HomeAlert`s (doorbell, package, leak, garage left open) that Home Assistant automations post to
`/hooks/home_assistant` with a shared secret (`home_assistant.webhook_secret`;
`ops/home-assistant/automations.example.yaml`). Each is kept and reaches every frame as an `alert`
stream action: the doorbell takeover with that camera's snapshot, the leak takeover with the
sensor's words, the package and garage banners with the alert's text. Dismissing, "Leave open" or
"View camera" acknowledges the alert, which the audit log records. Takeovers and banners stay the
frame's; phones get push in a later phase (gap review). **Auto-relock**: a door unlocked from the
doorbell takeover (through the PIN pad, as any unlock from the frame) relocks itself two minutes
later unless someone locked it already. **Garage-open timer**: fifteen minutes after the garage
opens, if it is still open, a banner says for how long and which adult is how far away, and asks
again every fifteen minutes until it closes or someone chooses "Leave open". **The water main**:
the leak takeover's hold closes the household's valve entity through the hub when one is set
(Settings → Integrations); nothing happens otherwise, as before.

Not in it: phone push (later phase), live video (snapshots only, ui-spec §1.6), Nest and Ring
themselves (they are Home Assistant integrations; milestone 5's hardware half).

### Milestone 5: the Rails side built (2026-10-16); the hub itself is next
**Mapping.** Every home thing carries the Home Assistant entity behind it (`entity_id` on devices,
the thermostat, the speaker, cameras, scenes; `presence_entity` on people); nil means the demo
data. Settings → Home lists rooms with their devices, scenes with per-device levels, climate, media
and cameras, each with add, edit, move and remove; the forms offer the hub's entities when it is
connected; **Import from Home Assistant** maps every light, switch, lock and cover it knows and
nothing is mapped to (plus the first thermostat and speaker and every camera); **Clear the home**
removes the demo home. Device types the house lacks simply have no device, so their tiles, sheets
and summaries do not appear (plan: Our instance).

**Writes** go through the hub: a mapped device's `apply` calls the matching service (lights and
switches, locks, covers for blinds and the garage) and lands the patch only when the hub took it,
which is the optimistic contract of ui-spec §1.6 unchanged; the thermostat sets its temperature in
the hub's unit and its mode, the speaker plays and pauses, a scene may also turn a hub scene on.
**States** come back two ways: the **bridge process** (`bin/rails home_assistant:listen`, the Kamal
`bridge` role) holds a WebSocket to the hub, subscribes to state changes and applies each to our
rows (it idles until the hub is configured, reconnects with a backoff), and `HomeStateRefreshJob`
reads every state every five minutes so a missed event never lasts. **Presence**: a person's hub
person entity gives Home / Away / "At <zone>" and their position; the Today card shows adults only
(gap review); an adult away gets an ETA home from the Waze service, cleared at home.

**Unlocking needs an adult** (gap review): adults set a 4–8 digit PIN on their person; on the frame
a lock's hold-to-unlock and the garage's slide-to-open answer with a PIN pad in the sheet; a signed-in
adult on a phone needs no PIN, a kid's login cannot unlock, anyone can lock. **The audit log**
(second gap review) records settings changes (people, routines, chores, stores, calendars,
screens, the household), chores done and undone, locks, unlocks, garage openings, scenes,
turn-everything-off and lock-all, each with the actor: the PIN's adult, the login's person, the
login, or the screen. Settings → Activity reads it; entries are pruned after ninety days.

**Still to do for the hub itself** (needs the owner): the home server that runs Home Assistant,
Tailscale between it and the VPS, the long-lived token in the credentials, adopting the devices in
Home Assistant (Hue, Kasa/Tapo, WiZ, Matter shares, Nest, Ring, the Ecobee), the Companion app on
each adult's phone, then Import and a pass through Settings → Home. Cameras keep placeholder images
until milestone 6.

### Sign-in: members only (2026-10-15)
The first login on a household with no logins bootstraps its owner. From then on only members may
sign in: an adult adds people in Settings, and a person's **email is their login** (a code each
time, no password; the address gets a mail saying where to sign in). Adults get Settings and
screens; a **kid with an email gets the app** (Me, chores, the lists), not Settings; a kid without
one has no login. Removing a person removes their login. Existing logins keep working without a
person (a fresh start removes the people, not the logins). The code forms are rate limited (ten
tries per few minutes). The household's time zone is stored as an IANA name; the settings select
offers those, and Rails' own zone names are normalised on the way in.

### Our instance
Our own household settings (people, emails, stores, devices, domain, network) live in
`docs/private/household.md`, which is gitignored. Nothing below depends on them; they are entered
through the app's setup/settings, never hard-coded.

Product decisions that came from our household and apply generally:
- Units and clock are settings (we use °F and 12-hour). Weather advice thresholds and thermostat
  steps/clamps follow the unit (Wes's "below 12 °C" ≈ 54 °F; 1 °F steps).
- **Stores, categories, aisle order, catalogue and usuals have full CRUD in the live app.**
- Device types the house doesn't have (garage, blinds, leak sensor) stay fully implemented but are
  hidden until a device of that type is mapped.
- Photos via Immich. iPhone sync = Immich iOS app background backup. Caveats for setup docs: iOS
  runs background backup only when it allows (opening the app catches up); photos kept only in
  iCloud ("Optimize iPhone Storage") need the app's iCloud download option.

### Calendars: pluggable sources
Today the family uses one shared Google calendar; this must be swappable later (HEY, another
Google calendar, ICS feeds, etc.) without touching the UI.

- **`CalendarSource`** model with an **adapter** per kind, all producing the same normalized
  `Event` rows:
  - **`IcsAdapter` (v1, the only one):** any ICS/webcal URL (HEY calendar subscription, Google
    secret iCal address, Outlook, school calendars), read-only.
  - Later, if wanted: `GoogleCalendarAdapter` (read + write) or `LocalAdapter` (app-only events).
- Each source has: name, adapter, credentials/URL, enabled, refresh interval, **assigned people**
  (a calendar can belong to one person, several, or the whole family), **writable?**. Sources can
  be added, swapped or disabled in settings; events are re-synced and the UI doesn't change.
- **Who an event belongs to** (decided), in priority order:
  1. **Manual override** set in Home HQ (from the event sheet, frame or phone); survives re-syncs.
  2. **Names in the title**, the way the family already writes them ("Ava ballet", "Max
     chinese class", "Ava + Max swim"): whole-word, case-insensitive match on each person's
     name and optional nicknames. The title is shown unchanged.
  3. **The calendar's assigned people** (a person's own calendar → that person; the shared family
     calendar → Everyone).
- **Colours are always per person** (never the source calendar's colour): an event takes its
  person's colour, a multi-person event uses the first person plus dots (Wes's rule), everyone =
  the black family style.
- **No adding, editing or deleting events for now** (see Simplifications): the Add sheet is hidden;
  only the people override can be changed.
- Recurrence (RRULE/EXDATE) expanded server-side for a rolling window (e.g. −7 to +60 days).

### Agents view: removed
Not built. Its rail slot goes to the **People** view below. (Its code in Wes's prototype is not
ported.)

### People view (new; replaces Agents)
One place where each person sees everything related to them.

- **Rail:** "People" (frame) / "Me" (phone). On the frame: four big avatars, tap one to open that
  person; idle returns to Today as usual. On a phone: opens the logged-in person,
  with the others one tap away.
- **Kids: "My day"** - built to be read by a kid on the wall:
  - **today's progress**: a big ring/bar for the whole day plus one per routine (morning, after
    school, evening), stars earned today, star total;
  - their chores for today, tappable to complete (same rules and Undo as the Chores view);
  - their **to-dos** (one-off items: "pack swim bag", "library book back"), tappable;
  - today's schedule (their events, with leave-by times);
  - the "This week" strip (days with everything done).
- **Adults:** today's and upcoming schedule (next 7 days), their to-dos (open, due,
  done today), chores assigned to them, and anything needing them (e.g. "Leave in 10 min").
- **New model: `Todo`** - person (or Anyone), title, optional due date/time, optional stars for
  kids, done_at, created_by. Distinct from routine chores (which repeat daily). Created from the
  frame, a phone, or the People view. **To-dos due today appear on the Today view** in that
  person's lane (timed ones in time order with events; untimed ones as a compact "To do" group),
  tappable to complete; Anyone to-dos go with the Anyone chores.
- Phone layout: the same sections stacked.

### Gap review answers (2026-10-14)
**Frame and security**
- **Unlocking from the frame:** Wes's hold-to-unlock **plus an adult PIN**. Anyone can lock;
  unlocking needs the PIN. (Phones: logged-in adults only.)
- **Night screen:** default **screen off overnight** (set hours, a tap wakes it); setting to use
  Wes's **red night clock** instead. Night hours configurable per screen. (Additive: Wes's red night
  mode stays fully implemented.)
- **Kiosk menu (two-finger hold):** Settings and Launcher require an **adult PIN**; Reload stays
  open. (Small kiosk app change.)
- **Logins:** **rails-now magic-link auth (email code)**, no passwords; passkeys deferred. Roles: adult, kid
  (no login), screen device. Screens sign in once as a named device with a long-lived session.
- **Screens:** plan for **several**. Each screen is a named device with its own settings (night
  mode and hours, default view, brightness, nightly reload).
- **Nightly reload** of each screen (default 3 AM) to keep the old WebView healthy.
- **Clock:** the frame corrects its time from the server's clock on every response (plus the boot
  fixes for NTP).

**Calendar and events**
- ~~Edit and delete events~~ - superseded: calendars are read-only for now (Simplifications 3).
- **"Send directions to phone":** v1 = QR code (see Second gap review); later, a **person picker** of adults (preselects the event's adult, if
  any); push goes to that adult's phone.
- **Kids' presence: hidden** (presence shows adults only).
- **Sync:** poll every **5 minutes** for all sources (no Google push channel for now).
- (If a Google API adapter is added later: set its OAuth app to "In production"; Testing-mode
  refresh tokens expire after 7 days.)

**Chores**
- Two schedule types: **daily** (per routine, as Wes) and **specific weekdays** ("Piano practice
  Mon/Wed", "Chinese study Mon-Wed"). A chore appears on the days it's due, in its routine.
  "Overdue" = due earlier today (an earlier routine) and not done. One-off items are to-dos.

**Devices**
- **Locks: Yale** (Home Assistant via Matter/Yale integration; confirm the model at milestone 5).
- **Thermostat: Ecobee** (Home Assistant 2026.3+ logs in with the ecobee account; no developer key).

**Data**
- **Nothing to import**; start fresh. Seed common grocery catalogue items and categories.

**Operations**
- **Home server:** updates on a **schedule** (no auto-update), containers restart on boot, UPS
  recommended.
- **Alerts:** **Telegram** messages from a bot (server/tunnel down, frame offline, errors, backup
  failures). Free.
- **Backups:** **Cloudflare R2** for **the app's database and data only** (Litestream for SQLite,
  plus any uploaded files such as avatars). **The photo library is not backed up** (Immich mirrors
  the phones' libraries, which live in iCloud/Google already). Home Assistant's own config is
  outside this scope; losing it means redoing device setup in HA.

### Second gap review (2026-10-14)
**Foundation: generate with `~/Work/rails-now`** (owner's bootstrapper and conventions):
- `rails-now home_dashboard Household ~/Work shared` → Rails 8, SQLite + Solid Queue/Cache/Cable,
  **magic-link auth (email → 6-digit code, bcrypt digest, 10-min TTL; no passwords stored)**,
  Identity/User split, `Current.household` tenancy (shared: one household per install, which also
  suits open-source self-hosters), MailerSend SMTP in production, letter_opener in development, a
  generated `CLAUDE.md`, and **local CI** (`~/Work/ci-template`: pre-push `bin/ci`, `gh signoff`;
  no GitHub Actions). Secret scanning (gitleaks) goes into `bin/ci`.
- Its conventions apply: delegated types, concerns with a common interface, name entities not
  values, tokenized public shares, always read through `Current.household`, defer what isn't needed.
- rails-now's "server-rendered, Hotwire" rule now applies to Wes's UI too (Working agreement),
  unless the milestone-1 frame performance spike forces the fallback.
- **Note:** the generated app as checked out may not exactly match the assumptions here (e.g. its
  deploy notes assume Hatchbox; we deploy with Kamal). Read the generated `CLAUDE.md` first.

**Security**
- **Adults:** email-code login (rails-now), year-long sessions. No passwords anywhere. Passkeys
  deferred (Simplifications 4).
- **Unlocking from a phone** asks for the adult PIN; on the frame, hold + adult PIN (above).
- Rate-limited login (Rails 8 `rate_limit`), audit log of unlocks, settings changes and
  completions.
- Home bridge least privilege: non-admin HA user, read-only Immich API key, Tailscale ACL letting
  only the Rails server reach HA and Immich.

**Offline edits on phones:** not in v1 (Simplifications 5): "Can't save while offline".

**Routines:** **weekend routines** (different routines or hours on Sat/Sun) and a **holiday /
vacation pause** (chosen days or a trip: chores paused, no misses on the weekly strip). School
calendar automation: not now.

**Scheduling:** everything runs in the **household's time zone**, never the server's (the VPS is in
Germany): day boundaries, chore resets, routines, nightly reloads, "today".

**Travel-time refresh:** every 10 min only within ~2 h of an event's leave-by time, hourly
otherwise; cache by origin/destination (polite to Waze via Home Assistant).

**DNS and certificates:** the dashboard hostname is **DNS-only (grey cloud)** in Cloudflare so
Kamal's Let's Encrypt certificate is what clients see; the frame then needs only ISRG Root X1.

**Chores** count **immediately** when tapped (Wes's behavior, with Undo); no parent approval.

**Phone notifications: not in v1.** The phone app is a "Add to Home Screen" web app for now.
- **"Send directions to phone" in v1:** tapping the location shows a **QR code** (and the address);
  scanning it with a phone camera opens Apple/Google Maps. No push, login or app needed. The person
  picker and Web Push version move to a later phase.
- Alerts for phones (doorbell, leave reminders, security) are a later phase; the frame's takeovers
  and banners are unaffected. Operational alerts go to Telegram (above).

**Phone design: mockups first.** Clickable phone mockups of every view, in Wes's style, approved
before milestone 2 is built.

**Wes:** contact him **before milestone 1** about a licence/permission, since building on his code
depends on it.
**Decision 2026-10-14 (owner):** the note went to Wes on 2026-10-14; no reply yet. The owner chose to
start milestone 1 anyway rather than wait: the port goes ahead, and if Wes declines or asks for
changes, the views are ours to refactor or redesign later.
**Update 2026-10-19:** Wes gave the OK and published his prototype under the MIT licence; his notice
and the list of derived parts are in `LICENSES/wes-bos-home-hq.txt`.

## Functionality parity (rule)
**Every behavior in `ui-spec.md` is kept**, including the demo/dev tools (demo drawer, time
presets, data modes, fast idle, `?diag`, `?exp`), ambient/night/nightdash, idle state machine,
burn-in shift, toasts with Undo, takeovers and banners, and the hidden-until-mapped device types.
The **only** removal is the Agents view (owner's decision). Additions (People view, to-dos,
pluggable calendars, phone layout, offline/stale handling, settings CRUD) must not change existing
behavior on the frame. Milestone 1 ends with a side-by-side parity check against the prototype.

## Open-source readiness
The repo starts private and will be published later, so from the first commit:

**Must not be in the repo (or its git history):**
- **Household data:** names, emails, kids' details, home address/coordinates, calendar
  assignments, photos, device/room/camera names. All of it lives in the database, entered through
  setup/settings. `docs/private/` is gitignored for our own notes.
- **Secrets:** ICS URLs (HEY/Google "secret address" URLs are credentials), Home Assistant
  long-lived token, Immich API key, Tailscale auth keys, MailerSend credentials, Telegram bot token,
  R2 keys, Rails `master.key` (later: Google OAuth, Web Push VAPID keys). Kept in
  Rails credentials (key never committed), `.kamal/secrets` reading from 1Password via `op`, or
  encrypted DB columns (Active Record Encryption) for per-household tokens entered in settings.
- **Infrastructure specifics:** domain, server hostnames/IPs, LAN addresses, SSH users: `config/
  deploy.yml` reads them from ENV; a `deploy.yml.example` is committed instead.
- **Kiosk signing keys** (`*.keystore`), frame backups, dumps (those stay in the separate
  photo-frame repo's ignored folders anyway).
- **Guards:** `.gitignore` from day one (`.env*`, `config/master.key`, `.kamal/secrets*`,
  `storage/`, `*.keystore`, `docs/private/`), gitleaks as a pre-commit hook and in CI, GitHub
  secret scanning on. If anything ever slips into history, rotate it and rewrite history before
  publishing (or publish a fresh squashed history).

**Must not be hard-coded (all become settings with sensible defaults):**
- people (count, names, colours, kid/adult, nicknames for title matching) - the UI must handle
  1 to ~8 people, not exactly four lanes (Wes's layout assumes 4 person lanes + Anyone);
- units (°F/°C), 12/24-hour clock, time zone, locale/first day of week (Wes's month view starts
  Monday), date formats;
- home location (for weather and travel), routines and their hours, chore lists, stars per chore;
- stores, categories, aisle order, catalogue, usuals;
- integrations: every one optional and switchable (**the app must run with zero integrations**,
  e.g. a "demo household" seed built from Wes's sample data);
- idle timings, night hours, slideshow intervals, frame device sessions;
- strings that name people or places in Wes's copy ("Pack a rain jacket for soccer" matches an
  event keyword - make the keyword/advice rules data, not code).

**Licensing and attribution:**
- **Wes's prototype has no licence**, so by default it is all-rights-reserved: the UI code, CSS and
  design can't be published in our repo without his permission. **Before going public, ask Wes for
  a licence (e.g. MIT) or written permission**; until then keep the repo private. (Plan B: publish
  only our backend and a rewritten UI.)
- Credit Wes and the photo-frame project in the README.
- Third-party assets: Archivo and Instrument Serif (SIL Open Font Licence; fine), icon set in
  `icons.js` (check its origin/licence), demo images from picsum.photos (only in demo mode).
- Kiosk Android app: rename its package (`com.wesbos.homehq`) and app name if Wes prefers, with
  credit; pick our own licence for our code (MIT is typical).

**Also before publishing:**
- README screenshots use the demo household, never our real data.
- Git author email: consider GitHub's `noreply` address for commits so personal emails aren't in
  the public history.
- Product name: "Home HQ" is Wes's name; ask him or choose our own.

## Future ideas (not in the current scope)
- **Announcements:** an adult sends an announcement from a phone; it takes over the whole frame
  (like the doorbell takeover) until someone acknowledges it on the frame, then it goes away (and
  the sender is told it was seen). Optional: priority, expiry, who acknowledged.
- **Kids' rewards:** spend stars in a reward shop, goals, streaks.
- **Meals:** weekly dinner plan; one tap to add a recipe's ingredients to the shopping list.
- **Systems panel:** servers, Synology, internet, backups, Immich backup progress, Claude/Grok
  status.
- **House health:** Ting, Rachio, Ecobee runtime, device health.
- **Family board:** notes and countdowns (birthdays, trips, school breaks).

## Open questions
1. **Espressif devices** (2): unknown generic Wi-Fi boards; HA discovery will likely identify them.
