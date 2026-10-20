import { Controller } from "@hotwired/stimulus"

// Person picks over stacked panels on a phone (the approved mockup): chores lanes (a tap narrows
// to that person, the same tap again shows everyone) and the "Me" pages (one is always picked).
// Pure client state; a re-render of the frame starts over.
export default class extends Controller {
  static targets = ["lanes"]
  static values = { allowAll: { type: Boolean, default: true } }

  pick(e) {
    const chip = e.target.closest("[data-pick]")
    if (!chip) return
    const same = this.lanesTarget.dataset.picked === chip.dataset.pick
    if (same && !this.allowAllValue) return
    const picked = same ? "" : chip.dataset.pick
    if (picked) this.lanesTarget.dataset.picked = picked
    else delete this.lanesTarget.dataset.picked
    Array.prototype.forEach.call(this.element.querySelectorAll("[data-pick]"), (c) => c.classList.toggle("is-on", c.dataset.pick === picked))
    Array.prototype.forEach.call(this.lanesTarget.querySelectorAll("[data-lane]"), (l) => l.classList.toggle("is-picked", l.dataset.lane === picked))
  }
}
