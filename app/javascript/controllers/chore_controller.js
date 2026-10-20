import { Controller } from "@hotwired/stimulus"
import { post, destroy } from "dashboard/request"

// One chore row (ui-spec §1.3). Not done: show the check animation for 350 ms, then post the
// completion (Anyone chores open the "Who did it?" sheet instead). Done: un-complete at once.
// Taps during the animation are ignored. The server answers with Turbo Streams.
export default class extends Controller {
  static values = { completeUrl: String, undoUrl: String, askUrl: String }

  tap(e) {
    e.preventDefault()
    if (this.pending) return
    if (this.undoUrlValue) return destroy(this.undoUrlValue)
    if (this.askUrlValue) return window.shell && document.querySelector("#sheetLayer") && this.ask()
    this.pending = true
    this.element.classList.add("is-checking")
    setTimeout(() => post(this.completeUrlValue), 350)
  }

  ask() {
    const layer = document.querySelector("#sheetLayer")
    const sheet = this.application.getControllerForElementAndIdentifier(layer, "sheet")
    if (sheet) sheet.open(this.askUrlValue)
  }
}
