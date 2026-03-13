import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "buttonText", "spinner", "results", "error", "fallback"]

  connect() {
    // Check permission state upfront (if supported)
    if (navigator.permissions) {
      navigator.permissions.query({ name: "geolocation" }).then((result) => {
        if (result.state === "denied") {
          this.showFallback()
        }
      }).catch(() => {})
    }
  }

  locate() {
    if (!navigator.geolocation) {
      this.showFallback()
      return
    }

    this.showLoading()

    navigator.geolocation.getCurrentPosition(
      (position) => this.onSuccess(position),
      (error) => this.onError(error),
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 300000 }
    )
  }

  onSuccess(position) {
    const lat = position.coords.latitude
    const lng = position.coords.longitude
    const url = `/shops/nearby?lat=${lat}&lng=${lng}`

    const frame = document.getElementById("nearby_results")
    if (frame) {
      frame.src = url
      frame.reload()
    }

    this.hideLoading()
  }

  onError(_error) {
    this.hideLoading()
    this.showFallback()
  }

  // Show the prefecture select fallback
  showFallback() {
    if (this.hasButtonTarget) this.buttonTarget.classList.add("hidden")
    if (this.hasErrorTarget) this.errorTarget.classList.add("hidden")
    if (this.hasFallbackTarget) this.fallbackTarget.classList.remove("hidden")
  }

  // Navigate to selected prefecture
  goToPrefecture(event) {
    const slug = event.target.value
    if (slug) {
      window.location.href = `/prefectures/${slug}`
    }
  }

  showLoading() {
    if (this.hasButtonTextTarget) this.buttonTextTarget.textContent = "取得中..."
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.remove("hidden")
    if (this.hasButtonTarget) this.buttonTarget.disabled = true
    if (this.hasErrorTarget) this.errorTarget.classList.add("hidden")
  }

  hideLoading() {
    if (this.hasButtonTextTarget) this.buttonTextTarget.textContent = "現在地から探す"
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.add("hidden")
    if (this.hasButtonTarget) this.buttonTarget.disabled = false
  }
}
