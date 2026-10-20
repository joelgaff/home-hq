# home_hq — working notes for Claude Code

## Stack (fixed)
- Rails 8, **SQLite + Solid suite** (Queue/Cache/Cable). No Postgres/Redis/Sidekiq.
- Hotwire (Turbo + Stimulus). Server-rendered, minimal JS.
- Mail: **letter_opener** in dev, **MailerSend** (SMTP) in prod.
- Deploy: **Kamal** to one machine, at home behind a **Cloudflare Tunnel** since 2026-10-16
  (`config/deploy.yml` reads `HOME_HQ_SERVER`, `_DOMAIN`, `_SSH_USER`, `_TLS` and
  `CLOUDFLARE_TUNNEL_TOKEN` from ENV; the `tunnel` accessory exists only with the token; a VPS
  shape is the same file with `_TLS=true`). `bin/restore-db` moves the database between
  machines; `ops/home-assistant/compose.yml` runs the hub beside the app. See the README. DNS: Cloudflare. Storage: Active Storage → **Cloudflare R2**;
  SQLite streamed to R2 with Litestream. Operational alerts → Telegram.
- The product plan, decisions and the UI spec live in `docs/plan.md` and `docs/ui-spec.md`;
  the ordered list of what is left is `docs/private/next.md` (git-ignored: the owner's own setup).
  Follow the plan's **Working agreement** (red/green/refactor, commit after each green, no AI
  attribution in commits, alert the owner before deviating).

