import { Controller } from "@hotwired/stimulus"
import * as clock from "dashboard/clock"
import * as fmt from "dashboard/time"

// Client state of the calendar frame (ui-spec §1.2): the grid's scroll position (auto-scroll
// to now − 170 px, kept across re-renders of the same day, reset on navigation), the swipe
// (|dx| > 90, |dy| < 60, under 700 ms, outside the header) and the now-line moving each minute.
const PX = 72, START = 6
let savedScroll = null

export default class extends Controller {
  static targets = ["scroll", "nowLine"]
  static values = { prev: String, next: String, mode: String }

  connect() {
    this.onDown = (e) => { this.sx = e.clientX; this.sy = e.clientY; this.st = Date.now(); this.inHead = !!e.target.closest(".cal-head") }
    this.onUp = (e) => this.swiped(e)
    this.element.addEventListener("pointerdown", this.onDown)
    this.element.addEventListener("pointerup", this.onUp)
    this.onNav = (e) => { if (e.target.closest("a")) savedScroll = null }
    this.element.addEventListener("click", this.onNav)
    this.placeScroll()
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.onDown)
    this.element.removeEventListener("pointerup", this.onUp)
    this.element.removeEventListener("click", this.onNav)
  }

  rendered() { this.placeScroll() }

  // The view is laid out only while shown (content-visibility), so scrolling has to wait for it;
  // each visit starts again at "now" (ui-spec §1.2).
  shown(e) {
    if (e.target.id !== "view-calendar") return
    savedScroll = null
    this.placeScroll()
  }

  placeScroll() {
    if (!this.hasScrollTarget) return
    const now = clock.wall()
    const y = ((fmt.hours(now) + fmt.minutes(now) / 60) - START) * PX
    this.scrollTarget.scrollTop = savedScroll != null ? savedScroll : Math.max(0, y - 170)
  }

  scrolled() { savedScroll = this.scrollTarget.scrollTop }

  swiped(e) {
    if (this.sx == null) return
    const dx = e.clientX - this.sx, dy = e.clientY - this.sy, dt = Date.now() - this.st
    this.sx = null
    if (Math.abs(dx) > 90 && Math.abs(dy) < 60 && dt < 700 && !this.inHead) this.navigate(dx < 0 ? this.nextValue : this.prevValue)
  }

  navigate(url) {
    savedScroll = null
    this.element.src = url
  }

  minute(e) {
    if (!this.hasNowLineTarget) return
    const now = e.detail.now
    this.nowLineTarget.style.top = (((fmt.hours(now) + fmt.minutes(now) / 60) - START) * PX) + "px"
    this.nowLineTarget.querySelector("span").textContent = fmt.time(now, false)
  }
}
