import { Controller } from "@hotwired/stimulus"

// The single centred modal sheet (ui-spec §0). Content arrives as the "sheet" Turbo Frame; the
// loaded body's data-sheet-class picks the width variant. Scrim, X, Escape and the shell close
// it. Any [data-ev] / [data-more] tap anywhere opens the matching event sheet.
export default class extends Controller {
  static targets = ["frame", "box"]

  connect() {
    this.onClick = (e) => this.delegate(e)
    document.addEventListener("click", this.onClick)
    this.onLoad = () => this.loaded()
    this.frameTarget.addEventListener("turbo:frame-load", this.onLoad)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick)
    this.frameTarget.removeEventListener("turbo:frame-load", this.onLoad)
  }

  delegate(e) {
    const any = e.target.closest("[data-sheet-url]")
    if (any) return this.open(any.dataset.sheetUrl)
    const ev = e.target.closest("[data-ev]")
    if (ev) return this.open("/events/" + ev.dataset.ev)
    const more = e.target.closest("[data-more]")
    if (more) return this.open("/events?ids=" + more.dataset.more)
  }

  // Opens the sheet with the content at `url`; the frame fetches it.
  open(url) {
    this.frameTarget.innerHTML = ""
    this.boxTarget.className = "sheet"
    this.frameTarget.src = url
    this.element.classList.add("is-open")
    this.dispatch("open")
  }

  loaded() {
    const body = this.frameTarget.querySelector("[data-sheet-class]")
    this.boxTarget.className = "sheet " + ((body && body.dataset.sheetClass) || "")
    this.dispatch("load")
  }

  // A form inside the sheet closes it when it is done, unless it asks to stay (the event sheet's
  // people chips: several taps in a row).
  close(e) {
    const form = e && e.detail && e.detail.formSubmission && e.detail.formSubmission.formElement
    if (form && form.hasAttribute("data-sheet-keep")) return
    if (!this.element.classList.contains("is-open")) return
    this.element.classList.remove("is-open")
    this.frameTarget.removeAttribute("src")
    this.frameTarget.innerHTML = ""
    this.dispatch("close")
  }

  get isOpen() { return this.element.classList.contains("is-open") }
}
