import { Controller } from "@hotwired/stimulus"

// Handles trend chart period tab switching via Turbo Frame
export default class extends Controller {
  static targets = ["tab"]
  static values = {
    url: String,
    current: { type: String, default: "7" }
  }

  switch(event) {
    event.preventDefault()
    const period = event.currentTarget.dataset.period
    if (period === this.currentValue) return

    this.currentValue = period

    // Update active tab styling
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.period === period
      tab.classList.toggle("bg-primary", isActive)
      tab.classList.toggle("text-primary-foreground", isActive)
      tab.classList.toggle("bg-secondary", !isActive)
      tab.classList.toggle("text-secondary-foreground", !isActive)
    })

    // Load new data via Turbo Frame
    const frame = document.getElementById("trend_chart_frame")
    if (frame) {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("period", period)
      frame.src = url.toString()
    }
  }
}
