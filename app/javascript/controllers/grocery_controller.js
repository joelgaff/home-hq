import { Controller } from "@hotwired/stimulus"
import { patch } from "dashboard/request"

// One shopping row (ui-spec §1.4). Check: strikethrough + a toast with Undo at once, the
// check itself is sent after 1.2 s unless the row is tapped again or Undo is pressed. Quantity
// buttons patch the row. A row that arrives flashing scrolls into view.
const PENDING_MS = 1200

export default class extends Controller {
  static targets = ["toast"]
  static values = { checkUrl: String, qtyUrl: String }

  connect() {
    if (this.element.classList.contains("is-flash")) {
      if (this.element.scrollIntoView) this.element.scrollIntoView({ block: "nearest" })
      setTimeout(() => this.element.classList.remove("is-flash"), 1200)
    }
  }

  disconnect() { clearTimeout(this.timer) }

  check() {
    if (this.timer) return this.cancel()
    this.element.classList.add("is-checking")
    this.showToast()
    this.timer = setTimeout(() => { this.timer = null; patch(this.checkUrlValue) }, PENDING_MS)
  }

  cancel() {
    clearTimeout(this.timer)
    this.timer = null
    this.element.classList.remove("is-checking")
    if (this.toastEl) this.toastEl.remove()
    this.toastEl = null
  }

  showToast() {
    const box = document.getElementById("toasts")
    if (!box || !this.hasToastTarget) return
    box.innerHTML = ""
    const node = this.toastTarget.content.firstElementChild.cloneNode(true)
    box.appendChild(node)
    this.toastEl = node
    const undo = node.querySelector("[data-toast-undo]")
    if (undo) undo.addEventListener("click", () => this.cancel())
  }

  qty(e) {
    const delta = +e.currentTarget.dataset.delta
    const num = this.element.querySelector(".s-qty .num")
    if (num) num.textContent = Math.max(1, (+num.textContent || 1) + delta)
    patch(this.qtyUrlValue, { delta })
  }
}
