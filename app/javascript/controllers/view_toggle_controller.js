import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "listBtn", "gridBtn"]

  connect() {
    this.mode = localStorage.getItem("machine_view_mode") || "list"
    this.apply()
  }

  showList() {
    this.mode = "list"
    localStorage.setItem("machine_view_mode", "list")
    this.apply()
  }

  showGrid() {
    this.mode = "grid"
    localStorage.setItem("machine_view_mode", "grid")
    this.apply()
  }

  apply() {
    if (this.mode === "grid") {
      this.listTargets.forEach(el => {
        el.classList.add("grid", "grid-cols-2", "sm:grid-cols-3", "gap-2")
        el.classList.remove("overflow-hidden")
        // Convert children to grid cards
        el.querySelectorAll("details").forEach(d => {
          d.classList.add("rounded-lg", "border", "border-border")
          d.classList.remove("border-b", "last:border-b-0")
        })
      })
      this.listBtnTargets.forEach(b => b.classList.remove("bg-secondary"))
      this.gridBtnTargets.forEach(b => b.classList.add("bg-secondary"))
    } else {
      this.listTargets.forEach(el => {
        el.classList.remove("grid", "grid-cols-2", "sm:grid-cols-3", "gap-2")
        el.classList.add("overflow-hidden")
        el.querySelectorAll("details").forEach(d => {
          d.classList.remove("rounded-lg", "border", "border-border")
          d.classList.add("border-b", "last:border-b-0")
        })
      })
      this.listBtnTargets.forEach(b => b.classList.add("bg-secondary"))
      this.gridBtnTargets.forEach(b => b.classList.remove("bg-secondary"))
    }
  }
}
