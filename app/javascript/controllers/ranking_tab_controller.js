import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  switch(event) {
    const url = new URL(window.location)
    const param = event.currentTarget.dataset.param
    const value = event.currentTarget.dataset.value
    url.searchParams.set(param, value)
    Turbo.visit(url.toString())
  }
}
