import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["selectBox"]

  search() {
    clearTimeout(this.timeout)
    this.showSelectBox()
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 200)
  }

  connect() {
    this.showSelectBox()
    document.addEventListener("click", this.hideSelectBox)
    document.addEventListener("keydown", this.handleKeyDown.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.hideSelectBox)
    document.removeEventListener("keydown", this.handleKeyDown.bind(this))
  }

  hideSelectBox = (event) => {
    if (!this.element.contains(event.target)) {
      this.selectBoxTarget.style.display = "none"
    }
  }

  showSelectBox = () => {
    const searchField = this.element.querySelector(".search__bar")
    if(searchField.value.length === 0) {
      this.selectBoxTarget.style.display = "none"
    }else {
      this.selectBoxTarget.style.display = "block"
    }
  }

  handleKeyDown(event) {
    if (event.key === "Escape") {
      this.selectBoxTarget.style.display = "none"
    }
  }
}