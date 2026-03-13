import { Controller } from "@hotwired/stimulus"

// Autocomplete shop search for play record form
// Shows favorite shops on focus, marks them with ★
export default class extends Controller {
  static targets = ["input", "hidden", "results", "display"]
  static values = { url: String, favoritesUrl: String }

  connect() {
    this._debounceTimer = null
    this._selectedId = null
  }

  focus() {
    // Already selected or user is typing — don't show favorites
    if (this._selectedId || this.inputTarget.value.trim().length >= 2) return

    const slugs = this._getFavorites()
    if (slugs.length === 0) return

    // Fetch favorite shops and show them
    this._fetchFavorites(slugs)
  }

  search() {
    const query = this.inputTarget.value.trim()

    // Clear selection when user types
    if (this._selectedId) {
      this._selectedId = null
      this.hiddenTarget.value = ""
    }

    if (query.length < 2) {
      // Show favorites if input is empty/short and we have some
      if (query.length === 0) {
        const slugs = this._getFavorites()
        if (slugs.length > 0) {
          this._fetchFavorites(slugs)
          return
        }
      }
      this._hideResults()
      return
    }

    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this._fetch(query), 250)
  }

  select(event) {
    const item = event.currentTarget
    const id = item.dataset.shopId
    const name = item.dataset.shopName
    const pref = item.dataset.shopPrefecture

    this._selectedId = id
    this.hiddenTarget.value = id
    this.inputTarget.value = `${name}（${pref}）`
    this._hideResults()

    // Dispatch event so machine selects can update
    this.dispatch("shopSelected", { detail: { shopId: id }, bubbles: true })
  }

  // Close results when clicking outside
  closeResults(event) {
    if (!this.element.contains(event.target)) {
      this._hideResults()
    }
  }

  // Private

  _getFavorites() {
    try {
      return JSON.parse(localStorage.getItem("favorite_shops") || "[]")
    } catch {
      return []
    }
  }

  async _fetchFavorites(slugs) {
    const url = `${this.urlValue}?favorites=${encodeURIComponent(slugs.join(","))}`
    try {
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return
      const shops = await response.json()
      if (shops.length > 0) {
        this._renderResults(shops, new Set(slugs))
      }
    } catch {
      // Silently fail
    }
  }

  async _fetch(query) {
    const url = `${this.urlValue}?q=${encodeURIComponent(query)}`
    try {
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return
      const shops = await response.json()
      const favSlugs = new Set(this._getFavorites())
      this._renderResults(shops, favSlugs)
    } catch {
      // Silently fail
    }
  }

  _renderResults(shops, favSlugs = new Set()) {
    const container = this.resultsTarget

    if (shops.length === 0) {
      container.innerHTML = `
        <div class="px-3 py-4 text-center text-xs text-muted-foreground">
          該当する店舗が見つかりません
        </div>`
      container.classList.remove("hidden")
      return
    }

    container.innerHTML = shops.map(shop => {
      const isFav = shop.slug ? favSlugs.has(shop.slug) : false
      const star = isFav ? `<span class="text-yellow-500 text-xs shrink-0 mr-1">★</span>` : ""
      return `
      <button type="button"
              class="w-full text-left px-3 py-2.5 hover:bg-secondary transition-colors flex items-center justify-between gap-2 min-h-[44px]"
              data-action="click->shop-autocomplete#select"
              data-shop-id="${shop.id}"
              data-shop-name="${this._escapeHtml(shop.name)}"
              data-shop-prefecture="${this._escapeHtml(shop.prefecture)}">
        <span class="text-sm text-foreground truncate flex items-center">${star}${this._escapeHtml(shop.name)}</span>
        <span class="text-[11px] text-muted-foreground shrink-0">${this._escapeHtml(shop.prefecture)}</span>
      </button>`
    }).join("")

    container.classList.remove("hidden")
  }

  _hideResults() {
    this.resultsTarget.classList.add("hidden")
    this.resultsTarget.innerHTML = ""
  }

  _escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
