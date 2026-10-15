import { Controller } from "@hotwired/stimulus"

// Keep the form usable across Turbo renders, failed requests, and cached visits.
export default class SearchController extends Controller {
  static targets = ["form", "searchInput", "scopeSelect", "clearButton", "spinner", "search",
    "submitButton", "submitText", "loadingTemplate", "hint", "feedback"]
  static values = {
    clearUrl: String,
    frameId: { type: String, default: "book-list" }
  }

  connect() {
    this.isLoading = false
    this.activeSubmission = null
    this.previousFrameHtml = null
    this.handlers = [
      ["turbo:frame-render", this.hideLoading.bind(this)],
      ["turbo:submit-start", this.submissionStarted.bind(this)],
      ["turbo:submit-end", this.submissionEnded.bind(this)],
      ["turbo:fetch-request-error", this.requestFailed.bind(this)],
      ["turbo:frame-missing", this.requestFailed.bind(this)],
      ["turbo:before-cache", this.beforeCache.bind(this)]
    ]
    this.handlers.forEach(([name, handler]) => document.addEventListener(name, handler))
    this.updateScopeHint()
    this.syncSubmitState()
    if (SearchController.focusAfterClear && !document.documentElement.hasAttribute("data-turbo-preview")) {
      SearchController.focusAfterClear = false
      this.searchInputTarget.focus()
    }
  }

  disconnect() {
    this.handlers.forEach(([name, handler]) => document.removeEventListener(name, handler))
    this.activeSubmission?.stop()
  }

  formChanged() {
    this.clearFeedback()
    this.updateScopeHint()
    this.syncSubmitState()
  }

  updateScopeHint() {
    const option = this.scopeSelectTarget.selectedOptions[0]
    this.searchInputTarget.placeholder = option.dataset.placeholder
    this.hintTarget.textContent = option.dataset.hint
  }

  clear(event) {
    event.preventDefault()
    const submission = this.activeSubmission
    this.activeSubmission = null
    submission?.stop()
    this.searchInputTarget.value = ""
    this.clearFeedback()
    this.finishLoading(true)
    this.searchInputTarget.focus()

    if (!this.clearUrlValue) return
    const destination = new URL(this.clearUrlValue, window.location.origin)
    const current = window.location.pathname + window.location.search
    if (current === destination.pathname + destination.search) return
    if (window.Turbo?.visit) {
      SearchController.focusAfterClear = true
      window.Turbo.visit(this.clearUrlValue)
    } else {
      window.location.assign(this.clearUrlValue)
    }
  }

  submit(event) {
    if (this.isLoading) {
      event.preventDefault()
      return
    }
    this.clearFeedback()
    const query = this.searchInputTarget.value.trim()
    const limit = this.searchInputTarget.maxLength
    let error = ""
    if (!query) error = "Enter a search first."
    else if (query.length > limit) error = `Keep your search to ${limit} characters or fewer.`
    else if (this.scopeSelectTarget.value === "isbn" && (!/^[0-9Xx\s-]+$/.test(query) || !/\d/.test(query))) {
      error = "Enter an ISBN using numbers, spaces, hyphens, and X when needed."
    }
    if (error) {
      event.preventDefault()
      this.feedbackTarget.textContent = error
      this.feedbackTarget.hidden = false
      this.searchInputTarget.setAttribute("aria-invalid", "true")
      this.searchInputTarget.focus()
      return
    }

    this.searchInputTarget.value = query
    this.isLoading = true
    this.syncSubmitState()
    const frame = document.getElementById(this.frameIdValue)
    if (frame) {
      this.previousFrameHtml = frame.innerHTML
      frame.classList.add("search-results--loading")
      frame.setAttribute("aria-busy", "true")
      frame.innerHTML = this.loadingTemplateTarget.innerHTML.trim()
    }
  }

  submissionStarted(event) {
    if (event.target === this.formTarget) this.activeSubmission = event.detail.formSubmission
  }

  submissionEnded(event) {
    if (event.target !== this.formTarget) return
    if (event.detail.formSubmission !== this.activeSubmission) return
    if (event.detail.error || event.detail.success === false) this.showRequestError()
  }

  requestFailed(event) {
    if (event.target !== this.formTarget && event.target?.id !== this.frameIdValue) return
    event.preventDefault()
    this.showRequestError()
  }

  showRequestError() {
    this.finishLoading(true)
    this.feedbackTarget.textContent = "Search couldn't finish. Check your connection and try again."
    this.feedbackTarget.hidden = false
  }

  hideLoading(event) {
    if (event.target?.id === this.frameIdValue) this.finishLoading()
  }

  beforeCache() {
    this.activeSubmission?.stop()
    this.finishLoading(true)
  }

  finishLoading(restore = false) {
    const frame = document.getElementById(this.frameIdValue)
    if (frame) {
      if (restore && this.previousFrameHtml !== null) frame.innerHTML = this.previousFrameHtml
      frame.classList.remove("search-results--loading")
      frame.setAttribute("aria-busy", "false")
    }
    this.previousFrameHtml = null
    this.activeSubmission = null
    this.isLoading = false
    this.syncSubmitState()
  }

  clearFeedback() {
    this.feedbackTarget.hidden = true
    this.feedbackTarget.textContent = ""
    this.searchInputTarget.removeAttribute("aria-invalid")
  }

  syncSubmitState() {
    const hasQuery = this.searchInputTarget.value.trim().length > 0
    this.element.classList.toggle("search--ready", hasQuery)
    this.clearButtonTarget.hidden = this.searchInputTarget.value.length === 0
    this.submitButtonTarget.disabled = this.isLoading || !hasQuery
    this.submitButtonTarget.setAttribute("aria-disabled", String(this.submitButtonTarget.disabled))
    this.submitButtonTarget.setAttribute("aria-busy", String(this.isLoading))
    this.submitTextTarget.textContent = this.isLoading ? "Searching…" : "Search"
    this.spinnerTarget.classList.toggle("visually-hidden", !this.isLoading)
    this.searchTarget.classList.toggle("visually-hidden", this.isLoading)
  }
}
