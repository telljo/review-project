import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu", "buttonText", "checkbox"]

  connect() {
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

  toggle(){
    if (!this.hasMenuTarget) return;

    if(this.menuTarget.classList.contains('toggled')) {
      this.menuTarget.classList.remove('toggled');
    }
    else {
      this.menuTarget.classList.add('toggled');
    }
  }

  hide(event) {
    if (!this.hasMenuTarget) return;

    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove('toggled');
      if(this.hasCheckboxTarget){
        this.checkboxTarget.checked = false;
      }
    }
  }
}
