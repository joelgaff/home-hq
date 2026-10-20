import { Controller } from "@hotwired/stimulus"

// On-device diagnostics (ui-spec §0): ?diag turns the overlay on (remembered in localStorage,
// ?diag=0 turns it off). Shows UA, viewport, frame rate and jank, DOM size, image megapixels,
// heap, and the last tab switches' render + paint times. ?exp=font,shadow,img,has,scale strips
// features for A/B checks on the frame.
const KEY = "hq-diag"

export default class extends Controller {
  connect() {
    const q = location.search.match(/[?&]diag(=([^&]*))?/)
    try {
      if (q) localStorage.setItem(KEY, q[2] === "0" ? "0" : "1")
      if (localStorage.getItem(KEY) !== "1") return
    } catch (e) { if (!q || q[2] === "0") return }
    const em = location.search.match(/[?&]exp=([^&]*)/)
    this.exp = em ? decodeURIComponent(em[1]).split(",") : []
    this.state = { switches: [], frames: [], jank: 0, last: performance.now(), down: null }
    this.applyExperiments()
    this.panel = document.createElement("div")
    this.panel.className = "diag"
    this.element.appendChild(this.panel)
    this.onDown = (e) => { this.state.down = { t: e.timeStamp, now: performance.now() } }
    this.onView = () => this.measure()
    this.element.querySelector("#rail").addEventListener("pointerdown", this.onDown, true)
    this.element.addEventListener("shell:view", this.onView)
    if (this.exp.indexOf("noframe") < 0) requestAnimationFrame((t) => this.frame(t))
    this.ticker = setInterval(() => this.paint(), 500)
  }

  disconnect() {
    clearInterval(this.ticker)
    this.stopped = true
    if (this.panel) this.panel.remove()
  }

  has(x) { return this.exp.indexOf(x) > -1 }

  applyExperiments() {
    let css = ""
    if (this.has("font")) css += "body, .serif, .num, button, input { font-family: sans-serif !important; font-stretch: normal !important; }"
    if (this.has("shadow")) css += "*, *::before, *::after { box-shadow: none !important; text-shadow: none !important; }"
    if (this.has("img")) css += "img { visibility: hidden !important; }"
    if (this.has("has")) {
      Array.prototype.forEach.call(document.styleSheets, (sh) => {
        let rules
        try { rules = sh.cssRules } catch (e) { return }
        for (let i = rules.length - 1; i >= 0; i--) if (rules[i].cssText.indexOf(":has(") > -1 || rules[i].cssText.indexOf("[style*=") > -1) sh.deleteRule(i)
      })
    }
    if (css) { const st = document.createElement("style"); st.textContent = css; document.head.appendChild(st) }
    if (this.has("scale")) this.element.style.transform = "none"
  }

  frame(t) {
    if (this.stopped) return
    const d = t - this.state.last
    this.state.last = t
    this.state.frames.push(d)
    if (d > 50) this.state.jank++
    if (this.state.frames.length > 180) this.state.frames.shift()
    requestAnimationFrame((n) => this.frame(n))
  }

  // Time from the tap to the next painted frame after a view switch.
  measure() {
    const t0 = performance.now(), from = this.state.down && t0 - this.state.down.now < 1000 ? this.state.down.now : null
    document.body.offsetHeight
    const t1 = performance.now()
    requestAnimationFrame(() => requestAnimationFrame(() => {
      const t2 = performance.now()
      this.state.switches.unshift({ view: window.shell ? window.shell.current : "?", layout: t1 - t0, paint: t2 - t1, total: t2 - (from || t0) })
      this.state.switches.length = Math.min(this.state.switches.length, 7)
      this.state.down = null
    }))
  }

  ua() {
    const m = navigator.userAgent.match(/(Firefox|Chrome)\/(\d+)/)
    const a = navigator.userAgent.match(/Android ([\d.]+)/)
    return (m ? m[1] + " " + m[2] : navigator.userAgent.slice(0, 30)) + (a ? " · Android " + a[1] : "")
  }

  paint() {
    const fr = this.state.frames.slice(-90), avg = fr.reduce((a, b) => a + b, 0) / (fr.length || 1)
    const scale = this.element.getBoundingClientRect().width / 1280
    const imgs = Array.prototype.filter.call(document.images, (i) => i.naturalWidth)
    const mpx = imgs.reduce((s, i) => s + i.naturalWidth * i.naturalHeight, 0) / 1e6
    const mem = performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) + " MB" : "n/a"
    const f = (n) => (n == null ? "–" : Math.round(n))
    this.panel.innerHTML =
      "<b>DIAG</b> " + this.ua() + " · exp " + (this.exp.join(",") || "none") + "<br>" +
      "viewport " + innerWidth + "×" + innerHeight + " · dpr " + devicePixelRatio + " · scale " + scale.toFixed(3) + "<br>" +
      "fps " + (1000 / avg).toFixed(0) + " · frame " + avg.toFixed(0) + "ms · jank>50ms " + this.state.jank + "<br>" +
      "dom " + document.getElementsByTagName("*").length + " · imgs " + imgs.length + " (" + mpx.toFixed(1) + " MP) · heap " + mem + "<br>" +
      "<u>view · layout · paint · TOTAL</u><br>" +
      (this.state.switches.length ? this.state.switches.map((s) => s.view + " · " + f(s.layout) + " · " + f(s.paint) + " · <b>" + f(s.total) + "ms</b>").join("<br>") : "tap a tab to measure")
  }
}
