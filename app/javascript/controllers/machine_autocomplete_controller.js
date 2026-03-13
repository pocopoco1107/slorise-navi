import { Controller } from "@hotwired/stimulus"

// Per-entry machine keyword search with client-side filtering
export default class extends Controller {
  static targets = ["input", "hidden", "results", "label"]

  connect() {
    this.machines = []
    this._debounceTimer = null
  }

  // Receive machine list from machine-options controller
  loadMachines(event) {
    this.machines = event.detail?.machines || []
    // Clear current selection if machine no longer in list
    const currentId = this.hiddenTarget.value
    if (currentId && !this.machines.find(m => String(m.id) === currentId)) {
      this._clearSelection()
    }
    // Update placeholder text (only if input is visible)
    this.inputTarget.placeholder = this.machines.length > 0
      ? `機種名を検索（${this.machines.length}機種）`
      : "店舗を選択すると検索できます"
  }

  search() {
    const query = this.inputTarget.value.trim()

    // If user edits after selecting, clear hidden value
    if (this.hiddenTarget.value) {
      this.hiddenTarget.value = ""
    }

    if (query.length === 0 || this.machines.length === 0) {
      this._hideResults()
      return
    }

    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this._filter(query), 100)
  }

  select(event) {
    const id = event.currentTarget.dataset.machineId
    const name = event.currentTarget.dataset.machineName

    this.hiddenTarget.value = id
    this.inputTarget.value = ""
    this.inputTarget.classList.add("hidden")

    // Show selected label
    if (this.hasLabelTarget) {
      this.labelTarget.querySelector("span").textContent = name
      this.labelTarget.classList.remove("hidden")
    }

    this._hideResults()
  }

  clear() {
    this._clearSelection()
    this.inputTarget.classList.remove("hidden")
    this.inputTarget.focus()
  }

  // Show all machines when input is focused and empty
  focus() {
    if (this.inputTarget.value.trim() === "" && this.machines.length > 0) {
      this._renderResults(this.machines.slice(0, 20))
    }
  }

  closeResults(event) {
    if (!this.element.contains(event.target)) {
      this._hideResults()
    }
  }

  // Private

  _filter(query) {
    const lowerQuery = query.toLowerCase()
    const matches = this.machines.filter(m =>
      m.name.toLowerCase().includes(lowerQuery)
    ).slice(0, 20)
    this._renderResults(matches)
  }

  _renderResults(machines) {
    const container = this.resultsTarget
    if (machines.length === 0) {
      container.innerHTML = `
        <div class="px-3 py-3 text-center text-xs text-muted-foreground">
          該当する機種がありません
        </div>`
      container.classList.remove("hidden")
      return
    }

    container.innerHTML = machines.map(m => `
      <button type="button"
              class="w-full text-left px-3 py-2.5 hover:bg-secondary transition-colors text-sm text-foreground truncate min-h-[44px] flex items-center"
              data-action="click->machine-autocomplete#select"
              data-machine-id="${m.id}"
              data-machine-name="${this._escapeHtml(m.name)}">
        ${this._escapeHtml(m.name)}
      </button>
    `).join("")

    container.classList.remove("hidden")
  }

  _hideResults() {
    this.resultsTarget.classList.add("hidden")
    this.resultsTarget.innerHTML = ""
  }

  _clearSelection() {
    this.hiddenTarget.value = ""
    this.inputTarget.value = ""
    this.inputTarget.classList.remove("hidden")
    this.inputTarget.placeholder = this.machines.length > 0
      ? `機種名を検索（${this.machines.length}機種）`
      : "店舗を選択すると検索できます"
    if (this.hasLabelTarget) {
      this.labelTarget.querySelector("span").textContent = ""
      this.labelTarget.classList.add("hidden")
    }
  }

  _escapeHtml(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
