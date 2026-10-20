import { Controller } from "@hotwired/stimulus"
import * as clock from "dashboard/clock"
import * as fmt from "dashboard/time"

// The stage shell (ui-spec §0): hash router over the warm views, rail taps on pointerdown, the
// 1 s tick that every clock and countdown listens to, display modes (day / ambient / night /
// nightdash), the idle machine, and the keyboard shortcuts. Other controllers talk to it through
// DOM events on the stage ("shell:second", "shell:minute", "shell:mode", "shell:view") and call
// it through `window.shell` for the few imperative hooks (go, toast, closeSheet).
const VIEWS = ["home", "calendar", "tasks", "shopping", "photos", "control", "people"]

export default class extends Controller {
  static targets = ["clockTime", "clockAmpm"]
  static values = {
    now: Number, offset: Number, idleHome: { type: Number, default: 60 }, idleAmbient: { type: Number, default: 120 },
    layout: { type: String, default: "frame" }, clock: { type: String, default: "12" },
    // The screen's settings (plan: per-screen settings): the view it starts on and idles back to,
    // its night hours [from, to) wrapping midnight (equal = never), the hour it reloads itself.
    view: { type: String, default: "home" }, nightFrom: { type: Number, default: 22 }, nightTo: { type: Number, default: 6 }, reloadHour: { type: Number, default: -1 }
  }

  connect() {
    clock.setBase(this.nowValue, this.offsetValue)
    fmt.setClockFormat(this.clockValue)
    window.shell = this
    this.current = null
    this.mode = "day"
    this.idleSeconds = 0
    this.lastMinute = -1

    this.onHash = () => this.go(location.hash.slice(1))
    this.onKey = (e) => this.key(e)
    this.onDown = () => this.resetIdle()
    this.onClick = (e) => this.delegateGo(e)
    window.addEventListener("hashchange", this.onHash)
    document.addEventListener("keydown", this.onKey)
    document.addEventListener("pointerdown", this.onDown, true)
    this.element.addEventListener("click", this.onClick)

    this.go(this.startView())
    this.booted = false
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
    this.element.setAttribute("data-shell-ready", "")
    this.dispatch("ready")
    if (this.frame) this.tipTimer = setTimeout(() => this.tip(), 1200)
  }

  // The frame is a kiosk with a fixed URL, so a cold start lands on its default view; a reload
  // (a setting changed elsewhere, the nightly reload) keeps the view the hash names, as the app
  // always does.
  startView() {
    const hash = location.hash.slice(1)
    if (this.frame && !this.reloaded()) return this.viewValue
    return hash || this.viewValue
  }

  reloaded() {
    const nav = performance.getEntriesByType && performance.getEntriesByType("navigation")[0]
    return !!nav && nav.type === "reload"
  }

  // The wall frame (fixed stage, pointerdown taps, idle machine, modes, demo drawer) or the app
  // on a phone or desktop, where those stay off (plan: Small screens).
  get frame() { return this.layoutValue !== "app" }

  // Startup tip (ui-spec §0): where the demo drawer hides.
  tip() {
    const tpl = document.getElementById("tpl-tip"), box = document.getElementById("toasts")
    if (!tpl || !box || box.children.length) return
    box.appendChild(tpl.content.firstElementChild.cloneNode(true))
  }

  disconnect() {
    clearInterval(this.timer)
    clearTimeout(this.tipTimer)
    window.removeEventListener("hashchange", this.onHash)
    document.removeEventListener("keydown", this.onKey)
    document.removeEventListener("pointerdown", this.onDown, true)
    this.element.removeEventListener("click", this.onClick)
    if (window.shell === this) window.shell = null
  }

  // ---------------------------------------------------------------- router
  go(name) {
    if (VIEWS.indexOf(name) < 0) name = "home"
    const from = this.current
    if (from === name) {
      if (location.hash !== "#" + name) history.replaceState(null, "", "#" + name)
      return
    }
    if (from) this.viewElement(from).dispatchEvent(new CustomEvent("view:hide", { bubbles: true }))
    this.views.forEach((v) => v.classList.toggle("is-active", v.dataset.view === name))
    this.railItems.forEach((b) => b.classList.toggle("is-active", b.dataset.go === name))
    this.current = name
    this.element.dataset.view = name
    this.viewElement(name).dispatchEvent(new CustomEvent("view:show", { bubbles: true, detail: { from } }))
    if (location.hash !== "#" + name) history.replaceState(null, "", "#" + name)
    this.dispatch("view", { detail: { name, from } })
  }

