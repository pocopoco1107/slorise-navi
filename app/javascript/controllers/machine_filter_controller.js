import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list"]

  filter() {
    const query = this.inputTarget.value.toLowerCase().trim()
    const list = this.listTarget

    // Check if we're filtering city-grouped shop cards (prefecture page)
    const cityGroups = list.querySelectorAll("[data-city-group]")
    if (cityGroups.length > 0) {
      this.#filterCityGroups(cityGroups, query)
      return
    }

    // Check if we're filtering flat shop cards (without city groups)
    const shopCards = list.querySelectorAll("[data-filter-name]")
    if (shopCards.length > 0) {
      this.#filterShopCards(shopCards, query)
      return
    }

    // Machine vote rows (shop page)
    const rows = list.querySelectorAll("turbo-frame[id^='machine_vote_']")
    const headers = list.querySelectorAll("[data-type-header]")

    if (query === "") {
      rows.forEach(el => el.parentElement?.classList.remove("hidden"))
      headers.forEach(el => el.classList.remove("hidden"))
      return
    }

    rows.forEach(el => {
      const wrapper = el.parentElement || el
      const name = wrapper.querySelector("a")?.textContent?.toLowerCase() || ""
      wrapper.classList.toggle("hidden", !name.includes(query))
    })

    headers.forEach(el => {
      let next = el.nextElementSibling
      let hasVisible = false
      while (next && !next.dataset?.typeHeader) {
        if (!next.classList.contains("hidden")) hasVisible = true
        next = next.nextElementSibling
      }
      el.classList.toggle("hidden", !hasVisible)
    })
  }

  #filterCityGroups(groups, query) {
    groups.forEach(group => {
      const cards = group.querySelectorAll("[data-filter-name]")
      let anyVisible = false

      if (query === "") {
        cards.forEach(el => el.classList.remove("hidden"))
        group.classList.remove("hidden")
        return
      }

      cards.forEach(el => {
        const name = el.dataset.filterName || ""
        const visible = name.includes(query)
        el.classList.toggle("hidden", !visible)
        if (visible) anyVisible = true
      })

      // Hide entire city group if no matching shops
      group.classList.toggle("hidden", !anyVisible)

      // Auto-expand group if it has matching results
      if (anyVisible) {
        const content = group.querySelector("[data-accordion-target='content']")
        if (content) content.classList.remove("hidden")
      }
    })
  }

  #filterShopCards(cards, query) {
    if (query === "") {
      cards.forEach(el => el.classList.remove("hidden"))
      return
    }

    cards.forEach(el => {
      const name = el.dataset.filterName || ""
      el.classList.toggle("hidden", !name.includes(query))
    })
  }
}
