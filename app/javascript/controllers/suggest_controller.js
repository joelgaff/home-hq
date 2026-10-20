import { Controller } from "@hotwired/stimulus"
import { post } from "dashboard/request"

// The add box (ui-spec §1.4): typing shows up to five catalogue matches (prefix first, then
// substring) plus "Add '...'" with its guessed category; empty shows the usuals. Enter or a tap
// adds; the server re-renders the list and the side panel.
const PLUS = '<svg class="i" width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>'

function esc(s) {
  return String(s == null ? "" : s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]))
}

export default class extends Controller {
  static targets = ["input", "matches", "usuals"]
  static values = { catalog: Array, addUrl: String }

  typed() { this.render() }

  key(e) {
    if (e.key === "Enter" && this.inputTarget.value.trim()) this.add(this.inputTarget.value)
  }

  tap(e) {
    const b = e.target.closest("[data-add]")
    if (b) this.add(b.dataset.add)
  }

  add(name) {
    const list = document.getElementById("shopping")
    const store = list && list.dataset.store
    this.inputTarget.value = ""
    this.render()
    post(this.addUrlValue, { name: name.trim(), store: store || null, drawer: list && list.dataset.drawer === "1" ? 1 : null })
  }

  onList() {
    try { return JSON.parse(this.usualsTarget.dataset.onList || "{}") } catch (e) { return {} }
  }

  categorize(name) {
    const n = name.toLowerCase().trim()
    const hit = this.catalogValue.find((c) => c[0].toLowerCase() === n) ||
      this.catalogValue.find((c) => { const a = c[0].toLowerCase(); return a.indexOf(n) > -1 || n.indexOf(a) > -1 }) ||
      this.catalogValue.find((c) => n.split(/\s+/).some((w) => w.length > 3 && c[0].toLowerCase().indexOf(w) > -1))
    return hit ? hit[1] : "Other"
  }

  render() {
    const q = this.inputTarget.value.trim().toLowerCase()
    if (!q) {
      this.matchesTarget.hidden = true
      this.usualsTarget.hidden = false
      return
    }
    const on = this.onList()
    const starts = this.catalogValue.filter((c) => c[0].toLowerCase().indexOf(q) === 0)
    const inside = this.catalogValue.filter((c) => c[0].toLowerCase().indexOf(q) > 0)
    const matches = starts.concat(inside).slice(0, 5)
    const exact = matches.some((m) => m[0].toLowerCase() === q)
    const raw = this.inputTarget.value.trim()
    this.matchesTarget.innerHTML = '<div class="label">Suggestions</div><div class="s-ac">' + matches.map((m) =>
      '<button class="s-ac-row" data-add="' + esc(m[0]) + '"><b>' + esc(m[0]) + '</b><span class="label">' + (on[m[0]] ? "On list · ×" + on[m[0]] : esc(m[1])) + "</span>" + PLUS + "</button>"
    ).join("") + (exact ? "" : '<button class="s-ac-row s-ac-row--new" data-add="' + esc(raw) + '"><b>Add “' + esc(raw) + '”</b><span class="label">' + esc(this.categorize(raw)) + "</span>" + PLUS + "</button>") + "</div>"
    this.matchesTarget.hidden = false
    this.usualsTarget.hidden = true
  }
}
