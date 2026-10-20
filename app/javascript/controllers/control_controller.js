import { Controller } from "@hotwired/stimulus"

// Home control chrome (ui-spec §1.6): summary cards open the Lights / Security sheets or pulse
// the climate / media panels; camera tiles open the camera sheet; snapshot ages tick 1..20 s.
export default class extends Controller {
  static targets = ["age"]
  static values = { devicesUrl: String }

  connect() { this.age = 4 }

  sheet() {
    const layer = document.querySelector("#sheetLayer")
    return layer && this.application.getControllerForElementAndIdentifier(layer, "sheet")
  }

  summary(e) {
    const kind = e.currentTarget.dataset.sum
    if (kind === "lights" || kind === "security") {
      const s = this.sheet()
      if (s) s.open(this.devicesUrlValue + "?kind=" + kind)
      return
    }
    const target = this.element.querySelector(kind === "climate" ? "#control-climate" : "#control-media")
    if (!target) return
    target.classList.add("is-pulse")
    setTimeout(() => target.classList.remove("is-pulse"), 900)
  }

  camera(e) {
    const s = this.sheet()
    if (s) s.open(e.currentTarget.dataset.url)
  }

  shown(e) {
    if (e.target.id === "view-control") this.age = 4
  }

  second() {
    const view = this.element.closest(".view")
    if (view && !view.classList.contains("is-active")) return
    this.age = this.age >= 20 ? 1 : this.age + 1
    if (this.age === 1) this.refreshLive()
    Array.prototype.forEach.call(document.querySelectorAll("[data-control-target=age]"), (el) => { el.textContent = this.age + "s ago" })
  }

  // Mapped cameras' images come through the snapshot proxy; a new query string fetches a fresh one.
  refreshLive() {
    Array.prototype.forEach.call(document.querySelectorAll("img[data-live]"), (img) => {
      const base = img.getAttribute("src").split("?")[0]
      img.setAttribute("src", base + "?t=" + Date.now())
    })
  }
}
