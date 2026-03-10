import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["star", "input"]

  connect() {
    this.rating = parseInt(this.inputTarget.value) || 0
    this.render()
  }

  select(event) {
    this.rating = parseInt(event.currentTarget.dataset.value)
    this.inputTarget.value = this.rating
    this.render()
  }

  hover(event) {
    const value = parseInt(event.currentTarget.dataset.value)
    this.starTargets.forEach((star, index) => {
      star.textContent = index < value ? "\u2605" : "\u2606"
      star.classList.toggle("text-yellow-400", index < value)
      star.classList.toggle("text-gray-300", index >= value)
    })
  }

  reset() {
    this.render()
  }

  render() {
    this.starTargets.forEach((star, index) => {
      star.textContent = index < this.rating ? "\u2605" : "\u2606"
      star.classList.toggle("text-yellow-400", index < this.rating)
      star.classList.toggle("text-gray-300", index >= this.rating)
    })
  }
}
