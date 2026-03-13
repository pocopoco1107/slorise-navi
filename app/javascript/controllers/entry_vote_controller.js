import { Controller } from "@hotwired/stimulus"

// Handles reset/setting/confirmed toggle buttons within a play record entry
export default class extends Controller {
  static targets = ["resetHidden", "resetBtn", "settingHidden", "settingBtn", "confirmedInput", "confirmedBtn"]

  selectReset(event) {
    const btn = event.currentTarget
    const value = btn.dataset.value
    const current = this.resetHiddenTarget.value

    // Toggle: same value → deselect
    if (current === value) {
      this.resetHiddenTarget.value = ""
      this.resetBtnTargets.forEach(b => this._setResetStyle(b, false))
    } else {
      this.resetHiddenTarget.value = value
      this.resetBtnTargets.forEach(b => {
        this._setResetStyle(b, b.dataset.value === value)
      })
    }
  }

  selectSetting(event) {
    const btn = event.currentTarget
    const value = btn.dataset.value
    const current = this.settingHiddenTarget.value

    if (current === value) {
      this.settingHiddenTarget.value = ""
      this.settingBtnTargets.forEach(b => this._setSettingStyle(b, false))
    } else {
      this.settingHiddenTarget.value = value
      this.settingBtnTargets.forEach(b => {
        this._setSettingStyle(b, b.dataset.value === value)
      })
    }
  }

  toggleConfirmed(event) {
    const label = event.currentTarget
    const tag = label.dataset.tag
    // Find the matching checkbox
    const input = this.confirmedInputTargets.find(i => i.value === tag)
    if (!input) return

    input.checked = !input.checked
    this._setConfirmedStyle(label, input.checked)
  }

  // Private style helpers

  _setResetStyle(btn, selected) {
    const isYes = btn.dataset.value === "1"
    if (selected) {
      btn.className = btn.className
        .replace(/bg-vote-(yes|no)\/10/, isYes ? "bg-vote-yes" : "bg-vote-no")
        .replace(/text-vote-(yes|no)(?!\/)/, "text-white")
      if (!btn.className.includes("ring-1")) {
        btn.classList.add("ring-1", isYes ? "ring-vote-yes/50" : "ring-vote-no/50")
      }
    } else {
      btn.classList.remove("ring-1", "ring-vote-yes/50", "ring-vote-no/50")
      btn.className = btn.className
        .replace(/bg-vote-(yes|no)(?!\/)/, isYes ? "bg-vote-yes/10" : "bg-vote-no/10")
        .replace(/text-white/, isYes ? "text-vote-yes" : "text-vote-no")
    }
  }

  _setSettingStyle(btn, selected) {
    const s = btn.dataset.value
    if (selected) {
      btn.className = btn.className
        .replace(new RegExp(`bg-setting-${s}/10`), `bg-setting-${s}`)
        .replace(new RegExp(`text-setting-${s}`), "text-white")
    } else {
      btn.className = btn.className
        .replace(new RegExp(`bg-setting-${s}(?!/)`), `bg-setting-${s}/10`)
        .replace(/text-white/, `text-setting-${s}`)
    }
  }

  _setConfirmedStyle(label, selected) {
    // Use the same pattern: swap /10 suffix
    if (selected) {
      label.className = label.className.replace(/\/10\b/, "")
      if (!label.className.includes("text-white")) {
        label.className = label.className.replace(/text-setting-\d/, "text-white")
      }
    } else {
      // Restore original by finding the color from the class
      const match = label.className.match(/bg-(setting-\d)/)
      if (match) {
        label.className = label.className
          .replace(new RegExp(`bg-${match[1]}(?!/)`), `bg-${match[1]}/10`)
          .replace(/text-white/, `text-${match[1]}`)
      }
    }
  }
}
