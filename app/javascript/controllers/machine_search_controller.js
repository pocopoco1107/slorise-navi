import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { shopId: Number, date: String }

  connect() {
    this.timeout = null
  }

  search() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    if (query.length < 1) {
      this.resultsTarget.innerHTML = ""
      return
    }

    this.timeout = setTimeout(() => {
      const url = `/machines/search?q=${encodeURIComponent(query)}&shop_id=${this.shopIdValue}&date=${this.dateValue}`
      fetch(url, { headers: { "Accept": "text/html" } })
        .then(r => r.text())
        .then(html => { this.resultsTarget.innerHTML = html })
        .catch(() => {})
    }, 200)
  }

  clear() {
    this.inputTarget.value = ""
    this.resultsTarget.innerHTML = ""
  }
}
