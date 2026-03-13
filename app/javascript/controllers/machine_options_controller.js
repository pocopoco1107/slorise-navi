import { Controller } from "@hotwired/stimulus"

// Fetches shop's machine list and broadcasts to machine-autocomplete instances
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.machines = []
  }

  // Called when shop-autocomplete dispatches shopSelected
  async update(event) {
    const shopId = event.detail?.shopId
    if (!shopId) return

    try {
      const url = `${this.urlValue}?shop_id=${encodeURIComponent(shopId)}`
      const response = await fetch(url, { headers: { "Accept": "application/json" } })
      if (!response.ok) return
      this.machines = await response.json()
    } catch (e) {
      this.machines = []
    }

    // Cache on window for late-joining entries
    window._cachedMachineList = this.machines

    // Broadcast on window so all machine-autocomplete controllers receive it
    window.dispatchEvent(new CustomEvent("machine-options:machinesLoaded", {
      detail: { machines: this.machines }
    }))
  }
}
