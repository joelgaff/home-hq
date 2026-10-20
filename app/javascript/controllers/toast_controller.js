import { Controller } from "@hotwired/stimulus"

// A toast's lifetime: in on the next frame, gone after `ms` (ui-spec §0 "Toasts").
export default class extends Controller {
  static values = { ms: { type: Number, default: 5000 } }

  connect() {
    requestAnimationFrame(() => this.element.classList.add("is-in"))
    this.timer = setTimeout(() => this.element.remove(), this.msValue)
  }

  disconnect() { clearTimeout(this.timer) }
}
