import { Controller } from "@hotwired/stimulus"

// Navigates via Turbo when a select value changes
export default class extends Controller {
  static values = { param: String }

  change() {
    const url = new URL(window.location)
    url.searchParams.set(this.paramValue, this.element.value)
    Turbo.visit(url.toString())
  }
}
