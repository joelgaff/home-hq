import { Controller } from "@hotwired/stimulus"
import { patch } from "dashboard/request"

// Thermostat buttons (ui-spec §1.6): ±0.5° steps and the mode; the server re-renders the panel.
export default class extends Controller {
  static values = { url: String }

  step(e) { patch(this.urlValue, { delta: +e.currentTarget.dataset.delta }) }
  mode(e) { patch(this.urlValue, { mode: e.currentTarget.dataset.tmode }) }
}
