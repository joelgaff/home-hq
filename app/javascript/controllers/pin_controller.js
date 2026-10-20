import { Controller } from "@hotwired/stimulus"

// The PIN pad (plan: gap review): digit keys type into the field, ⌫ deletes, ✓ submits.
export default class extends Controller {
  static targets = ["field", "form"]

  connect() { if (this.hasFieldTarget) this.fieldTarget.focus() }

  key(e) {
    const k = e.currentTarget.dataset.key
    if (k === "✓") return
    e.preventDefault()
    if (k === "⌫") this.fieldTarget.value = this.fieldTarget.value.slice(0, -1)
    else if (this.fieldTarget.value.length < 8) this.fieldTarget.value += k
  }
}
