import { Controller } from "@hotwired/stimulus"
import * as clock from "dashboard/clock"
import * as fmt from "dashboard/time"

// The demo drawer (ui-spec §1.9). Time presets and calendar modes are forms (the server keeps
// them in the session and the page reloads); modes, fast idle and alerts act right here.
export default class extends Controller {
  static targets = ["panel", "fastIdle", "now"]

  open() {
    this.nowTarget.textContent = fmt.time(clock.wall())
    this.fastIdleTarget.textContent = window.shell && window.shell.idleHomeValue < 60 ? "Idle: fast ✓" : "Idle: fast"
    this.element.classList.add("is-open")
  }

  close() { this.element.classList.remove("is-open") }

  toggle() { this.element.classList.contains("is-open") ? this.close() : this.open() }

  backdrop(e) { if (e.target === this.element) this.close() }

  setMode(e) {
    this.close()
    if (window.shell) window.shell.setMode(e.currentTarget.dataset.mode)
  }

  fastIdle() {
    if (!window.shell) return
    const fast = window.shell.idleHomeValue >= 60
    window.shell.setIdle(fast ? 8 : 60, fast ? 15 : 120)
    this.open()
  }

  alert(e) {
    this.close()
    document.dispatchEvent(new CustomEvent("demo:alert", { detail: { kind: e.currentTarget.dataset.alert } }))
  }
}
