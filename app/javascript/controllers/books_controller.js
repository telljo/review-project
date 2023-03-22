import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

// Connects to data-controller="change"
export default class extends Controller {
  change(event) {
    let isbn = event.target.selectedOptions[0].value

    get(`/books/select?isbn= ${isbn}`,{
      responseKind: "turbo-stream"
    })
  }
}