import { Controller } from "@hotwired/stimulus"

// Lightweight controller that shows ★ next to favorite shops
// Usage: <span data-controller="favorite-mark" data-favorite-mark-slug-value="shop-slug"></span>
export default class extends Controller {
  static values = { slug: String }

  connect() {
    const favorites = this._getFavorites()
    if (favorites.includes(this.slugValue)) {
      this.element.textContent = "★"
      this.element.classList.add("text-yellow-500")
    } else {
      this.element.remove()
    }
  }

  _getFavorites() {
    try {
      return JSON.parse(localStorage.getItem("favorite_shops") || "[]")
    } catch {
      return []
    }
  }
}
