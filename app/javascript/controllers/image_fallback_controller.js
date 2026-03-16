import { Controller } from "@hotwired/stimulus"

// Hides image (or its parent) on load error
export default class extends Controller {
  static values = { hideParent: { type: Boolean, default: false } }

  error() {
    if (this.hideParentValue) {
      this.element.parentElement.style.display = "none"
    } else {
      this.element.style.display = "none"
    }
  }
}
