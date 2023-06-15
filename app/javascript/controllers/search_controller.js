import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["selectBox", "searchBar", "input"]

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
      this.showSelectBox()
    }, 100)
  }

  connect() {
    this.showSelectBox()
    document.addEventListener("click", this.hideSelectBox)
    document.addEventListener("keydown", this.handleKeyDown.bind(this))
    this.inputTarget.addEventListener('focus', this.addBorder);
    this.inputTarget.addEventListener('blur', this.removeBorder);
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
    const searchField = this.element.querySelector(".search__bar-input")
    if(searchField.value.length < 3) {
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

  addBorder = () => {
    this.searchBarTarget.classList.add('has-focus');
  }

  removeBorder = () => {
    this.searchBarTarget.classList.remove('has-focus');
  }
}