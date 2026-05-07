import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu", "buttonText", "checkbox", "button"]

  connect() {
    this.setExpanded(this.isOpen());

    if (!this.hasButtonTextTarget) return;

    const urlParams = new URLSearchParams(window.location.search);
    const slug = urlParams.get('slug');

    if (!slug) {
      this.buttonTextTarget.textContent = "All";
      return;
    }

    switch(slug) {
      case 'read':
        this.buttonTextTarget.textContent = "Read";
        break;
      case 'reading':
        this.buttonTextTarget.textContent = "Currently reading";
        break;
      case 'want_to_read':
        this.buttonTextTarget.textContent = "Want to read";
        break;
    }
  }

  toggle() {
    if (!this.hasMenuTarget) return;

    if (this.isOpen()) {
      this.closeMenu();
    } else {
      this.openMenu();
    }
  }

  close() {
    this.closeMenu();
  }

  hide(event) {
    if (!this.hasMenuTarget) return;

    if (!this.element.contains(event.target)) {
      this.closeMenu();
    }
  }

  openMenu() {
    this.menuTarget.classList.add('toggled');
    this.syncCheckbox(true);
    this.setExpanded(true);
  }

  closeMenu() {
    this.menuTarget.classList.remove('toggled');
    this.syncCheckbox(false);
    this.setExpanded(false);
  }

  syncCheckbox(expanded) {
    if (this.hasCheckboxTarget) {
      this.checkboxTarget.checked = expanded;
    }
  }

  setExpanded(expanded) {
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", expanded ? "true" : "false");
    }
  }

  isOpen() {
    return this.hasMenuTarget && this.menuTarget.classList.contains("toggled");
  }
}