  railDown(e) {
    if (!this.frame) return
    const b = e.target.closest("[data-go]")
    if (b && e.button === 0) this.go(b.dataset.go)
  }

  // Keyboard "clicks" (detail === 0) still work; pointer clicks were handled on pointerdown. On
  // the app layout every click navigates (ui-spec §5: click, not pointerdown, on phones).
  railClick(e) {
    const b = e.target.closest("[data-go]")
    if (b && (e.detail === 0 || !this.frame)) this.go(b.dataset.go)
  }

  // Anything in a view with data-go (hero, cards, "+N more") navigates on click.
  delegateGo(e) {
    if (e.target.closest("#rail")) return
    const b = e.target.closest("[data-go]")
    if (b) this.go(b.dataset.go)
  }

  get views() { return Array.prototype.slice.call(this.element.querySelectorAll(".view")) }
  get railItems() { return Array.prototype.slice.call(this.element.querySelectorAll(".rail-item")) }
  viewElement(name) { return this.element.querySelector("#view-" + name) }

  // ---------------------------------------------------------------- time
  tick() {
    const now = clock.wall()
    this.dispatch("second", { detail: { now } })
    if (fmt.minutes(now) !== this.lastMinute) {
      this.lastMinute = fmt.minutes(now)
      this.clockTimeTarget.textContent = fmt.time(now, false)
      this.clockAmpmTarget.textContent = fmt.ampm(now)
      this.dispatch("minute", { detail: { now } })
      if (this.booted) this.hourly(now)
      this.booted = true
    }
    this.idleTick()
  }

  isNight() {
    const h = fmt.hours(clock.wall()), from = this.nightFromValue, to = this.nightToValue
    if (from === to) return false
    return from < to ? (h >= from && h < to) : (h >= from || h < to)
  }

  // On the minute, after the first: night ends with the night hours instead of sticking until
  // touched, ambient becomes night when they begin, and at the reload hour the frame reloads
  // itself onto its default view (plan: nightly reload keeps the old WebView healthy).
  hourly(now) {
    if (!this.frame) return
    if (this.reloadHourValue >= 0 && fmt.hours(now) === this.reloadHourValue && fmt.minutes(now) === 0) return this.nightlyReload()
    if (this.mode === "night" && !this.isNight()) { this.go(this.viewValue); this.setMode("day") }
    else if (this.mode === "ambient" && this.isNight()) this.setMode("night")
  }

  nightlyReload() {
    history.replaceState(null, "", "#" + this.viewValue)
    location.reload()
  }

  // ---------------------------------------------------------------- modes + idle
  setMode(mode) {
    if (!this.frame && mode !== "day") return
    this.mode = mode
    this.element.dataset.mode = mode
    this.resetIdle()
    this.dispatch("mode", { detail: { mode } })
  }

  idleTick() {
    if (!this.frame) return
    this.idleSeconds++
    const blocked = this.element.querySelector("#takeover").classList.contains("is-open")
    if (this.mode === "nightdash" && this.idleSeconds >= 20) { this.setMode("night"); return }
    if (this.mode !== "day" || blocked) return
    if (this.idleSeconds === this.idleHomeValue && this.current !== this.viewValue) { this.closeSheet(); this.go(this.viewValue) }
    if (this.idleSeconds >= this.idleAmbientValue) {
      this.closeSheet()
      this.go(this.viewValue)
      this.setMode(this.isNight() ? "night" : "ambient")
    }
  }

  resetIdle() { this.idleSeconds = 0 }

  setIdle(home, ambient) {
    this.idleHomeValue = home
    this.idleAmbientValue = ambient
  }

  // ---------------------------------------------------------------- hooks other controllers implement
  closeSheet() { this.dispatch("close-sheet") }
  openDemo() { this.dispatch("open-demo") }
  closeDemo() { this.dispatch("close-demo") }

  key(e) {
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return
    const k = e.key.toLowerCase()
    if (!this.frame && "dan".indexOf(k) > -1) return
    if (k === "d") this.dispatch("toggle-demo")
    if (k === "a") this.setMode("ambient")
    if (k === "n") this.setMode("night")
    if (k === "escape") { this.closeDemo(); this.closeSheet() }
    if (k >= "1" && k <= "7") this.go(VIEWS[+k - 1])
  }
}