## What already exists (built by the foundation script — do NOT recreate)
- **Auth:** Identity/User split, passwordless **6-digit magic-link** login. Working end to end:
  email → code emailed → code entry → session. See `SessionsController`, `Authentication`
  concern, `LoginMailer`, `Identity#issue_login_code!` / `#login_code_valid?`. **Members only**
  (plan: Decisions): `Household#login_allowed?` (a person's email, an existing login, or the first
  login ever); `Person#email` links to its `User` (`link_login`, and at first sign-in);
  `require_adult` guards Settings and screens (a kid's login gets the app only); `rate_limit` on
  the code forms.
- **Tenancy:** `Current.household` resolved in `ApplicationController#set_household`
  (single-tenant via `Household.first` today). `Current.user` set on sign-in.
- Root route → `home#index` (a trivial signed-in landing page).
- **Alerts:** `Alert.deliver(text)` (via `AlertJob`) → `Alerts::Telegram` (Bot API; credentials
  `telegram.bot_token` / `telegram.chat_id` or `TELEGRAM_*` env; no-op when unset, never raises).
  `Alerts::ErrorSubscriber` reports unhandled exceptions, one per class per 10 min; Puma's
  `on_booted` (config/puma.rb) announces each production boot, which is the deploy notice;
  `bin/rails alerts:test` sends a check message. `.github/workflows/uptime.yml` (not CI) checks `/up`
  from outside every 30 min and tells the same chat on a change (repository secrets).
- **CI runs locally, not on GitHub Actions:** `.githooks/pre-push` runs `bin/ci` (steps in
  `config/ci.rb`), blocks the push if it fails, and marks the commit green with `gh signoff`
  when it passes. `bin/setup` enables the hook per clone. Add CI steps to `config/ci.rb`.
- **Secret scanning:** `.githooks/pre-commit` runs gitleaks over the staged changes and `bin/ci`
  runs it over the whole history (gitleaks is pinned in `mise.toml`; allowlist false positives in
  `.gitleaks.toml`). Never commit household data, keys, tokens, domains, IPs or SSH users.

## The dashboard (milestones 1–3)
- **One page** (`DashboardController#show`, layout `dashboard`): the stage, rail and all views
  (`app/views/dashboard/views/*`), overlays (ambient, night, demo drawer, alert templates) and
  the sheet layer. Wes's CSS is copied as-is under `app/assets/stylesheets/dashboard/`; our
  overrides live in `dashboard/port.css` and `people.css`. **Never add `allow_browser`.**
- **Layout by who is signed in** (`frame_layout?` in ApplicationController = `current_screen`):
  a screen gets the fixed 1280 viewport and `?layout=frame` manifest; a person gets
  `width=device-width`, `dashboard/phone.css` (all phone rules, under `@media (max-width: 700px)`),
  `body[data-layout=app]` and the shell's `layout` value (no idle/modes/demo, click navigation).
  Phone-only partials render only when `!frame_layout?` (`today/_agenda`, `people/_me`,
  calendar chips, `calendar/_one_day`); frame-oriented controller tests must `show_on_screen`.
- **Views are Turbo Frames**: `TodayController` (`?part=hero` re-renders one piece),
  `CalendarController` (mode + date), `ChoresController` (routine), `ShoppingController`
  (store + drawer). Writes (`ChoreCompletions`, `GroceryItems`, `ClearedGroceries`, `Devices`,
  `SceneActivations`, `Lights`, `Locks`, `Thermostats`, `MediaPlayers`, `Photos`) answer with
  Turbo Streams that replace the pieces they touched (+ the Today card) and `update #toasts`.
- **Time**: `Current.now` (household zone, demo offset from the session); the page carries it
  and the UTC offset; `dashboard/clock.js` derives wall-clock time in the browser (UTC getters
  on shifted Dates), clocks and countdowns tick locally (spike rules in docs/plan.md).
- **Stimulus** (`app/javascript/controllers`): `shell` (router, tick, modes, idle, keys),
  `refresh` (frame reloads on the minute/hour/at an instant), `sheet`, `toast`, `hold`,
  `slideshow` (+ `dashboard/slideshow.js`), per-view controllers, `alerts`, `demo`, `diag`,
  `connection` (offline banner). `dashboard/request.js` sends Turbo Stream writes.
  `picker` narrows stacked lanes/panels to one person (chores chips, Me).
- **Live sync** (`Pieces`, `SyncsPieces`): models declare the piece ids their commits move;
  `ApplicationController` batches them per request and broadcasts one `pieces` action to the
  household; `dashboard/sync.js` fetches the named pieces from `PiecesController` (`/pieces`)
  with the page's context (routine, store, drawer), skipping its own writes via `X-Page-Token`.
  New piece ids go in `Pieces::REGISTRY`. Never broadcast rendered HTML (layouts differ).
  Household settings the page bakes in (zone, units, clock, week start) broadcast a `reload` instead.
- **Settings** (`SettingsController`, `Settings::*`, layout `application` + `dashboard/pages.css`):
  opens with `settings/_setup` (`Household#setup_steps`, `#setup_complete?`); `Settings::ChoresController`
  `require_a_routine` gates new/create.
  CRUD + `move` (up/down via `Positioned#move!`) for people, routines, chores, stores (+ aisle
  order), categories, catalogue. `Scheduled` holds weekday bitmasks (`weekday_names=` from forms);
  `Household#fresh_start!` / `seed_catalog!` move from demo to real data. The week starts on
  Monday or Sunday (`Household#beginning_of_week`, `week_day_names`). **Screens** (`ScreensController`,
  adults) carry their own settings: `night_from`/`night_to` (`Screen#night?`), `night_style` (off =
  dark, `port.css` hides the clock; clock = Wes's red clock), `default_view`
  (`Screen::VIEWS`), `reload_hour` (nil = never); the page bakes them into the shell's values
  (`data-shell-view-value` etc.), the shell checks them on the minute (`hourly`), and a change
  broadcasts `reload` on the screen's own stream (`Screen::RELOAD_SETTINGS`).
- **Models**: `Household` concerns per area (`Calendar`, `Chores`, `Shopping`, `HomeControl`,
  `Photos`); `Device` is a delegated type (`Light`, `Blind`, `DoorLock`, `GarageDoor`) with the
  optimistic `apply` contract; chores are done via `ChoreCompletion` rows (daily reset for
  free) and stars are a ledger (`StarEntry`). **Query budget**: the page loads chores once per
  request (`Household#loaded_chores`, cached in `Current.chores_cache`, cleared by chore and
  completion writes) and devices once per piece (`Household#home_status`); a test caps the page's
  queries. Read lists from these, never per row.
- **Offline writes** are refused in `dashboard/request.js` (`offline()`, toast `tpl-offline-write`,
  also Turbo form submits). **Stale feeds**: `WeatherReport#stale?`, `CalendarSource#staleness`.
  **Samples**: `Household#clear_samples!` (demo home, photos, weather; `fresh_start!` calls it;
  `household:clear_samples`). A unit change converts stored temperatures.
- **Seeds** = Wes's demo data (`db/seeds.rb`, idempotent); they set `households.demo`, which alone
  shows the demo tools (drawer, presets, tip, `DemoController`); `fresh_start!` clears it. `bin/webview-check` guards WebView
  106 compatibility in `bin/ci`; system tests run headless at 1280×800.

## Milestone 4: calendars, weather, travel
- **Calendar feeds**: `CalendarSource` (kind `ics` → `CalendarSources::Ics`, `fetcher` injectable
  in tests) `sync!`s into `Event` rows (`uid` per occurrence, `calendar_source_id`); people by
  `CalendarSource#people_for(title)` (override on `events.people_overridden` → `Person#named_at`
  with `nicknames` → source people → everyone). `CalendarSyncJob` every 5 min (`config/recurring.yml`,
  shared across envs). The calendar view is the `calendar` piece (context mode/date/person in
  sync.js; `CalendarController.locals_from`). `Event`/`Attendee` sync the today + calendar pieces.
- **Home Assistant**: `HomeAssistant.state` / `.call` (`transport` injectable; `configure`/`reset!`
  in tests), nil when unconfigured. `WeatherSyncJob` (30 min; `households.weather_entity` via the hub, else
  `weather_location` → `OpenMeteo.geocode`/`.forecast`, transport injectable; `rain_keywords` drive the advice;
  `weather_reports.source`), `TravelSyncJob` (10 min, `home_address` + `travel_region`,
  `events.travel_checked_at`, synced events only). Jobs set `Current.household` and
  `Time.use_zone`, and wrap writes in `Pieces.batch(origin: nil)` for one broadcast.
- **Sheets**: a form inside the sheet closes it on submit unless it carries `data-sheet-keep`.
  `EventsController#update` (people override) answers the sheet plus a `pieces` stream action with
  no origin, which makes the page refetch its own pieces. `#directions` renders the QR (rqrcode SVG).

## Milestone 5: the home bridge (Rails side)
- **Mapping**: `entity_id` on `Device` (unique per household; `Device::DOMAINS` per type),
  `Thermostat`, `MediaPlayer`, `Camera`, `Scene`; `Person#presence_entity`. Settings → Home
  (`Settings::HomeController` + rooms/devices/scenes/cameras/climate/media_players controllers;
  `settings/_entity_field` with the hub's `datalist`). `Household#import_from_hub!`, `#clear_home!`.
- **Writes**: `Device#apply` → `HomeAssistant::Commands.device` when `hub?` (mapped + configured),
  else the demo `flaky` rule; `Thermostat#adjust!`/`#set_mode!`, `MediaPlayer#toggle!`,
  `Scene#activate!` the same. Commands answer false on `HomeAssistant::FAILURES`; callers refuse the patch.
- **States**: `HomeAssistant::StateSync.apply(household, state)` / `.apply_many` / `.refresh`
  (rows updated directly, never via `apply`). `HomeAssistant::Listener` (WebSocket via
  websocket-driver; `session` testable with a fake connection) runs under `home_assistant:listen`
  = Kamal role `bridge`; `HomeStateRefreshJob` every 5 min.
- **PIN**: `Person has_secure_password :pin` (`pin_digest`, adults, 4–8 digits);
  `Household#adult_for_pin`; `DevicesController#unlocking?` → `devices/pin.turbo_stream.erb`
  (+ `open_sheet` stream action in sync.js, `pin` Stimulus controller); `Current.pin_person`.
- **Audit**: `AuditEntry.record(action, household:, subject:, details:)`; `Audited` concern
  (`audited "person", only: [...]`) on settings records; explicit records in chores, devices,
  scenes, home control; `AuditEntry#sentence` for Settings → Activity; `AuditEntry.prune!` daily.

## Milestone 6: cameras and alerts (Rails side)
- **Snapshots**: `CamerasController#snapshot` → `HomeAssistant.camera_image` (binary transport:
  `[status, bytes, type]`), `Rails.cache` 15 s; `Camera#snapshot_url` is the proxy path when mapped,
  the placeholder otherwise; `img[data-live]` refreshed by `control_controller#refreshLive`.
- **Alerts**: `HomeAlert` (kinds doorbell/package/leak/garage_open → `screen_kind`), created by
  `HooksController#home_assistant` (X-Hook-Secret vs `HomeAssistant.webhook_secret`, no session or
  CSRF) or by `GarageOpenCheckJob`; `after_create_commit` broadcasts the `alert` stream action
  (sync.js → `house:alert` → `alerts_controller#show`); `HomeAlertsController#acknowledge`
  (`alerts_controller#acknowledgeAlert` on dismiss/Leave open/View camera). `_alerts` renders for
  the frame only.
- **Relock**: `Device#unlock_for_a_while!` / `params[:relock]` → `RelockJob` after
  `Device::RELOCK_AFTER`; `Device#apply(patch, audit:)`. **Garage**: `GarageDoor` after_update_commit →
  `GarageOpenCheckJob` (15 min, re-arms while open, quiet after an acknowledged alert).
- **Water main**: `households.water_valve_entity`, `WaterValvesController#close` (valve.close_valve or
  switch.turn_off), `alerts_controller#valve` posts it.

## Milestone 7: photos (Rails side)
- `Immich` (`app/models/immich.rb`): `configure`/`reset!`/`transport` like `HomeAssistant`;
  `albums`, `album(id)`, `search(body)`, `favorite!(ids, bool)`, `thumbnail(id, size:)` (binary).
- `PhotoSyncJob` (6 h; `households.immich_album_ids` json): upserts `photos.immich_id` rows
  (`image_key` "immich:<id>"), on-this-day via `/api/search/metadata` per past year, prunes
  vanished and beyond `POOL_CAP`; demo photos (nil `immich_id`) untouched. `Photo#url` is
  `image_photo_path` for Immich photos. `PhotosController#image` proxies; `#update` mirrors the
  favourite. `Settings::PhotosController` sync/destroy.

## Milestone 8: People view, to-dos, lane counts
- `Todo` (`household`, `person` nil = Anyone, `due_on`/`due_at`, `stars`, `done_at`, `done_by`,
  `created_by`; `complete!(by:)` writes a `StarEntry` with `todo_id`; `undo!`). `Household#todos_today_for`
  / `#open_todos_for` order: timed today, open untimed (overdue first), done today. `TodosController`
  answers `todos/changed` (lanes + agenda + a `pieces` nudge for chores/people). `Settings::TodosController`.
- People view: `PeopleController#show` renders `people/people` (the `people` piece; locals `person:`),
  `people/_day` (kid), `people/_adult`, shared `_needs`, `_schedule`, `_todos`, `_chores_list`,
  `_rings`; the phone's `people/_panel` uses the same. sync.js takes the person from `#people [data-person]`.
- Lane counts: views set `style="--lanes:N"` (+ `is-many` past five); `port.css` overrides Wes's
  fixed `repeat(4|5, 1fr)` with `repeat(var(--lanes), 1fr)`; the 3-day calendar keeps its classes.

## Conventions
- **Delegated types** for "same role, different attributes" modeling; keep superclasses lean
  (only universal FKs on the parent), type-specific attributes on the type tables.
- **Shared behavior via concerns** with a common interface; let each type define divergent pieces.
- **Name entities, not values** (no `Year` table with a `year` column).
- **Tokenized public shares** (`has_secure_token` + unauthenticated token-scoped controller)
  instead of building logins for external/read-only users.
- **Route reads through `Current.household`** — never a hardcoded id or `.first` outside
  `set_household`. Keeps multi-tenancy a one-line change later.

## Deferred until actually needed
- Multi-tenant membership/roles/switching (single-tenant now; structure is ready).
- Stripe billing (add when the app monetizes).

## Build the domain on top
Add domain models/controllers/views. The foundation (auth, tenancy, mail) is done.
