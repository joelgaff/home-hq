// Photo slideshow (ui-spec §1.5), shared by the Photos view, ambient mode and the home tile.
// Takes the server's pool (favourites twice, on-this-day first; see Household::Photos) and
// picks layouts: portrait → pair with a same-album portrait else polaroid; landscape → every
// 5th slide a collage, the one after a polaroid, else cover. No crossfades or Ken Burns (tablet).
function shuffle(a) {
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1)), t = a[i]
    a[i] = a[j]
    a[j] = t
  }
  return a
}

function esc(s) {
  return String(s == null ? "" : s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]))
}

function caption(ps, size) {
  const m = ps[0]
  return '<div class="cap cap--' + (size || "l") + '">' +
    '<div class="cap-kicker">' + (m.on_this_day ? "<b>On this day</b> · " : "") + esc(m.kicker) + " · " + esc(m.place) + "</div>" +
    '<div class="cap-date serif">' + esc(ps.length > 1 ? m.month_year : m.date) + "</div>" +
    "</div>"
}

function still(p) {
  return '<div class="kb kb--still"><img src="' + esc(p.url) + '" alt=""></div>'
}

const BUILD = {
  cover(ps, o) {
    const p = ps[0]
    if (p.portrait) {
      return '<div class="slide slide--fit"><img class="blurfill" src="' + esc(p.small) + '" alt=""><img class="fitimg" src="' + esc(p.url) + '" alt="">' + (o.captions ? caption(ps) : "") + "</div>"
    }
    return '<div class="slide slide--cover">' + still(p) + (o.captions ? caption(ps) : "") + "</div>"
  },
  pair(ps, o) {
    return '<div class="slide slide--pair"><div class="pane">' + still(ps[0]) + '</div><div class="pane">' + still(ps[1]) + "</div>" + (o.captions ? caption(ps, "m") : "") + "</div>"
  },
  collage(ps, o) {
    return '<div class="slide slide--collage"><div class="pane pane--a">' + still(ps[0]) + '</div><div class="pane pane--b">' + still(ps[1]) + '</div><div class="pane pane--c">' + still(ps[2]) + "</div>" + (o.captions ? caption(ps, "m") : "") + "</div>"
  },
  polaroid(ps) {
    const p = ps[0], rot = (Math.random() * 5 - 2.5).toFixed(1)
    return '<div class="slide slide--polaroid"><img class="blurfill" src="' + esc(p.small) + '" alt="">' +
      '<figure class="polaroid polaroid--' + (p.portrait ? "p" : "l") + '" style="transform:rotate(' + rot + 'deg)"><div class="polaroid-img"><img src="' + esc(p.url) + '" alt=""></div>' +
      '<figcaption class="serif"><i>' + esc(p.place) + ", " + esc(p.month_year) + "</i></figcaption></figure></div>"
  }
}

export default class Slideshow {
  constructor(el, photos, opts) {
    this.el = el
    this.photos = photos
    this.o = Object.assign({ layout: "auto", interval: 15000, captions: true, onChange: null }, opts || {})
    this.queue = []
    this.history = []
    this.count = 0
    this.timer = null
    this.current = null
  }

  refill() {
    // The pool arrives on-this-day first; keep that, shuffle the rest.
    const first = this.photos.filter((p) => p.on_this_day), rest = this.photos.filter((p) => !p.on_this_day)
    this.queue = shuffle(first.slice()).concat(shuffle(rest.slice()))
  }

  take(pred) {
    if (!this.queue.length) this.refill()
    for (let i = 0; i < this.queue.length; i++) if (!pred || pred(this.queue[i])) return this.queue.splice(i, 1)[0]
    return null
  }

  pick() {
    let layout = this.o.layout
    const n = this.count++
    let first = this.take()
    if (!first) return null
    const sibling = (pred) => this.take(pred) || this.photos.filter((x) => x.id !== first.id && pred(x))[0]
    if (layout === "auto") {
      if (first.portrait) layout = this.photos.some((x) => x.id !== first.id && x.album === first.album && x.portrait) ? "pair" : "polaroid"
      else layout = n % 5 === 3 ? "collage" : n % 5 === 4 ? "polaroid" : "cover"
    }
    let ps = [first]
    if (layout === "pair") {
      if (!first.portrait) { first = sibling((x) => x.portrait) || first; ps = [first] }
      const partner = sibling((x) => x.id !== first.id && x.portrait && x.album === first.album) || sibling((x) => x.id !== first.id && x.portrait)
      if (partner) ps.push(partner); else layout = "cover"
    }
    if (layout === "collage") {
      const b = sibling((x) => x.id !== first.id), c = sibling((x) => ps.indexOf(x) < 0 && x !== b)
      if (b && c) ps.push(b, c); else layout = "cover"
    }
    return { layout, photos: ps }
  }

  render(slide) {
    this.current = slide
    const wrap = document.createElement("div")
    wrap.innerHTML = BUILD[slide.layout](slide.photos, this.o)
    const node = wrap.firstChild
    node.style.opacity = "0"
    Array.prototype.forEach.call(node.querySelectorAll("img"), (im) => {
      im.addEventListener("error", () => im.classList.add("is-broken"))
    })
    const old = Array.prototype.slice.call(this.el.children)
    this.el.appendChild(node)
    const first = node.querySelector("img:not(.blurfill)")
    let shown = false
    const show = () => {
      if (shown) return
      shown = true
      node.classList.add("is-in")
      node.style.opacity = ""
      old.forEach((o) => o.remove())
    }
    // Wait (at most 2.5 s) for the image so the swap never shows a blank frame.
    if (first && !first.complete) { first.addEventListener("load", show); first.addEventListener("error", show); setTimeout(show, 2500) }
    else show()
    if (this.o.onChange) this.o.onChange(slide)
  }

  next() {
    const s = this.pick()
    if (!s) return
    if (this.current) this.history.push(this.current)
    this.render(s)
    this.restart()
  }

  prev() {
    if (!this.history.length) return
    this.render(this.history.pop())
    this.restart()
  }

  setLayout(l) { this.o.layout = l; this.next() }

  restart() {
    clearInterval(this.timer)
    this.timer = setInterval(() => this.next(), this.o.interval)
  }

  start() { if (!this.current) this.next(); else this.restart() }
  stop() { clearInterval(this.timer); this.timer = null }
}
