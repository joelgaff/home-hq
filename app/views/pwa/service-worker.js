// Home HQ service worker (plan: Offline and stale data). Runs on the frame's WebView 106 and on
// phones, so: no ES2023+, no top-level await.
//
// - Navigations (the dashboard page): network first; a good answer is copied into the page
//   cache with the time it was fetched. With the network gone, the copy is served with
//   data-offline-since on <body>, which the connection controller turns into the stale banner.
// - Assets (/assets, the importmap's modules, Google Fonts): cache first, refreshed in the
//   background, so the shell boots even when the server is down.
// - Everything else (Turbo Frames, writes, the cable) goes to the network as is.
var VERSION = "hq-v1"
var PAGES = VERSION + "-pages"
var ASSETS = VERSION + "-assets"
var STATIC_HOSTS = ["fonts.googleapis.com", "fonts.gstatic.com"]

// Browser offline emulation does not reach a worker's own fetches, so tests (and a manual check
// on the frame) ask the worker to pretend: postMessage({ type: "hq:simulate-offline", value: true }).
var simulateOffline = false
self.addEventListener("message", function (event) {
  if (event.data && event.data.type === "hq:simulate-offline") simulateOffline = !!event.data.value
})

function network(request) {
  return simulateOffline ? Promise.reject(new Error("simulated offline")) : fetch(request)
}

self.addEventListener("install", function (event) {
  event.waitUntil(self.skipWaiting())
})

// The page that installed the worker was fetched before the worker could see it, so take a
// first copy right away (cookies travel with a same-origin fetch, so it renders signed in).
function cachePage() {
  return fetch("/", { credentials: "same-origin" }).then(function (response) {
    if (!response.ok) return
    return stamp(response).then(function (stamped) {
      return caches.open(PAGES).then(function (cache) { return cache.put("/", stamped) })
    })
  }).catch(function () {})
}

self.addEventListener("activate", function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.filter(function (k) { return k.indexOf(VERSION) !== 0 }).map(function (k) { return caches.delete(k) }))
    }).then(function () { return self.clients.claim() }).then(cachePage)
  )
})

function isAsset(url) {
  if (STATIC_HOSTS.indexOf(url.hostname) > -1) return true
  return url.origin === self.location.origin && (url.pathname.indexOf("/assets/") === 0 || url.pathname === "/icon.png" || url.pathname === "/icon.svg")
}

function stamp(response) {
  var headers = new Headers(response.headers)
  headers.set("x-cached-at", new Date().toISOString())
  return response.clone().text().then(function (body) {
    return new Response(body, { status: response.status, statusText: response.statusText, headers: headers })
  })
}

function withStaleMark(response) {
  var at = response.headers.get("x-cached-at") || ""
  return response.text().then(function (html) {
    var marked = html.replace(/<body([^>]*)>/, '<body$1 data-offline-since="' + at + '">')
    var headers = new Headers(response.headers)
    return new Response(marked, { status: 200, headers: headers })
  })
}

self.addEventListener("fetch", function (event) {
  var request = event.request
  if (request.method !== "GET") return
  var url = new URL(request.url)

  if (request.mode === "navigate") {
    event.respondWith(
      network(request).then(function (response) {
        if (response.ok) {
          var copy = response.clone()
          caches.open(PAGES).then(function (cache) { stamp(copy).then(function (stamped) { cache.put("/", stamped) }) })
        }
        return response
      }).catch(function () {
        return caches.open(PAGES).then(function (cache) { return cache.match("/") }).then(function (cached) {
          if (cached) return withStaleMark(cached)
          return new Response("<!doctype html><title>Home HQ</title><p style='font:20px sans-serif;padding:40px'>Offline, and nothing cached yet.</p>", { status: 503, headers: { "Content-Type": "text/html" } })
        })
      })
    )
    return
  }

  if (isAsset(url)) {
    event.respondWith(
      caches.open(ASSETS).then(function (cache) {
        return cache.match(request).then(function (cached) {
          var refresh = fetch(request).then(function (response) {
            if (response.ok || response.type === "opaque") cache.put(request, response.clone())
            return response
          }).catch(function () { return cached })
          return cached || refresh
        })
      })
    )
  }
})
