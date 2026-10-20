# Home HQ

A family wall-frame dashboard (and phone app) built on Rails 8 + Hotwire, based on the look and
behavior of [Wes Bos's Home HQ prototype](https://github.com/wesbos/photo-frame-dashboard).

- Plan and decisions: `docs/plan.md`
- UI behavior spec: `docs/ui-spec.md`

## Development

```sh
bin/setup          # installs gems and pinned tools, prepares the SQLite databases, enables the git guards
bin/rails server   # http://localhost:3000; sign in with any email, the code opens via letter_opener
bin/ci             # the full local CI (also runs automatically before every push)
```

### Demo data

`db/seeds.rb` builds a demo household from Wes's sample data, relative to today, so the dashboard
always looks current. It fills the first household only while it has no people (safe to re-run).
Set the household's time zone first so the demo day is built in it:

```sh
HOME_DASHBOARD_TIME_ZONE=America/Los_Angeles bin/rails db:seed
```

Real household data is entered through the app from milestone 3 on; nothing in the seeds is ours.

### The dashboard

`/` is one page: the stage with its rail and every view already in the DOM; tabs switch in the
browser, and each piece of a view is a Turbo Frame that refreshes on its own (the hero when its
event starts, weather and lanes on the hour) or when a write changes it. Writes answer with Turbo
Streams. The wall frame signs in once through a screen enrollment link (`/screens`), phones sign
in by email code.

Press and hold the rail clock (or press `D`) for the demo drawer: time-of-day presets, ambient and
night modes, fast idle, the alert takeovers and banners, and the calendar data modes. `?diag` in
the URL shows the on-device diagnostics overlay.

### Phones

The same page under 700 px: the rail becomes a five-tab bar, views stack and scroll, sheets fill
the screen. Who is signed in picks the layout, so a person's browser (phone or desktop) gets the
device-width app and only an enrolled screen gets the fixed frame. Sign in by email code, then
Share → Add to Home Screen to install it. `PHONE_SHOTS=1 bin/rails test
test/system/phone_screens_test.rb` saves a screenshot of every view at phone size under
`tmp/screenshots/`.

### Settings and real data

`/settings` (adults only; the Me page links to it) opens with a Getting started list in the order
that works: people, routines, chores (a chore needs a routine, and the app insists), calendars,
stores, PINs, the screen. It holds the household (name, time zone, °C/°F,
12/24-hour clock, the first day of the week, a chores pause), people, routines, chores, stores with their aisle orders,
categories and the catalogue. To move a deployment from the demo data to a real household:
`bin/rails household:fresh_start` clears the demo people and lists, turns the demo tools off and
reseeds the generic catalogue, then enter the people, routines, chores and stores in Settings. Every write reaches
every screen live; changing the zone, units, clock or week start reloads every screen. Each
screen (`/screens`) has its own night hours and night style (dark, or the red clock), the view it starts on and idles back to, and a nightly
reload hour (3 AM by default) that keeps the frame's old browser healthy.

Sign-in is for members: the first login on a fresh install becomes the owner, who adds the other
people in Settings. A person's email is their login (they get a mail saying where to sign in);
adults get Settings, kids with an email get the app, kids without one have no login.

### Calendars, weather and drive times
Settings → Calendars takes read-only ICS or webcal addresses (a Google calendar's secret iCal
address, HEY, Outlook, a school calendar), each for some people or everyone; they sync every five
minutes, or on "Sync now". Who an event is for follows the names in its title (nicknames are set on
each person), the calendar's people, or everyone, and can be changed from the event sheet. A Google
share link or the public address of a private calendar is refused with a pointer to the secret
address. Weather comes from the **weather location** under Settings → Integrations (a city, looked
up and forecast by Open-Meteo, free and keyless), or from a Home Assistant weather entity when one
is set. Drive times come from Home Assistant: `HOME_ASSISTANT_URL` and `HOME_ASSISTANT_TOKEN` (fields
`home_assistant_url`/`_token` in the 1Password item, pulled by `bin/secrets-pull`, or the
credentials), then the home address and the Waze region. A feed that stops updating is flagged on
the screens (the weather says "as of", the calendar header names the feed). The outdoor words that
turn rain advice into "Pack a rain jacket for soccer" are a setting too. The event sheet's location opens a QR code that a phone camera turns
into directions. The jobs are in `config/recurring.yml` and run inside Puma's Solid Queue.

### The home (Home Assistant)
Settings → Home holds the rooms, devices, scenes, climate, speaker and cameras. Until Home Assistant
is connected they are the demo's. To connect it: run Home Assistant where it can reach the devices
(the home server), make the VPS reach it (Tailscale), create a long-lived access token in Home
Assistant and set `home_assistant.url` and `home_assistant.token` in the credentials (or the
`HOME_ASSISTANT_URL` / `HOME_ASSISTANT_TOKEN` environment), deploy, then on Settings → Home press
"Clear the home" and "Import from Home Assistant" and sort the devices into rooms. The `bridge`
process (`bin/rails home_assistant:listen`, a Kamal role) keeps a WebSocket to the hub so tiles
follow the house live; a full refresh runs every five minutes as well. Each person can be tied to
their Home Assistant person entity (the Companion app) for presence and an ETA home.

Unlocking a door or opening the garage from the frame asks for an adult's PIN (set on each adult
under Settings → People). Settings → Activity lists settings changes, chores, locks and scenes for
the last ninety days.

