import { Controller } from "@hotwired/stimulus"
import { post, destroy } from "@rails/request.js"

export default class extends Controller {
  static targets = ["book"]

  create(event, slug) {
    const isbn = parseInt(event.target.dataset.isbn, 10)
    post(`/books?isbn=${isbn}&slug=${slug}`,{
      responseKind: "turbo-stream"
    })
  }

  addToWantToRead(event) {
    this.create(event, "want_to_read")
  }

  addToCurrentlyReading(event) {
    this.create(event, "reading")
  }

  addToRead(event) {
    this.create(event, "read")
  }

  remove(event) {
    const id = parseInt(event.target.dataset.id, 10)
    destroy(`/books?id=${id}`,{
      responseKind: "turbo-stream"
    })
  }
}
