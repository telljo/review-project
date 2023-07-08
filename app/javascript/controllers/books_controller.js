import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

// Connects to data-controller="change"
export default class extends Controller {
  change(event) {
    let book = event.target.selectedOptions[0];
    let isbn = book.getAttribute("isbn");
    let id = book.getAttribute("id");

    let url = `/books/select?isbn=${isbn}`

    if(id != null){
      url += `&id=${id}`
    }

    get(url,{
      responseKind: "turbo-stream"
    })
  }
}