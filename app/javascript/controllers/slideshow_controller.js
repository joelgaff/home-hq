import { Controller } from "@hotwired/stimulus"
import Slideshow from "dashboard/slideshow"

// Wraps dashboard/slideshow for one stage element. Photos come from the server as JSON; the
// optional caption outlet (a selector) gets the home tile's one-line caption. `active` tells the
// controller whether its view is showing; it only runs while it is.
function esc(s) {
  return String(s == null ? "" : s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]))
}

export default class extends Controller {
  static values = {
    photos: Array, layout: { type: String, default: "auto" }, interval: { type: Number, default: 15000 },
    captions: { type: Boolean, default: true }, captionOutletSelector: String, autostart: { type: Boolean, default: false }
  }

  connect() {
    this.show = new Slideshow(this.element, this.photosValue, {
      layout: this.layoutValue, interval: this.intervalValue, captions: this.captionsValue,
      onChange: (slide) => this.changed(slide)
    })
    this.active = false
    if (this.autostartValue || this.viewIsActive()) this.resume()
  }

  disconnect() { this.show.stop() }

  viewIsActive() {
    const view = this.element.closest(".view")
    return !!(view && view.classList.contains("is-active"))
  }

  resume(e) {
    if (e && e.target.closest && !e.target.contains(this.element)) return
    this.active = true
    this.show.start()
  }

  pause(e) {
    if (e && e.target.closest && !e.target.contains(this.element)) return
    this.active = false
    this.show.stop()
  }

  next() { this.show.next() }
  prev() { this.show.prev() }
  setLayout(layout) { this.show.setLayout(layout) }
  get current() { return this.show.current }

  changed(slide) {
    this.dispatch("change", { detail: { slide } })
    if (!this.hasCaptionOutletSelectorValue) return
    const cap = document.querySelector(this.captionOutletSelectorValue)
    if (!cap) return
    const m = slide.photos[0]
    cap.innerHTML = "<b>" + (m.on_this_day ? "On this day · " : "") + esc(m.kicker) + "</b><span>" + esc(m.place) + "</span>"
  }
}
