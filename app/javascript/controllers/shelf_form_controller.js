import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]

  start() {
    this.element.setAttribute("aria-busy", "true")
    this.statusTarget.setAttribute("role", "status")
    this.statusTarget.textContent = "Saving your shelf choice…"
  }

  finish(event) {
    this.element.removeAttribute("aria-busy")
    if (event.detail.error) {
      this.statusTarget.setAttribute("role", "alert")
      this.statusTarget.textContent = "We couldn't save this book. Your shelf choice is still selected. Try again."
    } else {
      this.statusTarget.textContent = ""
    }
  }
}
