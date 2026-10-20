import { Controller } from "@hotwired/stimulus"
import { patch } from "dashboard/request"

// A device tile's gestures (ui-spec §1.6), applied optimistically: the tile changes at once with
// a pending dot, the server's answer replaces it (confirmed) or puts it back (failed, red toast).
// Lights and blinds: tap toggles, a horizontal drag over 10 px dims (the whole tile is the
// slider). Locks: hold 1 s to unlock (progress ring), tap to lock, taps within 800 ms of a hold
// ignored; an early release hints. Garage: tap opens the slide-to-confirm sheet.
const HOLD_MS = 1000

export default class extends Controller {
  static targets = ["state", "hint"]
  static values = { url: String, kind: String, name: String, on: Boolean, level: Number, locked: Boolean, sheetUrl: String }

  connect() {
    this.onDown = (e) => this.down(e)
    this.onMove = (e) => this.move(e)
    this.onUp = (e) => this.up(e)
    this.onCancel = () => this.cancelGesture()
    this.element.addEventListener("pointerdown", this.onDown)
    this.element.addEventListener("pointermove", this.onMove)
    this.element.addEventListener("pointerup", this.onUp)
    this.element.addEventListener("pointerleave", this.onCancel)
    this.element.addEventListener("pointercancel", this.onCancel)
    this.element.style.setProperty("--hold", HOLD_MS + "ms")
  }

  disconnect() {
    clearTimeout(this.holdTimer)
    this.element.removeEventListener("pointerdown", this.onDown)
    this.element.removeEventListener("pointermove", this.onMove)
    this.element.removeEventListener("pointerup", this.onUp)
    this.element.removeEventListener("pointerleave", this.onCancel)
    this.element.removeEventListener("pointercancel", this.onCancel)
  }

  get slider() { return this.kindValue === "light" || this.kindValue === "blind" }

  down(e) {
    if (e.button !== 0) return
    this.sx = e.clientX
    this.dragging = false
    this.width = this.element.getBoundingClientRect().width
    this.startLevel = this.kindValue === "light" ? (this.onValue ? this.levelValue : 0) : this.levelValue
    try { this.element.setPointerCapture(e.pointerId) } catch (err) { /* older WebViews */ }
    if (this.kindValue === "door_lock" && this.lockedValue) {
      this.element.classList.add("is-holding")
      this.holdTimer = setTimeout(() => {
        this.holdTimer = null
        this.element.classList.remove("is-holding")
        this.lastHold = Date.now()
        this.send({ locked: false })
      }, HOLD_MS)
    }
  }

  move(e) {
    if (this.sx == null || !this.slider) return
    const dx = e.clientX - this.sx
    if (!this.dragging && Math.abs(dx) > 10) { this.dragging = true; this.element.classList.add("is-drag") }
    if (!this.dragging) return
    const level = Math.max(0, Math.min(100, Math.round(this.startLevel + dx / this.width * 100)))
    this.paintLevel(level)
    this.dragLevel = level
  }

  up(e) {
    if (this.sx == null) return
    this.sx = null
    this.element.classList.remove("is-drag")
    if (this.slider) {
      if (this.dragging) {
        const level = this.dragLevel
        if (this.kindValue === "light") this.send(level ? { on: true, level } : { on: false })
        else this.send({ position: level })
      } else if (this.kindValue === "light") {
        const on = !this.onValue
        this.paintLevel(on ? (this.levelValue || 100) : 0)
        this.send({ on, level: this.levelValue || 100 })
      } else {
        const position = this.levelValue > 0 ? 0 : 100
        this.paintLevel(position)
        this.send({ position })
      }
    } else if (this.kindValue === "door_lock") {
      if (this.holdTimer) {
        clearTimeout(this.holdTimer)
        this.holdTimer = null
        this.element.classList.remove("is-holding")
        if (e.type === "pointerup") this.hint()
      } else if (!this.lockedValue && Date.now() - (this.lastHold || 0) > 800) {
        this.send({ locked: true })
      }
    } else if (this.kindValue === "garage_door" && this.hasSheetUrlValue) {
      const layer = document.querySelector("#sheetLayer")
      const sheet = layer && this.application.getControllerForElementAndIdentifier(layer, "sheet")
      if (sheet) sheet.open(this.sheetUrlValue)
    }
  }

  cancelGesture() {
    if (this.holdTimer) { clearTimeout(this.holdTimer); this.holdTimer = null; this.element.classList.remove("is-holding") }
    if (this.sx != null && this.dragging) { this.sx = null; this.element.classList.remove("is-drag") }
  }

  paintLevel(level) {
    this.element.style.setProperty("--lvl", level + "%")
    this.element.classList.toggle("is-on", level > 0)
    if (this.hasStateTarget) this.stateTarget.textContent = this.kindValue === "light" ? (level ? level + "%" : "Off") : (level === 0 ? "Closed" : level === 100 ? "Open" : level + "% open")
  }

  send(body) {
    if (!this.element.querySelector(".pend")) {
      const dot = document.createElement("i")
      dot.className = "pend"
      this.element.appendChild(dot)
    }
    patch(this.urlValue, body)
  }

  hint() {
    const box = document.getElementById("toasts")
    if (!box || !this.hasHintTarget) return
    box.innerHTML = ""
    box.appendChild(this.hintTarget.content.firstElementChild.cloneNode(true))
  }
}
