import { Controller } from "@hotwired/stimulus"

// Autocomplete shop search for play record form
export default class extends Controller {
  static targets = ["input", "hidden", "results", "display"]
  static values = { url: String }

  connect() {
    this._debounceTimer = null
    this._selectedId = null
  }

  search() {
    const query = this.inputTarget.value.trim()

    // Clear selection when user types
    if (this._selectedId) {
      this._selectedId = null
      this.hiddenTarget.value = ""
    }

    if (query.length < 2) {
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

  async _fetch(query) {
    const url = `${this.urlValue}?q=${encodeURIComponent(query)}`
    try {
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return
      const shops = await response.json()
      this._renderResults(shops)
    } catch (e) {
      // Silently fail
    }
  }

  _renderResults(shops) {
    const container = this.resultsTarget

    if (shops.length === 0) {
      container.innerHTML = `
        <div class="px-3 py-4 text-center text-xs text-muted-foreground">
          該当する店舗が見つかりません
        </div>`
      container.classList.remove("hidden")
      return
    }

    container.innerHTML = shops.map(shop => `
      <button type="button"
              class="w-full text-left px-3 py-2.5 hover:bg-secondary transition-colors flex items-center justify-between gap-2 min-h-[44px]"
              data-action="click->shop-autocomplete#select"
              data-shop-id="${shop.id}"
              data-shop-name="${this._escapeHtml(shop.name)}"
              data-shop-prefecture="${this._escapeHtml(shop.prefecture)}">
        <span class="text-sm text-foreground truncate">${this._escapeHtml(shop.name)}</span>
        <span class="text-[11px] text-muted-foreground shrink-0">${this._escapeHtml(shop.prefecture)}</span>
      </button>
    `).join("")

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
