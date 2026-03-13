import { Controller } from "@hotwired/stimulus"

// Bottom sheet (mobile) / center dialog (desktop) for play record entry
export default class extends Controller {
  static targets = ["backdrop", "panel", "dateInput", "dateLabel"]

  connect() {
    this._onKeydown = this._handleKeydown.bind(this)
    this._isOpen = false
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    document.body.style.overflow = ""
  }

  // Called from calendar:dateSelected event
  openWithDate(event) {
    const date = event.detail?.date
    if (date) this._setDate(date)
    this.open()
  }

  // FAB button — open for today
  openForToday() {
    const today = new Date()
    const yyyy = today.getFullYear()
    const mm = String(today.getMonth() + 1).padStart(2, "0")
    const dd = String(today.getDate()).padStart(2, "0")
    this._setDate(`${yyyy}-${mm}-${dd}`)
    this.open()
  }

  open() {
    if (this._isOpen) return
    this._isOpen = true

    const panel = this.panelTarget
    const backdrop = this.backdropTarget
    const desktop = this._isDesktop()

    // Reset inline styles and show elements
    backdrop.classList.remove("hidden")
    panel.classList.remove("hidden")

    // Set initial state
    backdrop.style.transition = "opacity 300ms ease"
    backdrop.style.opacity = "0"

    panel.style.transition = "transform 300ms ease, opacity 300ms ease"
    if (desktop) {
      panel.style.transform = "translate(-50%, -50%) scale(0.95)"
      panel.style.opacity = "0"
    } else {
      panel.style.transform = "translateY(100%)"
      panel.style.opacity = "1"
    }

    // Lock body scroll
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this._onKeydown)

    // Animate in
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        backdrop.style.opacity = "1"
        if (desktop) {
          panel.style.transform = "translate(-50%, -50%) scale(1)"
          panel.style.opacity = "1"
        } else {
          panel.style.transform = "translateY(0)"
        }
      })
    })
  }

  close() {
    if (!this._isOpen) return
    this._isOpen = false

    const panel = this.panelTarget
    const backdrop = this.backdropTarget
    const desktop = this._isDesktop()

    // Animate out
    backdrop.style.opacity = "0"
    if (desktop) {
      panel.style.transform = "translate(-50%, -50%) scale(0.95)"
      panel.style.opacity = "0"
    } else {
      panel.style.transform = "translateY(100%)"
    }

    setTimeout(() => {
      backdrop.classList.add("hidden")
      panel.classList.add("hidden")
      // Clean up inline styles
      panel.style.transform = ""
      panel.style.opacity = ""
      panel.style.transition = ""
      backdrop.style.transform = ""
      backdrop.style.opacity = ""
      backdrop.style.transition = ""
      document.body.style.overflow = ""
      document.removeEventListener("keydown", this._onKeydown)
    }, 300)
  }

  backdropClose(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }

  // Private

  _handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  _setDate(dateStr) {
    if (this.hasDateInputTarget) {
      this.dateInputTarget.value = dateStr
    }
    if (this.hasDateLabelTarget) {
      this.dateLabelTarget.textContent = this._formatDate(dateStr)
    }
  }

  _formatDate(dateStr) {
    const d = new Date(dateStr + "T00:00:00")
    const days = ["日", "月", "火", "水", "木", "金", "土"]
    return `${d.getMonth() + 1}/${d.getDate()}(${days[d.getDay()]})`
  }

  _isDesktop() {
    return window.matchMedia("(min-width: 640px)").matches
  }
}
