// Turbo Stream requests from Stimulus controllers (the writes behind taps and gestures). The
// answer is rendered by Turbo; the caller never waits on it (optimistic UI).
import { Turbo } from "@hotwired/turbo-rails"
import { pageToken } from "dashboard/sync"

function token() {
  const meta = document.querySelector("meta[name=csrf-token]")
  return meta ? meta.content : ""
}

// Writes while offline are refused with a toast (plan: Offline and stale data); the optimistic
// change on screen is put right by the refresh that follows the reconnect (dashboard/sync.js).
export function offline() {
  return navigator.onLine === false || !!document.querySelector("#banners .banner--offline")
}

function refuse() {
  const box = document.getElementById("toasts"), tpl = document.getElementById("tpl-offline-write")
  if (box && tpl) { box.innerHTML = ""; box.appendChild(tpl.content.firstElementChild.cloneNode(true)) }
  return Promise.resolve(false)
}

export function send(method, url, body) {
  if (offline()) return refuse()
  return fetch(url, {
    method,
    headers: { "X-CSRF-Token": token(), "Accept": "text/vnd.turbo-stream.html", "Content-Type": "application/json", "X-Page-Token": pageToken },
    body: body ? JSON.stringify(body) : undefined,
    credentials: "same-origin"
  }).then((r) => r.text().then((html) => {
    if (r.ok) Turbo.renderStreamMessage(html)
    return r.ok
  }), () => {
    document.dispatchEvent(new Event("turbo:fetch-request-error", { bubbles: true }))
    return refuse()
  })
}

export function post(url, body) { return send("POST", url, body) }
export function patch(url, body) { return send("PATCH", url, body) }
export function destroy(url, body) { return send("DELETE", url, body) }

// Turbo form submissions (Undo, the sheets' forms) obey the same rule; reads still go through.
document.addEventListener("turbo:before-fetch-request", (e) => {
  const method = (e.detail.fetchOptions.method || "GET").toUpperCase()
  if (method !== "GET" && offline()) { e.preventDefault(); refuse() }
})
