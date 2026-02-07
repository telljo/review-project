import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["searchInput", "spinner", "search", "form"];
  static values = { frameId: { type: String, default: "book-list" } };

  connect() {
    this._hide = this.hideLoading.bind(this)

    // Hide loading after the frame updates (Turbo renders the response)
    document.addEventListener("turbo:frame-render", this._hide)
    // Fallback: also hide when Turbo finishes loading
    document.addEventListener("turbo:load", this._hide)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-render", this._hide)
    document.removeEventListener("turbo:load", this._hide)
  }

  search() {
    const q = this.searchInputTarget.value?.trim()

    // If you want: don’t show spinner / don’t submit for empty query
    if (!q) {
      this.hideLoading()
      return
    }

    this.showLoading()

    // Debounce so you don’t fire a request on every keystroke
    clearTimeout(this._t)
    this._t = setTimeout(() => {
      // Submit GET form via requestSubmit (works well with Turbo)
      this.formTarget.requestSubmit()
    }, 200)
  }

  showLoading() {
    this.searchTarget.classList.add("visually-hidden");
    this.spinnerTarget.classList.remove("visually-hidden");
  }

  hideLoading(event) {
    if (event?.target?.id && event.target.id !== this.frameIdValue) return;

    this.spinnerTarget.classList.add("visually-hidden");
    this.searchTarget.classList.remove("visually-hidden");
  }
}