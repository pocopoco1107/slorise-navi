import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["day"]

  select(event) {
    const date = event.currentTarget.dataset.calendarDate

    // Ring on selected day
    this.dayTargets.forEach(el => {
      const match = el.dataset.calendarDate === date
      el.classList.toggle("ring-2", match)
      el.classList.toggle("ring-primary", match)
    })

    // Dispatch event for modal to listen
    this.dispatch("dateSelected", { detail: { date }, bubbles: true })
  }
}
