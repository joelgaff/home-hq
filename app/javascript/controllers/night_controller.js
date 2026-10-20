import { Controller } from "@hotwired/stimulus"

// Night mode (ui-spec §1.8): tap → nightdash; the clock block shifts a few pixels each minute.
export default class extends Controller {
  static targets = ["inner"]

  disconnect() { clearInterval(this.shift) }

  mode(e) {
    clearInterval(this.shift)
    if (e.detail.mode === "night") this.shift = setInterval(() => this.nudge(), 60000)
  }

  tap() { if (window.shell) window.shell.setMode("nightdash") }

  nudge() {
    const x = Math.round(Math.random() * 8 - 4), y = Math.round(Math.random() * 8 - 4)
    this.innerTarget.style.transform = "translate(" + x + "px," + y + "px)"
  }
}
