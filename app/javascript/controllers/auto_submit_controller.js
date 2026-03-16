import { Controller } from "@hotwired/stimulus"

// Submits the closest form when the element changes
export default class extends Controller {
  submit() {
    this.element.form.submit()
  }
}
