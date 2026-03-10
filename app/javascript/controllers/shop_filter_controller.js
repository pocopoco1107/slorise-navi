import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "toggleIcon", "toggleText", "count", "total", "checkbox"]

  connect() {
    this.totalCount = this.element.querySelectorAll("[data-shop-card]").length
    this.totalTarget.textContent = this.totalCount
    this.countTarget.textContent = this.totalCount
  }

  toggle() {
    this.panelTarget.classList.toggle("hidden")
    this.toggleIconTarget.classList.toggle("rotate-180")
    const isOpen = !this.panelTarget.classList.contains("hidden")
    this.toggleTextTarget.textContent = isOpen ? "閉じる" : "絞り込み"
  }

  // 統計項目クリックからフィルタを適用
  applyPreset(event) {
    event.preventDefault()
    event.stopPropagation()

    const category = event.currentTarget.dataset.presetCategory
    const value = event.currentTarget.dataset.presetValue
    if (!category || !value) return

    // まず全チェックボックスをクリア
    this.checkboxTargets.forEach(cb => { cb.checked = false })

    // 該当するチェックボックスをONにする
    this.checkboxTargets.forEach(cb => {
      if (cb.dataset.filterCategory === category && cb.value === value) {
        cb.checked = true
      }
    })

    // フィルタパネルを開く
    if (this.panelTarget.classList.contains("hidden")) {
      this.panelTarget.classList.remove("hidden")
      this.toggleIconTarget.classList.add("rotate-180")
      this.toggleTextTarget.textContent = "閉じる"
    }

    // フィルタ適用
    this.apply()

    // フィルタパネルまでスクロール
    this.panelTarget.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }

  apply() {
    const filters = this.#collectFilters()
    const cards = this.element.querySelectorAll("[data-shop-card]")
    let visibleCount = 0

    cards.forEach(card => {
      const visible = this.#matchesFilters(card, filters)
      card.classList.toggle("hidden", !visible)
      if (visible) visibleCount++
    })

    // Hide/show city groups based on visible cards
    const cityGroups = this.element.querySelectorAll("[data-city-group]")
    cityGroups.forEach(group => {
      const visibleCards = group.querySelectorAll("[data-shop-card]:not(.hidden)")
      group.classList.toggle("hidden", visibleCards.length === 0)

      // Update city group count badge
      const badge = group.querySelector("[data-city-count]")
      const totalCards = group.querySelectorAll("[data-shop-card]")
      if (badge) {
        const total = totalCards.length
        const shown = visibleCards.length
        badge.textContent = shown < total ? `${shown}/${total}店` : `${total}店`
      }
    })

    this.countTarget.textContent = visibleCount
    // Highlight count when filtered
    const counter = this.countTarget.closest("[data-filter-counter]")
    if (counter) {
      counter.classList.toggle("text-primary", visibleCount < this.totalCount)
      counter.classList.toggle("font-bold", visibleCount < this.totalCount)
    }
  }

  clear() {
    this.checkboxTargets.forEach(cb => { cb.checked = false })
    this.apply()
  }

  // Private

  #collectFilters() {
    const filters = {}
    this.checkboxTargets.forEach(cb => {
      if (!cb.checked) return
      const category = cb.dataset.filterCategory
      if (!filters[category]) filters[category] = []
      filters[category].push(cb.value)
    })
    return filters
  }

  #matchesFilters(card, filters) {
    // No filters active = show all
    if (Object.keys(filters).length === 0) return true

    // AND across categories, OR within category
    for (const [category, values] of Object.entries(filters)) {
      const cardValue = card.dataset[`filter${this.#capitalize(category)}`] || ""

      if (category === "facilities") {
        // facilities is comma-separated, check if any filter value is included
        const cardFacilities = cardValue.split(",").map(f => f.trim())
        const match = values.some(v => cardFacilities.includes(v))
        if (!match) return false
      } else if (category === "rates") {
        // rates is comma-separated (e.g., "20スロ,5スロ")
        const cardRates = cardValue.split(",").map(r => r.trim())
        const match = values.some(v => cardRates.includes(v))
        if (!match) return false
      } else if (category === "morning") {
        // morning: "yes" means has morning entry
        const hasMorning = cardValue === "yes"
        const match = values.some(v => (v === "yes") === hasMorning)
        if (!match) return false
      } else {
        // exchange, hours: single value match
        const match = values.some(v => cardValue === v)
        if (!match) return false
      }
    }

    return true
  }

  #capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
  }
}
