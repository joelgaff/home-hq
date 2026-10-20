import { Controller } from "@hotwired/stimulus"
import { patch } from "dashboard/request"

// The Photos view chrome (ui-spec §1.5) over the slideshow controller: prev/next, loud
// captions, the layout toggle and the favourite button (optimistic: the heart flips at once and
// the pool entry is marked so it comes round twice from the next refill).
export default class extends Controller {
  static targets = ["fav"]
  static outlets = ["slideshow"]
  static values = { url: String }

  prev() { if (this.hasSlideshowOutlet) this.slideshowOutlet.prev() }
  next() { if (this.hasSlideshowOutlet) this.slideshowOutlet.next() }

  loud() { this.element.classList.toggle("is-loud") }

  layout(e) {
    const layout = e.currentTarget.dataset.layout
    Array.prototype.forEach.call(this.element.querySelectorAll("[data-layout]"), (b) => b.classList.toggle("is-on", b === e.currentTarget))
    if (this.hasSlideshowOutlet) this.slideshowOutlet.setLayout(layout)
  }

  changed() { this.heart() }

  heart() {
    const slide = this.hasSlideshowOutlet && this.slideshowOutlet.current
    const on = !!(slide && slide.photos[0].favorite)
    this.favTarget.classList.toggle("is-on", on)
  }

  fav() {
    const slide = this.hasSlideshowOutlet && this.slideshowOutlet.current
    if (!slide) return
    const photo = slide.photos[0]
    photo.favorite = !photo.favorite
    this.slideshowOutlet.photosValue.forEach((p) => { if (p.id === photo.id) p.favorite = photo.favorite })
    this.heart()
    patch(this.urlValue.replace(":id", photo.id), { favorite: photo.favorite })
  }
}