### Cameras and alerts
Mapped cameras' snapshots come through the app from Home Assistant's camera proxy and refresh
every twenty seconds on the Home control panel. Alerts come from Home Assistant automations that
post to `/hooks/home_assistant` with the shared secret `home_assistant.webhook_secret` (set it in
the credentials next to the hub's URL and token; `HOME_ASSISTANT_WEBHOOK_SECRET` works too);
`ops/home-assistant/automations.example.yaml` has the REST command and three automations to adapt.
The frame shows a doorbell takeover (with that camera), a leak takeover, and package and garage
banners; dismissing them is logged under Settings → Activity. A door unlocked from the doorbell
takeover relocks after two minutes. The app itself raises the garage-open banner fifteen minutes
after the garage opens. A water main valve entity under Settings → Integrations makes the leak
takeover's "hold to shut off water" real.

### People and to-dos
The People view shows the big avatars; tapping one opens that person's page. A kid gets "My day":
progress rings for the day and each routine, stars earned today and in total, today's chores, their
to-dos, today's schedule and the week strip. An adult gets what needs them next, the week ahead,
to-dos and chores. To-dos are one-off items for a person or anyone, due on a day, at a time, or
whenever, worth stars for a kid; add them on a person's page, from a phone's Me, or under
Settings → To-dos. Those due today appear in the person's Today lane, timed ones with the events and
the rest as a "To do" group. Lanes follow the number of people, one to about eight.

### Photos
The slideshow draws from Immich. Run it beside the app (`ops/immich/compose.yml`), create an API
key under Account settings, set `immich.url` and `immich.api_key` in the credentials (or
`IMMICH_URL` / `IMMICH_API_KEY`), deploy, then under Settings → Integrations tick the albums to show
and press "Sync photos now" (it also runs every six hours; "on this day" across the years is added
on its own). "Clear the demo photos" removes the placeholders. Images reach the screens through the
app, favourites toggled on the frame go back to Immich. The phones back their camera rolls up with
the Immich app.

### The wall frame

The frame runs Android System WebView 106, which cannot be upgraded. `bin/webview-check` (part of
`bin/ci`) rejects CSS and JavaScript it cannot run: 4/8-digit hex colours, `oklch()`,
`color-mix()`, CSS nesting, `dvh`, `inset`, ES2023+. System tests run in a headless Chromium
sized like the frame (1280×800). To check a change on the real frame without deploying, run the
dev server, forward it over USB (`adb reverse tcp:3000 tcp:3000`) and open an enrollment link
in the kiosk app: `adb shell am start -n com.wesbos.homehq/.MainActivity -d http://127.0.0.1:3000/screens/enroll/<token>`.

Offline: a service worker caches the shell and the last rendered page; with the server down the
frame boots from the copy and shows "Offline · showing data from H:MM" until the network returns.

## Alerts

Operational alerts (deploys, unhandled errors, later backups) go to a Telegram chat through a bot
you create with @BotFather. Put the bot token and the chat id in the production credentials
(`bin/rails credentials:edit --environment production`; the shared `credentials.yml.enc` holds
only the base secret, so development and test stay free of real services):

```yaml
telegram:
  bot_token: 123456:ABC...
  chat_id: 987654321
```

`TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` work too (`.kamal/secrets` passes those from
`.env`). Without them alerts are silently off. Check the setup with `bin/rails alerts:test`.
Every production boot (each deploy starts a new container) announces itself in the chat.

## Deployment

Kamal, to one machine: a VPS with its own TLS, or a machine at home behind a Cloudflare Tunnel.
`config/deploy.yml` reads everything machine-specific from ENV, so nothing household- or
server-specific is committed:

```sh
export HOME_DASHBOARD_SERVER=203.0.113.10          # the machine (SSH + Docker)
export HOME_DASHBOARD_DOMAIN=dash.example.net      # the public hostname
export HOME_DASHBOARD_SSH_USER=root                # the SSH user (root on a VPS, your user at home)
export HOME_DASHBOARD_TLS=true                     # kamal-proxy gets its own certificate (a VPS)
bin/kamal setup                                    # first time; bin/kamal deploy afterwards
```

**At home behind a Cloudflare Tunnel** (our shape since 2026-10-16: the always-on box runs the
app, Home Assistant and later Immich; the family keeps the public hostname, no VPN, no open
ports): create a tunnel in Cloudflare Zero Trust, add the hostname as a public hostname pointing
at `http://kamal-proxy:80`, put the tunnel token in the 1Password item (`cloudflare_tunnel_token`),
then deploy with `HOME_DASHBOARD_TLS=false` and the token in `.env` (`bin/secrets-pull`). The
`tunnel` accessory (cloudflared on the kamal Docker network) appears only when the token is set;
Cloudflare terminates TLS and kamal-proxy speaks plain HTTP behind it. The machine needs sshd
(Kamal deploys over SSH, even to itself) and your user in the `docker` group.

**Moving to another machine.** The app is one image and one Docker volume (the SQLite database and
uploads), replicated to R2 every ten seconds. On the new machine: Docker and sshd. Then, from the
laptop:

```sh
bin/kamal app stop && bin/kamal accessory stop litestream     # on the OLD machine's env: one writer at a time
export HOME_DASHBOARD_SERVER=<new machine> HOME_DASHBOARD_SSH_USER=<user>
bin/restore-db                                                # R2 → the new machine's volume
bin/kamal setup                                               # proxy, web, bridge, litestream (+ tunnel)
```

The tunnel follows the token, so the hostname moves with the app; on a VPS, point the DNS record
at the new address instead. Home Assistant moves with `ops/home-assistant/compose.yml` and one of
its own backups. Then `bin/kamal app remove` on the old machine.

Secrets follow Kamal's convention: `.kamal/secrets` (committed) only references variables, and
their values live in a gitignored `.env` that `bin/kamal` loads. Fill it once per machine, and
again after rotating a secret, from the 1Password item that is the source of truth:

```sh
bin/secrets-pull      # one `op` call: writes .env (mode 600) from the "Home HQ" item in vault "keys"
```

Item and vault names are overridable with `HOME_DASHBOARD_OP_ITEM` / `HOME_DASHBOARD_OP_VAULT`;
the item's fields are listed in `bin/secrets-pull`. A new machine never copies `.env` from
another one; it pulls its own. kamal-proxy gets the Let's Encrypt certificate on port 80/443;
Litestream runs as an accessory and streams the SQLite database to R2.

### Deploying from a new machine

Nothing is copied between machines: each one pulls its own secrets and has its own SSH key, so any
one of them can be cut off later by deleting one line on the server.

1. Clone the repo and run `bin/setup`.
2. Give the machine its own deploy key and point SSH at it for the server only:
   ```sh
   ssh-keygen -t ed25519 -N "" -C "home-hq-deploy@$(hostname)" -f ~/.ssh/home-hq-deploy
   printf '\nHost %s\n  User root\n  IdentityAgent none\n  IdentitiesOnly yes\n  IdentityFile ~/.ssh/home-hq-deploy\n' "$HOME_DASHBOARD_SERVER" >> ~/.ssh/config
   ```
3. Allow that key on the server, authenticating with a key you already use there:
   ```sh
   ssh root@$HOME_DASHBOARD_SERVER "cat >> ~/.ssh/authorized_keys" < ~/.ssh/home-hq-deploy.pub
   ```
4. Pull the secrets into `.env`: `bin/secrets-pull`. On a headless box without the 1Password
   app, sign the CLI in first with `op signin` (account password + secret key); the session is
   only needed for that one pull.

From then on `bin/kamal deploy` needs neither 1Password nor an SSH agent on that machine.

## Licence

MIT, see [LICENSE](LICENSE). The look and behaviour come from
[Wes Bos's Home HQ prototype](https://github.com/wesbos/photo-frame-dashboard) (MIT, © 2026 Wes Bos);
[`LICENSES/wes-bos-home-hq.txt`](LICENSES/wes-bos-home-hq.txt) lists the parts derived from it and
carries his notice. Used with his blessing.
