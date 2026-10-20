// Live sync between screens (plan: milestone 3). The page subscribes to its household (the
// turbo-cable-stream-source on the stage). A write anywhere broadcasts a "pieces" action naming
// the dashboard pieces it changed; this page skips its own writes (its page token travels with
// every request as X-Page-Token), coalesces the rest for a moment, and fetches the pieces it has
// in the DOM from /pieces, rendered for this page. On a cable reconnect the active view's pieces
// are fetched again, since missed streams never replay. No ES2023+ (WebView 106).
import { Turbo } from "@hotwired/turbo-rails"

export const pageToken = Math.random().toString(36).slice(2) + Date.now().toString(36)

document.addEventListener("turbo:before-fetch-request", (e) => {
  e.detail.fetchOptions.headers["X-Page-Token"] = pageToken
})

let pending = {}, timer = null

Turbo.StreamActions.pieces = function () {
  if (this.getAttribute("origin") === pageToken) return
  const ids = (this.getAttribute("targets") || "").split(",")
  ids.forEach((id) => { if (id && document.getElementById(id)) pending[id] = true })
  clearTimeout(timer)
  timer = setTimeout(flush, 250)
}

// Settings every page bakes in (clock format, offset, units) changed: reload, unless this page
// made the change (the frame keeps its view: the URL hash names it).
Turbo.StreamActions.reload = function () {
  if (this.getAttribute("origin") === pageToken) return
  location.reload()
}

// A write that needs more from the person (the PIN pad) answers with the sheet's content and
// this action, which opens the sheet layer around it.
Turbo.StreamActions.open_sheet = function () {
  const layer = document.getElementById("sheetLayer")
  if (!layer) return
  layer.classList.add("is-open")
  const body = layer.querySelector("[data-sheet-class]"), box = layer.querySelector(".sheet")
  if (box) box.className = "sheet " + ((body && body.dataset.sheetClass) || "")
}

// An alert from the house (plan: milestone 6): the alerts controller shows the takeover or banner.
Turbo.StreamActions.alert = function () {
  const detail = { kind: this.getAttribute("kind"), alertId: this.getAttribute("alert-id"), message: this.getAttribute("message") || "",
    cameraUrl: this.getAttribute("camera-url") || "", cameraSnapshot: this.getAttribute("camera-snapshot") || "", deviceUrl: this.getAttribute("device-url") || "" }
  document.dispatchEvent(new CustomEvent("house:alert", { detail: detail }))
}

function context() {
  const params = []
  const routine = document.querySelector("#chores[data-routine]")
  if (routine) params.push("routine=" + encodeURIComponent(routine.dataset.routine))
  const calendar = document.querySelector("#calendar[data-mode]")
  if (calendar) {
    params.push("mode=" + encodeURIComponent(calendar.dataset.mode), "date=" + encodeURIComponent(calendar.dataset.date))
    if (calendar.dataset.person) params.push("person=" + encodeURIComponent(calendar.dataset.person))
  }
  // The person's page carries its id on its own root (a frame navigation keeps the frame element,
  // so an attribute on #people itself would go stale).
  const people = document.querySelector("#people [data-person]")
  if (people && people.dataset.person) params.push("person=" + encodeURIComponent(people.dataset.person))
  const shopping = document.getElementById("shopping")
  if (shopping) {
    if (shopping.dataset.store) params.push("store=" + encodeURIComponent(shopping.dataset.store))
    if (shopping.dataset.drawer === "1") params.push("drawer=1")
  }
  return params
}

export function refresh(ids) {
  ids.forEach((id) => { if (document.getElementById(id)) pending[id] = true })
  clearTimeout(timer)
  timer = setTimeout(flush, 0)
}

function flush() {
  const ids = Object.keys(pending)
  pending = {}
  if (!ids.length) return
  const query = ids.map((id) => "ids[]=" + encodeURIComponent(id)).concat(context()).join("&")
  fetch("/pieces?" + query, { headers: { "Accept": "text/vnd.turbo-stream.html", "X-Page-Token": pageToken }, credentials: "same-origin" })
    .then((r) => r.ok ? r.text() : "")
    .then((html) => { if (html) Turbo.renderStreamMessage(html) })
    .catch(() => {})
}

// Reconnect: the stream source flips its `connected` attribute. After a drop, refresh what the
// active view shows (the Today cards count as part of Today).
const VIEW_PIECES = {
  home: ["today-hero", "today-lanes", "today-agenda", "today-chores", "today-shopping", "today-status", "today-presence"],
  calendar: ["calendar"], tasks: ["chores"], shopping: ["shopping", "shopping-side"], people: ["people"],
  control: ["control-sum", "control-scenes", "control-rooms", "control-climate", "control-media"]
}
let wasConnected = null
function watchCable() {
  const source = document.querySelector("turbo-cable-stream-source")
  if (!source) return
  const check = () => {
    const connected = source.hasAttribute("connected")
    if (wasConnected === false && connected) {
      const stage = document.getElementById("stage")
      const view = stage ? stage.dataset.view : "home"
      refresh(VIEW_PIECES[view] || [])
    }
    wasConnected = connected
  }
  new MutationObserver(check).observe(source, { attributes: true, attributeFilter: ["connected"] })
  check()
}
if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", watchCable)
else watchCable()
