import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "count", "rateButton"]

  connect() {
    this.activeRates = new Set()
  }

  toggleRate(event) {
    const rate = event.currentTarget.dataset.rate
    if (this.activeRates.has(rate)) {
      this.activeRates.delete(rate)
      event.currentTarget.classList.remove("ring-2", "ring-blue-500", "bg-blue-100")
      event.currentTarget.classList.add("bg-gray-50")
    } else {
      this.activeRates.add(rate)
      event.currentTarget.classList.remove("bg-gray-50")
      event.currentTarget.classList.add("ring-2", "ring-blue-500", "bg-blue-100")
    }
    this.#applyFilter()
  }

  clearRates() {
    this.activeRates.clear()
    this.rateButtonTargets.forEach(btn => {
      btn.classList.remove("ring-2", "ring-blue-500", "bg-blue-100")
      btn.classList.add("bg-gray-50")
    })
    this.#applyFilter()
  }

  #applyFilter() {
    let visibleCount = 0
    this.cardTargets.forEach(card => {
      const ratesStr = card.dataset.rates || ""
      const cardRates = ratesStr.split(",").filter(r => r)

      let show = true
      if (this.activeRates.size > 0) {
        show = [...this.activeRates].some(r => cardRates.includes(r))
      }

      card.classList.toggle("hidden", !show)
      if (show) visibleCount++
    })

    if (this.hasCountTarget) {
      this.countTarget.textContent = `${visibleCount}店`
    }
  }
}
