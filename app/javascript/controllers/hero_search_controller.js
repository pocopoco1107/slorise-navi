import { Controller } from "@hotwired/stimulus"

// Real-time autocomplete for hero search (shops & machines)
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String, type: String } // type: "shop" or "machine"

  connect() {
    this._debounceTimer = null
    this._onClickOutside = this._onClickOutside.bind(this)
    document.addEventListener("click", this._onClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this._onClickOutside)
    clearTimeout(this._debounceTimer)
  }

  focus() {
    // Show favorites on focus when input is empty (shop type only)
    if (this.typeValue !== "shop") return
    if (this.inputTarget.value.trim().length >= 1) return

    const slugs = this._getFavorites()
    if (slugs.length === 0) return

    this._fetchFavorites(slugs)
  }

  search() {
    const query = this.inputTarget.value.trim()

    if (query.length < 1) {
      // Show favorites if empty (shop only)
      if (this.typeValue === "shop") {
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
    this._debounceTimer = setTimeout(() => this._fetch(query), 200)
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
        this._renderResults(shops)
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
      const items = await response.json()
      this._renderResults(items)
    } catch {
      // Silently fail
    }
  }

  _renderResults(items) {
    const container = this.resultsTarget

    if (items.length === 0) {
      container.innerHTML = `
        <div class="px-3 py-4 text-center text-xs text-muted-foreground">
          該当する結果が見つかりません
        </div>`
      container.classList.remove("hidden")
      return
    }

    if (this.typeValue === "shop") {
      this._renderShops(items, container)
    } else {
      this._renderMachines(items, container)
    }

    container.classList.remove("hidden")
  }

  _renderShops(shops, container) {
    const favSlugs = new Set(this._getFavorites())
    container.innerHTML = shops.map(shop => {
      const isFav = favSlugs.has(shop.slug)
      const star = isFav ? `<span class="text-yellow-500 text-xs mr-1">★</span>` : ""
      return `
        <a href="/shops/${this._escapeAttr(shop.slug)}"
           class="flex justify-between items-center hover:bg-secondary px-3 py-2.5 transition-colors duration-150 min-h-[44px]">
          <span class="font-medium text-sm text-foreground truncate">${star}${this._escapeHtml(shop.name)}</span>
          <span class="text-xs text-muted-foreground shrink-0 ml-2">${this._escapeHtml(shop.prefecture)}</span>
        </a>`
    }).join("")
  }

  _renderMachines(machines, container) {
    container.innerHTML = machines.map(machine => {
      const badge = machine.display_type
        ? `<span class="text-[10px] font-bold px-1.5 py-0.5 rounded-md bg-secondary text-muted-foreground shrink-0 ml-2">${this._escapeHtml(machine.display_type)}</span>`
        : ""
      return `
        <a href="/machines/${this._escapeAttr(machine.slug)}"
           class="flex justify-between items-center hover:bg-secondary px-3 py-2.5 transition-colors duration-150 min-h-[44px]">
          <span class="font-medium text-sm text-foreground truncate">${this._escapeHtml(machine.name)}</span>
          ${badge}
        </a>`
    }).join("")
  }

  _hideResults() {
    this.resultsTarget.classList.add("hidden")
    this.resultsTarget.innerHTML = ""
  }

  _onClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this._hideResults()
    }
  }

  _getFavorites() {
    try {
      return JSON.parse(localStorage.getItem("favorite_shops") || "[]")
    } catch {
      return []
    }
  }

  _escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }

  _escapeAttr(str) {
    return str.replace(/[&"'<>]/g, c => ({
      "&": "&amp;", '"': "&quot;", "'": "&#39;", "<": "&lt;", ">": "&gt;"
    })[c])
  }
}
