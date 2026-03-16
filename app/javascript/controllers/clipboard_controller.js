import { Controller } from "@hotwired/stimulus"

// Copies target text to clipboard with temporary feedback
export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    const text = this.sourceTarget.textContent.trim()
    navigator.clipboard.writeText(text).then(() => {
      this.buttonTarget.textContent = "コピー済み"
      setTimeout(() => {
        this.buttonTarget.textContent = "コピー"
      }, 2000)
    })
  }
}
