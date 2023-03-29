import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"

export default class extends Controller {
  create(event) {
    const isbn = parseInt(event.target.dataset.isbn, 10)
    post(`/books?isbn=${isbn}`,{
      responseKind: "turbo-stream"
    })
  }
}
