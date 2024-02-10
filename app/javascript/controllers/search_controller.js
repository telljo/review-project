import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["searchInput"]

  search() {
    if(this.searchInputTarget.value.length > 3) {
      clearTimeout(this.timeout)
      this.timeout = setTimeout(() => {
        this.element.requestSubmit()
      }, 1000)
    }
  }
}