import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["searchInput", "scopeSelect", "clearButton", "spinner", "search", "submitButton", "loadingTemplate"]
  static values = {
    clearUrl: String,
    frameId: { type: String, default: "book-list" },
    submitCooldown: { type: Number, default: 1500 }
  }

  connect() {
    this._hide = this.hideLoading.bind(this)
    this.isLoading = this.frameIsBusy()
    this.cooldownUntil = 0
    this.lastSubmissionKey = null
    this.clearButtonTarget.hidden = true
    this.clearButtonTarget.classList.add("visually-hidden");

    // Hide loading after the frame updates (Turbo renders the response)
    document.addEventListener("turbo:frame-render", this._hide)
    // Fallback: also hide when Turbo finishes loading
    document.addEventListener("turbo:load", this._hide)

    if (this.isLoading) {
      this.showLoading()
    } else {
      this.syncSubmitState()
    }
  }

  disconnect() {
    document.removeEventListener("turbo:frame-render", this._hide)
    document.removeEventListener("turbo:load", this._hide)
    clearTimeout(this.cooldownTimer)
  }

  formChanged() {
    if (this.submissionKey() !== this.lastSubmissionKey) {
      this.cooldownUntil = 0
      clearTimeout(this.cooldownTimer)
    }

    this.syncSubmitState()
  }

  clear(event) {
    event.preventDefault()

    this.searchInputTarget.value = ""
    this.cooldownUntil = 0
    this.lastSubmissionKey = null
    clearTimeout(this.cooldownTimer)
    this.isLoading = false

    this.submitButtonTarget.setAttribute("aria-busy", "false")
    this.spinnerTarget.classList.add("visually-hidden")
    this.searchTarget.classList.remove("visually-hidden")
    this.syncSubmitState()

    const clearUrl = this.clearUrlValue
    if (!clearUrl) return

    const currentUrl = window.location.pathname + window.location.search
    const clearPath = new URL(clearUrl, window.location.origin)
    const targetUrl = `${clearPath.pathname}${clearPath.search}`

    if (currentUrl === targetUrl) return

    if (window.Turbo?.visit) {
      window.Turbo.visit(clearUrl)
    } else {
      window.location.assign(clearUrl)
    }
  }

  submit(event) {
    if (!this.canSubmit()) {
      event.preventDefault()
      return
    }

    this.lastSubmissionKey = this.submissionKey()
    this.cooldownUntil = Date.now() + this.submitCooldownValue
    this.isLoading = true

    this.showLoading()
    this.renderLoadingState()
    this.scheduleCooldownSync()
  }

  showLoading() {
    this.submitButtonTarget.setAttribute("aria-busy", "true")
    this.searchTarget.classList.add("visually-hidden")
    this.spinnerTarget.classList.remove("visually-hidden")
    this.syncSubmitState()
  }

  hideLoading(event) {
    if (event?.target?.id && event.target.id !== this.frameIdValue) return

    const frame = document.getElementById(this.frameIdValue)
    if (frame) {
      frame.classList.remove("search-results--loading")
      frame.setAttribute("aria-busy", "false")
    }

    this.isLoading = false
    this.submitButtonTarget.setAttribute("aria-busy", "false")
    this.spinnerTarget.classList.add("visually-hidden")
    this.searchTarget.classList.remove("visually-hidden")
    this.syncSubmitState()
  }

  renderLoadingState() {
    const frame = document.getElementById(this.frameIdValue)
    if (!frame || !this.hasLoadingTemplateTarget) return

    frame.classList.add("search-results--loading")
    frame.setAttribute("aria-busy", "true")
    frame.innerHTML = this.loadingTemplateTarget.innerHTML.trim()
  }

  canSubmit() {
    if (this.isLoading) return false

    return !(this.isCoolingDown() && this.submissionKey() === this.lastSubmissionKey)
  }

  frameIsBusy() {
    const frame = document.getElementById(this.frameIdValue)
    return frame?.getAttribute("aria-busy") === "true"
  }

  isCoolingDown() {
    return Date.now() < this.cooldownUntil
  }

  scheduleCooldownSync() {
    clearTimeout(this.cooldownTimer)
    if (!this.isCoolingDown()) return

    this.cooldownTimer = setTimeout(() => {
      this.syncSubmitState()
    }, this.cooldownUntil - Date.now() + 10)
  }

  submissionKey() {
    const query = this.searchInputTarget.value?.trim().replace(/\s+/g, " ") || ""
    const scope = this.scopeSelectTarget.value || ""

    return `${scope}::${query.toLowerCase()}`
  }

  syncSubmitState() {
    const hasQuery = this.searchInputTarget.value?.trim().length > 0
    const sameAsLastSubmission = this.submissionKey() === this.lastSubmissionKey
    const isBlocked = this.isLoading || (sameAsLastSubmission && this.isCoolingDown())

    this.element.classList.toggle("search--ready", hasQuery)
    this.clearButtonTarget.classList.toggle("visually-hidden", !hasQuery)
    this.submitButtonTarget.disabled = isBlocked
    this.submitButtonTarget.setAttribute("aria-disabled", isBlocked ? "true" : "false")

    if (!this.isLoading) {
      this.searchTarget.classList.remove("visually-hidden")
      this.spinnerTarget.classList.add("visually-hidden")
    }
  }
}
