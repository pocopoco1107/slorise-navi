import { Controller } from "@hotwired/stimulus"

// テーマ切替コントローラ
// ダーク (dark) / ライト (light) の2段階。デフォルトはダーク。
export default class extends Controller {
  static targets = ["icon", "label"]

  connect() {
    this.applyTheme()
  }

  toggle() {
    const next = this.currentSetting === "dark" ? "light" : "dark"
    try {
      localStorage.setItem("theme", next)
    } catch {
      // localStorage access denied
    }
    this.applyTheme()
  }

  get currentSetting() {
    try {
      return localStorage.getItem("theme") || "dark"
    } catch {
      return "dark"
    }
  }

  applyTheme() {
    const isDark = this.currentSetting === "dark"
    document.documentElement.classList.toggle("dark", isDark)
    this.updateIcon(isDark)
  }

  updateIcon(isDark) {
    if (!this.hasIconTarget) return

    if (isDark) {
      this.iconTarget.innerHTML = `
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"/>
        </svg>`
    } else {
      this.iconTarget.innerHTML = `
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"/>
        </svg>`
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = isDark ? "ダーク" : "ライト"
    }
  }
}
