import { Controller } from "@hotwired/stimulus"
import { patch, post } from "dashboard/request"
import * as clock from "dashboard/clock"
import * as fmt from "dashboard/time"

// Takeovers (doorbell, water leak) and banners (garage open, package) from ui-spec §1.9. A
// takeover forces day mode, closes any sheet, blocks the idle machine, and the doorbell closes
// itself after 45 s. Banners stack; the package one leaves after 9 s.
const DOORBELL_MS = 45000, PACKAGE_MS = 9000

export default class extends Controller {
  static targets = ["body", "doorbell", "leak", "garage", "package", "toastUnlocked", "toastKeepHolding", "toastKeepHoldingValve", "toastAcknowledged"]
  static values = { garageUrl: String, garageSheet: String, cameraUrl: String }

  // From the demo drawer (kind only) or the house (an alert with its id, camera and text).
  show(e) {
    const kind = e.detail.kind
    this.alert = e.detail.alertId ? e.detail : null
    if (kind === "doorbell" || kind === "leak") this.takeover(kind)
    if (kind === "garage") this.garageBanner()
    if (kind === "package") this.packageBanner()
  }

  // The house's alert is acknowledged when the frame dismisses it (plan: milestone 6, the log).
  acknowledgeAlert(alert) {
    if (alert && alert.alertId) patch("/home_alerts/" + alert.alertId + "/acknowledge", {})
  }

  // ---------------------------------------------------------------- takeovers
  takeover(kind) {
    const tpl = kind === "doorbell" ? this.doorbellTarget : this.leakTarget
    this.bodyTarget.innerHTML = ""
    this.bodyTarget.appendChild(tpl.content.firstElementChild.cloneNode(true))
    this.stampTime(this.bodyTarget)
    this.current = this.alert
    if (this.alert) {
      const img = this.bodyTarget.querySelector(".tk-cam img")
      if (img && this.alert.cameraSnapshot) img.src = this.alert.cameraSnapshot
      const sub = this.bodyTarget.querySelector(".tk-sub")
      if (sub && this.alert.message) sub.textContent = this.alert.message
      const unlock = this.bodyTarget.querySelector("[data-unlock]")
      if (unlock && this.alert.deviceUrl) unlock.dataset.deviceUrl = this.alert.deviceUrl
    }
    this.element.className = "takeover is-open " + (kind === "doorbell" ? "takeover--door" : "takeover--alarm")
    if (window.shell) { window.shell.closeSheet(); if (window.shell.mode !== "day") window.shell.setMode("day") }
    clearTimeout(this.timer)
    if (kind === "doorbell") this.timer = setTimeout(() => this.close(), DOORBELL_MS)
  }

  close() {
    clearTimeout(this.timer)
    this.element.className = "takeover"
    this.bodyTarget.innerHTML = ""
    this.acknowledgeAlert(this.current)
    this.current = null
  }

  talk(e) {
    const b = e.currentTarget
    b.classList.toggle("is-on")
    b.querySelector("span").textContent = b.classList.contains("is-on") ? "Talking…" : "Talk"
  }

  // Unlock from the doorbell: the door relocks in two minutes. On the frame the server answers
  // with the PIN pad, so the takeover closes to leave it in view.
  unlock(e) {
    const b = e.currentTarget
    if (b.dataset.deviceUrl) patch(b.dataset.deviceUrl, { locked: false, relock: true })
    b.classList.add("is-on")
    b.querySelector("span").textContent = "Unlocked"
    this.toast(this.toastUnlockedTarget)
    this.close()
  }

  unlockHint() { this.toast(this.toastKeepHoldingTarget) }

  // The water main, through the hub when one is mapped (nothing happens otherwise, as before).
  valve(e) {
    const b = e.currentTarget
    post("/water_valve/close", {})
    b.classList.add("is-on")
    b.querySelector("span").textContent = "Water main closed"
  }

  valveHint() { this.toast(this.toastKeepHoldingValveTarget) }

  acknowledge() {
    this.close()
    this.toast(this.toastAcknowledgedTarget)
  }

  // ---------------------------------------------------------------- banners
  banner(tpl, opts) {
    const box = document.getElementById("banners")
    if (!box) return null
    const b = tpl.content.firstElementChild.cloneNode(true)
    this.stampTime(b)
    const alert = this.alert
    if (alert && alert.message) {
      const text = b.querySelector(".banner-text b")
      const parts = alert.message.split(" · ")
      if (text) text.textContent = parts[0]
      const sub = b.querySelector(".banner-text span")
      if (sub && parts.length > 1) sub.textContent = parts.slice(1).join(" · ")
    }
    box.appendChild(b)
    requestAnimationFrame(() => b.classList.add("is-in"))
    const kill = () => b.remove()
    b.querySelector("[data-x]").addEventListener("click", () => { kill(); this.acknowledgeAlert(alert) })
    const act = b.querySelector("[data-act]")
    if (act) act.addEventListener("click", () => { kill(); this.acknowledgeAlert(alert); opts.onAction() })
    if (opts.ms) setTimeout(kill, opts.ms)
    return b
  }

  garageBanner() {
    // The demo drawer opens the demo garage; the house's banner describes a door already open.
    if (!this.alert && this.garageUrlValue) patch(this.garageUrlValue, { state: "open" })
    this.banner(this.garageTarget, { onAction: () => this.openSheet(this.garageSheetValue) })
  }

  packageBanner() {
    const url = (this.alert && this.alert.cameraUrl) || this.cameraUrlValue
    this.banner(this.packageTarget, { ms: PACKAGE_MS, onAction: () => this.openSheet(url) })
  }

  // ---------------------------------------------------------------- helpers
  openSheet(url) {
    const layer = document.querySelector("#sheetLayer")
    const sheet = layer && this.application.getControllerForElementAndIdentifier(layer, "sheet")
    if (sheet && url) sheet.open(url)
  }

  stampTime(root) {
    const t = fmt.time(clock.wall())
    Array.prototype.forEach.call(root.querySelectorAll("[data-alerts-time]"), (el) => { el.textContent = t })
  }

  toast(tpl) {
    const box = document.getElementById("toasts")
    if (!box) return
    box.innerHTML = ""
    box.appendChild(tpl.content.firstElementChild.cloneNode(true))
  }
}
