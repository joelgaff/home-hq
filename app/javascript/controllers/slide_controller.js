import { Controller } from "@hotwired/stimulus"
import { patch } from "dashboard/request"

// Slide-to-confirm for the garage (ui-spec §1.6): drag the knob to the end to start the door
// moving; the mock bridge finishes the move four seconds later (Home Assistant will push the
// real state instead).
const MOVE_MS = 4000

export default class extends Controller {
  static targets = ["knob", "fill"]
  static values = { url: String, moving: String, final: String }

  down(e) {
    this.sx = e.clientX
    const track = this.element.getBoundingClientRect(), knob = this.knobTarget.getBoundingClientRect()
    this.max = track.width - knob.width - 8
    this.scale = this.stageScale()
    try { this.knobTarget.setPointerCapture(e.pointerId) } catch (err) { /* older WebViews */ }
  }

  move(e) {
    if (this.sx == null) return
    const x = Math.max(0, Math.min(this.max / this.scale, (e.clientX - this.sx) / this.scale))
    this.knobTarget.style.transform = "translateX(" + x + "px)"
    this.fillTarget.style.width = (x + 76) + "px"
    this.x = x
  }

  up() {
    if (this.sx == null) return
    this.sx = null
    if (this.x >= this.max / this.scale - 6) {
      if (window.shell) window.shell.closeSheet()
      patch(this.urlValue, { state: this.movingValue })
      setTimeout(() => patch(this.urlValue, { state: this.finalValue }), MOVE_MS)
    } else {
      this.knobTarget.style.transform = ""
      this.fillTarget.style.width = ""
    }
  }

  // The stage may be scaled down on a desktop preview; pointer deltas are in screen pixels.
  stageScale() {
    const stage = document.getElementById("stage")
    return stage ? stage.getBoundingClientRect().width / 1280 : 1
  }
}
