import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["ratingStar"]

  starClicked(event) {
    const clickedStar = event.target.closest('[data-review-target="ratingStar"]')
    this.highlightStars(clickedStar.dataset.value)
    this.element.querySelector(".rating-value").value = clickedStar.dataset.value;
  }

  highlightStars(rating) {
    this.ratingStarTargets.forEach(star => {
      let starValue = star.dataset.value;
      if (starValue <= rating) {
        star.classList.add("selected");
      } else {
        star.classList.remove("selected");
      }
    })
  }
}
