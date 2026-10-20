import { Controller } from "@hotwired/stimulus"
import * as clock from "dashboard/clock"
import * as fmt from "dashboard/time"

// Stale-data banner (plan: Offline and stale data). Shown when the page came from the service
// worker's cache (data-offline-since on <body>) or when a request fails while running; it says
// how old the data is, probes the server every few seconds, and clears (reloading a cached
// page) once the network is back.
const PROBE_MS = 10000

export default class extends Controller {
  connect() {
    this.loadedAt = clock.epoch()
    this.fromCache = document.body.dataset.offlineSince || null
    this.onError = () => this.lost()
    this.onOnline = () => this.probe()
    this.onOffline = () => this.lost()
    document.addEventListener("turbo:fetch-request-error", this.onError)
    document.addEventListener("turbo:frame-missing", this.onError)
    document.addEventListener("turbo:frame-load", () => { this.loadedAt = clock.epoch() })
    window.addEventListener("online", this.onOnline)
    window.addEventListener("offline", this.onOffline)
    // A cached page is as old as the moment the server rendered it (the shell's clock base).
    if (this.fromCache) this.lost(+this.element.dataset.shellNowValue || this.loadedAt)
  }

  disconnect() {
    clearInterval(this.timer)
    document.removeEventListener("turbo:fetch-request-error", this.onError)
    document.removeEventListener("turbo:frame-missing", this.onError)
    window.removeEventListener("online", this.onOnline)
    window.removeEventListener("offline", this.onOffline)
  }

  lost(sinceMs) {
    this.showBanner(sinceMs || this.loadedAt)
    if (!this.timer) this.timer = setInterval(() => this.probe(), PROBE_MS)
  }

  probe() {
    fetch("/up", { cache: "no-store" }).then((r) => { if (r.ok) this.restored() }).catch(() => {})
  }

  restored() {
    clearInterval(this.timer)
    this.timer = null
    if (this.fromCache) { location.reload(); return }
    this.hideBanner()
  }

  showBanner(sinceMs) {
    const box = document.getElementById("banners"), tpl = document.getElementById("tpl-offline")
    if (!box || !tpl || box.querySelector(".banner--offline")) return
    const b = tpl.content.firstElementChild.cloneNode(true)
    b.querySelector("[data-connection-since]").textContent = fmt.time(this.wallAt(sinceMs))
    box.prepend(b)
    requestAnimationFrame(() => b.classList.add("is-in"))
  }

  // The page's own UTC offset: this controller connects before the shell hands the clock its
  // base, so on a cached page the clock would still say UTC.
  wallAt(ms) {
    const offset = this.element.dataset.shellOffsetValue
    return offset === undefined ? clock.wallAt(ms) : new Date(ms + +offset * 60000)
  }

  hideBanner() {
    const b = document.querySelector("#banners .banner--offline")
    if (b) b.remove()
  }
}
