// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "dashboard/sync"

// Offline mode: the service worker caches the shell and the last rendered page so the frame can
// boot without the server (plan: Offline and stale data).
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js", { scope: "/" }).catch(() => {})
}
