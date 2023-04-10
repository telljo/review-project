import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["selectBox"]

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 200)
  }

  connect() {
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
    this.selectBoxTarget.style.display = "block"
  }

  handleKeyDown(event) {
    if (event.key === "Escape") {
      this.selectBoxTarget.style.display = "none"
    }
  }
}