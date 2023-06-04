import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="book_select"
export default class extends Controller {
  static targets = ["select"]

  connect() {
    const urlParams = new URLSearchParams(window.location.search)
    const slug = urlParams.get("slug")

    if (slug) {
      const option = this.selectTarget.querySelector(`option[value*=${slug}]`)
      if (option) {
        option.selected = true
      }
    }
  }
}