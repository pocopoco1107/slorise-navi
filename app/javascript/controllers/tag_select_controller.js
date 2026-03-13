import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chip", "input"]

  toggle(event) {
    const chip = event.currentTarget
    const value = chip.dataset.tagSelectValue
    chip.classList.toggle("bg-primary")
    chip.classList.toggle("text-primary-foreground")
    chip.classList.toggle("bg-secondary")
    chip.classList.toggle("text-secondary-foreground")

    // Toggle hidden input
    const input = this.inputTargets.find(i => i.value === value)
    if (input) {
      input.disabled = !input.disabled
    }
  }
}
