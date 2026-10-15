import { Controller } from "@hotwired/stimulus"

// Keep the form usable across Turbo renders, failed requests, and cached visits.
export default class SearchController extends Controller {
  static targets = ["form", "searchInput", "scopeSelect", "clearButton", "spinner", "search",
    "submitButton", "submitText", "hint", "feedback", "retryButton"]
  static values = {
    clearUrl: String,
    frameId: { type: String, default: "book-list" },
    timeout: { type: Number, default: 20000 }
  }

  connect() {
    this.isLoading = false
    this.activeSubmission = null
    this.previousFrameHtml = null
    this.retryAt = 0
    this.handlers = [
      ["turbo:frame-render", this.hideLoading.bind(this)],
      ["turbo:before-frame-render", this.prepareResults.bind(this)],
      ["turbo:before-fetch-response", this.responseReceived.bind(this)],
      ["turbo:submit-start", this.submissionStarted.bind(this)],
      ["turbo:submit-end", this.submissionEnded.bind(this)],
      ["turbo:fetch-request-error", this.requestFailed.bind(this)],
      ["turbo:frame-missing", this.requestFailed.bind(this)],
      ["turbo:before-cache", this.beforeCache.bind(this)]
    ]
    this.handlers.forEach(([name, handler]) => document.addEventListener(name, handler))
    this.updateScopeHint()
    this.readRecovery()
    this.syncSubmitState()
    if (SearchController.focusAfterClear && !document.documentElement.hasAttribute("data-turbo-preview")) {
      SearchController.focusAfterClear = false
      this.searchInputTarget.focus()
    }
  }

  disconnect() {
    clearTimeout(this.timeoutId)
    clearInterval(this.cooldownId)
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
    if (this.retryRemaining > 0) {
      event.preventDefault()
      return
    }
    this.clearFeedback()
    if (window.navigator?.onLine === false) {
      event.preventDefault()
      this.showRequestError("You're offline. Reconnect, then retry your search.")
      return
    }
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
    if (event.submitter?.matches("[data-recovery-retry]") || event.submitter === this.retryButtonTarget) {
      this.searchInputTarget.focus()
    }
    this.isLoading = true
    this.activeResponse = null
    this.syncSubmitState()
    const frame = document.getElementById(this.frameIdValue)
    if (frame) {
      this.previousFrameHtml = frame.innerHTML
      frame.setAttribute("aria-busy", "true")
    }
    this.timeoutId = setTimeout(() => {
      this.showRequestError("Search took too long. Your search is still here; try again.")
    }, this.timeoutValue)
  }

  responseReceived(event) {
    if (event.target !== this.formTarget || !this.isLoading) return
    this.activeResponse = event.detail.fetchResponse.response
    if (!event.detail.fetchResponse.succeeded) {
      event.preventDefault()
      this.showRequestError("Search couldn't finish right now. Your search is still here; try again.")
    }
  }

  prepareResults(event) {
    if (event.target?.id !== this.frameIdValue) return
    const current = event.target.querySelector("[data-search-response]")
    const incoming = event.detail.newFrame.querySelector("[data-search-response]")
    if (!incoming?.dataset.failed || !current) return
    if (current.dataset.query !== incoming.dataset.query || current.dataset.scope !== incoming.dataset.scope) return
    const grid = current.querySelector(".search-results__grid")
    if (!grid?.children.length) return

    incoming.querySelectorAll(".search-results__header, .search-results__grid").forEach(element => element.remove())
    const header = current.querySelector(".search-results__header")
    if (header) incoming.append(header.cloneNode(true))
    incoming.append(grid.cloneNode(true))
    incoming.querySelector("[data-recovery-detail]").textContent = "Your previous results are still shown below."
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
    if (!this.isLoading || event.detail.request?.abortSignal?.aborted) return
    if (event.detail.request && event.detail.request !== this.activeSubmission?.fetchRequest) return
    if (event.detail.response && event.detail.response !== this.activeResponse) return
    this.showRequestError()
  }

  showRequestError(message = "Search couldn't finish. Check your connection and try again.") {
    const submission = this.activeSubmission
    this.finishLoading(true)
    submission?.stop()
    this.feedbackTarget.textContent = message
    this.feedbackTarget.hidden = false
    this.retryButtonTarget.hidden = false
  }

  hideLoading(event) {
    if (event.target?.id !== this.frameIdValue) return
    this.finishLoading()
    this.readRecovery()
  }

  beforeCache() {
    const submission = this.activeSubmission
    this.finishLoading(true)
    submission?.stop()
  }

  finishLoading(restore = false) {
    clearTimeout(this.timeoutId)
    const frame = document.getElementById(this.frameIdValue)
    if (frame) {
      if (restore && this.previousFrameHtml !== null && frame.innerHTML !== this.previousFrameHtml) {
        frame.innerHTML = this.previousFrameHtml
      }
      frame.classList.remove("search-results--loading")
      frame.setAttribute("aria-busy", "false")
    }
    this.previousFrameHtml = null
    this.activeSubmission = null
    this.activeResponse = null
    this.isLoading = false
    this.syncSubmitState()
  }

  clearFeedback() {
    this.feedbackTarget.hidden = true
    this.feedbackTarget.textContent = ""
    this.retryButtonTarget.hidden = true
    this.searchInputTarget.removeAttribute("aria-invalid")
  }

  syncSubmitState() {
    const hasQuery = this.searchInputTarget.value.trim().length > 0
    this.element.classList.toggle("search--ready", hasQuery)
    this.clearButtonTarget.hidden = this.searchInputTarget.value.length === 0
    this.submitButtonTarget.disabled = this.isLoading || !hasQuery || this.retryRemaining > 0
    this.submitButtonTarget.setAttribute("aria-disabled", String(this.submitButtonTarget.disabled))
    this.submitButtonTarget.setAttribute("aria-busy", String(this.isLoading))
    this.submitTextTarget.textContent = this.isLoading ? "Searching…" : "Search"
    this.spinnerTarget.classList.toggle("visually-hidden", !this.isLoading)
    this.searchTarget.classList.toggle("visually-hidden", this.isLoading)
    this.retryButtonTarget.disabled = this.submitButtonTarget.disabled
    const frame = document.getElementById(this.frameIdValue)
    frame?.querySelectorAll?.("[data-recovery-retry]").forEach(button => {
      button.disabled = this.submitButtonTarget.disabled
    })
  }

  get retryRemaining() {
    return Math.max(0, Math.ceil((this.retryAt - Date.now()) / 1000))
  }

  readRecovery() {
    clearInterval(this.cooldownId)
    const frame = document.getElementById(this.frameIdValue)
    const response = frame?.querySelector?.("[data-search-response]")
    this.retryAt = Date.parse(response?.dataset.retryAt || "") || 0
    this.syncSubmitState()
    if (!this.retryAt) return
    const countdown = frame.querySelector("[data-recovery-countdown]")
    const update = () => {
      this.syncSubmitState()
      if (countdown) {
        if (this.retryRemaining === 0) {
          countdown.setAttribute("role", "status")
          countdown.setAttribute("aria-live", "polite")
        }
        countdown.textContent = this.retryRemaining > 0
          ? `You can retry in ${this.retryRemaining} seconds.` : "You can retry now."
      }
      if (this.retryRemaining === 0) clearInterval(this.cooldownId)
    }
    update()
    if (this.retryRemaining > 0) this.cooldownId = setInterval(update, 1000)
  }
}
