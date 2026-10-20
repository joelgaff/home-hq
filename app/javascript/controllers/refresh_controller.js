import { Controller } from "@hotwired/stimulus"
import * as clock from "dashboard/clock"
import * as fmt from "dashboard/time"

// Reloads a Turbo Frame on a schedule: `every` = "minute" | "hour" (on the rollover), and/or
// `at` = an epoch-ms instant after which the content is stale (the hero's next event starting).
// One small patch per reload, pulled by the screen itself (spike rules: no fast streams).
export default class extends Controller {
  static values = { every: String, at: Number, url: String }

  connect() {
    this.onMinute = (e) => this.minute(e.detail.now)
    document.addEventListener("shell:minute", this.onMinute)
    this.reloaded = false
  }

  disconnect() {
    document.removeEventListener("shell:minute", this.onMinute)
  }

  minute(now) {
    const due = (this.everyValue === "minute") ||
      (this.everyValue === "hour" && fmt.minutes(now) === 0) ||
      (this.hasAtValue && this.atValue > 0 && clock.epoch() >= this.atValue && !this.reloaded)
    if (due) this.reload()
  }

  reload() {
    this.reloaded = true
    if (this.element.src) this.element.reload()
    else this.element.src = this.urlValue
  }
}
