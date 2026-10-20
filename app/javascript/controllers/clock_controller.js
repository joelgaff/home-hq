import { Controller } from "@hotwired/stimulus"
import * as clock from "dashboard/clock"
import * as fmt from "dashboard/time"

// A clock re-rendered from the household wall clock on every minute rollover (Today, ambient,
// night). `long` writes the date as "Wednesday, October 14" in one piece.
export default class extends Controller {
  static targets = ["time", "ampm", "day", "date"]
  static values = { long: Boolean }

  render() {
    const now = clock.wall()
    this.timeTarget.textContent = fmt.time(now, false)
    if (this.hasAmpmTarget) this.ampmTarget.textContent = fmt.ampm(now)
    if (this.hasDayTarget) this.dayTarget.textContent = fmt.day(now)
    if (this.hasDateTarget) this.dateTarget.textContent = (this.longValue ? fmt.day(now) + ", " : "") + fmt.month(now) + " " + fmt.date(now)
  }
}
