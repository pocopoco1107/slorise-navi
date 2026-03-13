import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sign", "amount", "hidden"]

  connect() {
    this.positive = true
  }

  toggleSign() {
    this.positive = !this.positive
    this.signTarget.textContent = this.positive ? "+" : "-"
    this.signTarget.classList.toggle("text-primary", this.positive)
    this.signTarget.classList.toggle("text-destructive", !this.positive)
    this.updateHidden()
  }

  updateHidden() {
    const amount = parseInt(this.amountTarget.value) || 0
    this.hiddenTarget.value = this.positive ? amount : -amount
  }

  input() {
    this.updateHidden()
  }
}
