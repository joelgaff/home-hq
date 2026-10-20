import { Controller } from "@hotwired/stimulus"
import { patch } from "dashboard/request"

// Now playing: play / pause.
export default class extends Controller {
  static values = { url: String }

  toggle() { patch(this.urlValue) }
}
