import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {

  static targets = ["menu", "checkbox"]

  connect() {
    const urlParams = new URLSearchParams(window.location.search);
    const slug = urlParams.get('slug');
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
    if(this.menuTarget.classList.contains('toggled')) {
      this.menuTarget.classList.remove('toggled');
    }
    else {
      this.menuTarget.classList.add('toggled');
    }
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove('toggled');
      if(this.checkboxTarget){
        this.checkboxTarget.checked = false;
      }
    }
  }
}