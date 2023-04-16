import { Controller } from "@hotwired/stimulus"
import { post, destroy } from "@rails/request.js"

export default class extends Controller {
  static targets = ["book"]

  create(event) {
    const isbn = parseInt(event.target.dataset.isbn, 10)
    post(`/books?isbn=${isbn}`,{
      responseKind: "turbo-stream"
    })
  }

  remove(event) {
    const id = parseInt(event.target.dataset.id, 10)
    destroy(`/books?id=${id}`,{
      responseKind: "turbo-stream"
    })
  }
}
