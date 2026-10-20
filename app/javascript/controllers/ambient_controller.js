import { Controller } from "@hotwired/stimulus"

// Ambient mode (ui-spec §1.8): the slideshow runs only while the mode is on; the info block is
// nudged a few pixels every minute so nothing sits still for hours (burn-in).
export default class extends Controller {
  static targets = ["info"]

  disconnect() { clearInterval(this.shift) }

  mode(e) {
    clearInterval(this.shift)
    const show = this.slideshow()
    if (e.detail.mode === "ambient") {
      if (show) show.resume()
      this.shift = setInterval(() => this.nudge(), 60000)
    } else if (show) {
      show.pause()
    }
  }

  tap() {
    if (!window.shell) return
    window.shell.setMode("day")
    window.shell.go(window.shell.viewValue)
  }

  slideshow() {
    const stage = this.element.querySelector(".amb-stage")
    return stage && this.application.getControllerForElementAndIdentifier(stage, "slideshow")
  }

  nudge() {
    const x = Math.round(Math.random() * 8 - 4), y = Math.round(Math.random() * 8 - 4)
    this.infoTarget.style.transform = "translate(" + x + "px," + y + "px)"
  }
}
