import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    // 自動消去タイマー
    this.timer = setTimeout(() => this.fadeOut(), this.delayValue)
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  dismiss() {
    this.fadeOut()
  }

  fadeOut() {
    this.element.style.transition = "opacity 0.3s ease-out"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 300)
  }
}
