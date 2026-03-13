import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["entriesContainer", "template", "entry"]

  addEntry() {
    const template = this.templateTarget
    const clone = template.content.cloneNode(true)
    const newIndex = this.entryTargets.length

    // Update name attributes: replace __INDEX__ with correct index
    clone.querySelectorAll("[data-index-placeholder]").forEach(el => {
      const name = el.getAttribute("name")
      if (name) {
        el.setAttribute("name", name.replace("__INDEX__", newIndex))
      }
      el.removeAttribute("data-index-placeholder")
    })

    this.entriesContainerTarget.appendChild(clone)

    // Send current machine list to the newly added entry's autocomplete
    // The machine-options controller stores machines; re-broadcast after DOM insertion
    requestAnimationFrame(() => {
      const machineOptions = this.element.closest("[data-controller~='machine-options']")
        || this.element.querySelector("[data-controller~='machine-options']")
      // Find the controller instance via the element's __stimulus property
      // Simpler: just re-dispatch the event on window with cached data
      if (window._cachedMachineList) {
        window.dispatchEvent(new CustomEvent("machine-options:machinesLoaded", {
          detail: { machines: window._cachedMachineList }
        }))
      }
    })
  }

  removeEntry(event) {
    const entry = event.currentTarget.closest("[data-play-record-form-target='entry']")
    if (!entry) return

    // Keep at least one entry
    if (this.entryTargets.length <= 1) return

    entry.remove()
    this._reindex()
  }

  // Re-number name indices after removal
  _reindex() {
    this.entryTargets.forEach((entry, index) => {
      entry.querySelectorAll("[data-entry-field]").forEach(el => {
        const field = el.dataset.entryField
        // tags uses entries[N][tags][] format
        const suffix = field === "tags" ? "[]" : ""
        el.setAttribute("name", `entries[${index}][${field}]${suffix}`)
      })
    })
  }
}
