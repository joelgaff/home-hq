import { Controller } from "@hotwired/stimulus"

// Press-and-hold (ui-spec §0): `.is-holding` while pressed, "hold:done" after `ms`, "hold:cancel"
// on an early release (used for "keep holding" hints). `--hold` is set for CSS progress rings.
export default class extends Controller {
  static values = { ms: { type: Number, default: 700 }, enabled: { type: Boolean, default: true } }

  connect() {
    this.element.style.setProperty("--hold", this.msValue + "ms")
    this.timer = null
    this.onDown = (e) => this.down(e)
    this.onUp = (e) => this.cancel(e)
    this.element.addEventListener("pointerdown", this.onDown)
    this.element.addEventListener("pointerup", this.onUp)
    this.element.addEventListener("pointerleave", this.onUp)
    this.element.addEventListener("pointercancel", this.onUp)
  }

  disconnect() {
    clearTimeout(this.timer)
    this.element.removeEventListener("pointerdown", this.onDown)
    this.element.removeEventListener("pointerup", this.onUp)
    this.element.removeEventListener("pointerleave", this.onUp)
    this.element.removeEventListener("pointercancel", this.onUp)
  }

  down() {
    if (!this.enabledValue) return
    this.element.classList.add("is-holding")
    this.timer = setTimeout(() => {
      this.timer = null
      this.element.classList.remove("is-holding")
      this.dispatch("done")
    }, this.msValue)
  }

  cancel(e) {
    if (!this.timer) return
    clearTimeout(this.timer)
    this.timer = null
    this.element.classList.remove("is-holding")
    if (e.type === "pointerup") this.dispatch("cancel")
  }
}
