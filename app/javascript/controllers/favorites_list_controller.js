import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    const favorites = this.getFavorites()
    if (favorites.length === 0) {
      this.containerTarget.classList.add("hidden")
      return
    }

    // Load favorite shops via fetch
    this.containerTarget.classList.remove("hidden")
    const slugs = favorites.join(",")
    fetch(`/shops/favorites?slugs=${encodeURIComponent(slugs)}`, {
      headers: { "Accept": "text/html" }
    })
      .then(r => r.text())
      .then(html => {
        const list = this.containerTarget.querySelector("[data-favorites-list]")
        if (list && html.trim()) {
          list.innerHTML = html
        }
      })
      .catch(() => {})
  }

  getFavorites() {
    try {
      return JSON.parse(localStorage.getItem("favorite_shops") || "[]")
    } catch {
      return []
    }
  }
}
