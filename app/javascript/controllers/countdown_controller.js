import { Controller } from "@hotwired/stimulus"
import * as clock from "dashboard/clock"
import * as fmt from "dashboard/time"

// The hero's big number and leave pill (ui-spec §1.1), ticking locally each minute from the
// server's time: minutes to start under 100, else the start time; "Leave now" (red) at or past
// the leave-by, "Leave in N min" (dark) within 15, plain beyond.
const CAR = '<svg class="i" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 17v2M19 17v2M3 13l2-6h14l2 6v4H3z"/><circle cx="7.5" cy="14" r=".8"/><circle cx="16.5" cy="14" r=".8"/></svg>'

export default class extends Controller {
  static targets = ["count", "pill"]
  static values = { start: Number, leave: Number }

  render() {
    const now = clock.epoch()
    const mins = (this.startValue - now) / 60000
    if (mins < 100) {
      this.countTarget.innerHTML = Math.round(mins) + "<small>min</small>"
    } else {
      const start = clock.wallAt(this.startValue)
      this.countTarget.innerHTML = fmt.time(start, false) + "<small>" + fmt.ampm(start) + "</small>"
    }
    if (!this.hasLeaveValue || !this.leaveValue) return
    const leave = (this.leaveValue - now) / 60000
    this.pillTarget.innerHTML = leave <= 0
      ? '<span class="pill pill--alert"><i class="pulse"></i>Leave now</span>'
      : '<span class="pill' + (leave <= 15 ? " pill--soon" : "") + '">' + CAR + "Leave in " + fmt.mins(leave) + "</span>"
  }
}
