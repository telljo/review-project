import test, { afterEach } from 'node:test'
import assert from 'node:assert/strict'
import SearchController from '../../app/javascript/controllers/search_controller.js'

const controllers = []
afterEach(() => { controllers.splice(0).forEach(controller => controller.disconnect()) })

function node() {
  const attributes = new Map()
  const classes = new Set()
  return {
    value: '', hidden: false, disabled: false, maxLength: 500, textContent: '',
    innerHTML: '', focused: false, querySelector: () => null, querySelectorAll: () => [],
    classList: {
      add: value => classes.add(value), remove: value => classes.delete(value),
      toggle: (value, enabled) => enabled ? classes.add(value) : classes.delete(value)
    },
    setAttribute: (name, value) => attributes.set(name, value),
    removeAttribute: name => attributes.delete(name),
    getAttribute: name => attributes.get(name),
    focus() { this.focused = true }
  }
}

function setup(query = '', scope = 'title', preview = false) {
  const element = node()
  const frame = node()
  frame.id = 'book-list'
  frame.innerHTML = '<p>Previous results</p>'
  globalThis.document = new EventTarget()
  document.documentElement = { hasAttribute: name => name === 'data-turbo-preview' && preview }
  document.getElementById = id => id === frame.id ? frame : null
  globalThis.window = { location: { origin: 'http://localhost', pathname: '/', search: '' } }
  const controller = new SearchController({ scope: { element } })
  for (const name of SearchController.targets) {
    Object.defineProperty(controller, name + 'Target', { value: node() })
  }
  controller.searchInputTarget.value = query
  controller.scopeSelectTarget.value = scope
  controller.scopeSelectTarget.selectedOptions = [{ dataset: { placeholder: 'Book title', hint: 'Enter a book title.' } }]
  controller.frameIdValue = frame.id
  controller.timeoutValue = 20000
  controller.clearUrlValue = '/'
  controller.connect()
  controllers.push(controller)
  return { controller, frame }
}

function action(target, detail = {}) {
  return { target, detail, prevented: false, preventDefault() { this.prevented = true } }
}

test('empty and whitespace queries cannot submit; empty Clear is hidden', () => {
  const { controller } = setup()
  assert.equal(controller.clearButtonTarget.hidden, true)
  assert.equal(controller.submitButtonTarget.disabled, true)
  controller.searchInputTarget.value = '   '
  controller.formChanged()
  const event = action(controller.formTarget)
  controller.submit(event)
  assert.equal(event.prevented, true)
  assert.equal(controller.isLoading, false)
  assert.equal(controller.feedbackTarget.hidden, false)
})

test('Clear cancels a pending submission, removes the query, and restores focus', () => {
  const { controller, frame } = setup('Dune')
  controller.submit(action(controller.formTarget))
  let stopped = false
  controller.submissionStarted(action(controller.formTarget, { formSubmission: { stop() { stopped = true } } }))
  controller.clear(action(controller.clearButtonTarget))
  assert.equal(stopped, true)
  assert.equal(controller.searchInputTarget.value, '')
  assert.equal(controller.searchInputTarget.focused, true)
  assert.equal(controller.clearButtonTarget.hidden, true)
  assert.equal(frame.innerHTML, '<p>Previous results</p>')
  assert.equal(frame.getAttribute('aria-busy'), 'false')
})

test('Clear restores focus on the final page rather than consuming it on a cached preview', () => {
  const { controller } = setup('Dune')
  window.location.pathname = '/google_books/search'
  window.Turbo = { visit() {} }
  controller.clear(action(controller.clearButtonTarget))
  const cached = setup('', 'title', true).controller
  assert.equal(cached.searchInputTarget.focused, false)
  const final = setup().controller
  assert.equal(final.searchInputTarget.focused, true)
  assert.equal(SearchController.focusAfterClear, false)
})

test('duplicate submits are blocked, and a failed submission can immediately retry', () => {
  const { controller, frame } = setup('Dune')
  controller.submit(action(controller.formTarget))
  for (let count = 0; count < 10; count++) {
    const event = action(controller.formTarget)
    controller.submit(event)
    assert.equal(event.prevented, true)
  }
  const submission = { stop() {} }
  controller.submissionStarted(action(controller.formTarget, { formSubmission: submission }))
  controller.submissionEnded(action(controller.formTarget, { formSubmission: submission, success: false }))
  assert.equal(controller.submitButtonTarget.disabled, false)
  assert.equal(controller.searchInputTarget.value, 'Dune')
  assert.equal(controller.feedbackTarget.hidden, false)
  assert.equal(frame.innerHTML, '<p>Previous results</p>')
  const retry = action(controller.formTarget)
  controller.submit(retry)
  assert.equal(retry.prevented, false)
  assert.equal(controller.isLoading, true)
})

test('network and missing-frame errors restore controls; unrelated requests do not', () => {
  const { controller, frame } = setup('Dune')
  controller.submit(action(controller.formTarget))
  controller.requestFailed(action({ id: 'other-frame' }))
  assert.equal(controller.isLoading, true)
  const failure = action(frame)
  controller.requestFailed(failure)
  assert.equal(failure.prevented, true)
  assert.equal(controller.submitButtonTarget.disabled, false)
  assert.equal(frame.getAttribute('aria-busy'), 'false')
  assert.equal(controller.submitTextTarget.textContent, 'Search')
})

test('scope changes update guidance, and ISBN spaces and hyphens remain valid', () => {
  const { controller } = setup('978-0-261-10334-4', 'isbn')
  controller.scopeSelectTarget.selectedOptions = [{ dataset: { placeholder: 'ISBN', hint: 'Enter an ISBN.' } }]
  controller.formChanged()
  assert.equal(controller.searchInputTarget.placeholder, 'ISBN')
  assert.equal(controller.hintTarget.textContent, 'Enter an ISBN.')
  const event = action(controller.formTarget)
  controller.submit(event)
  assert.equal(event.prevented, false)
  assert.equal(controller.isLoading, true)
})

test('invalid ISBNs and oversized queries show validation without starting a request', () => {
  for (const [query, scope] of [['not-an-isbn', 'isbn'], ['x'.repeat(501), 'title']]) {
    const { controller, frame } = setup(query, scope)
    const event = action(controller.formTarget)
    controller.submit(event)
    assert.equal(event.prevented, true)
    assert.equal(controller.isLoading, false)
    assert.equal(controller.searchInputTarget.getAttribute('aria-invalid'), 'true')
    assert.equal(frame.innerHTML, '<p>Previous results</p>')
  }
})

test('cached visits do not preserve a loading skeleton or a disabled Search button', () => {
  const { controller, frame } = setup('Dune')
  controller.submit(action(controller.formTarget))
  controller.beforeCache()
  assert.equal(frame.innerHTML, '<p>Previous results</p>')
  assert.equal(controller.submitButtonTarget.disabled, false)
  assert.equal(controller.submitTextTarget.textContent, 'Search')
  controller.disconnect()
})

test('a stalled browser request stops, preserves results, and allows a manual retry', context => {
  context.mock.timers.enable({ apis: ['setTimeout', 'Date'], now: 1000 })
  const { controller, frame } = setup('Dune')
  controller.submit(action(controller.formTarget))
  assert.equal(frame.innerHTML, '<p>Previous results</p>')
  let stopped = false
  controller.submissionStarted(action(controller.formTarget, { formSubmission: { stop() { stopped = true } } }))
  context.mock.timers.tick(20000)
  assert.equal(stopped, true)
  assert.equal(controller.feedbackTarget.textContent, 'Search took too long. Your search is still here; try again.')
  assert.equal(controller.retryButtonTarget.hidden, false)
  assert.equal(controller.submitButtonTarget.disabled, false)
  assert.equal(frame.getAttribute('aria-busy'), 'false')
})

test('an old or aborted request error cannot end a newer submission', () => {
  const { controller } = setup('Dune')
  controller.submit(action(controller.formTarget))
  const current = { fetchRequest: {}, stop() {} }
  controller.submissionStarted(action(controller.formTarget, { formSubmission: current }))
  controller.requestFailed(action(controller.formTarget, { request: { abortSignal: { aborted: true } } }))
  controller.requestFailed(action(controller.formTarget, { request: {} }))
  assert.equal(controller.isLoading, true)
  assert.equal(controller.feedbackTarget.hidden, true)
  controller.requestFailed(action(controller.formTarget, { request: current.fetchRequest }))
  assert.equal(controller.isLoading, false)
})

test('a failed HTTP response is stopped before Turbo replaces the working result frame', () => {
  const { controller, frame } = setup('Dune')
  controller.submit(action(controller.formTarget))
  const event = action(controller.formTarget, { fetchResponse: { succeeded: false, response: {} } })
  controller.responseReceived(event)
  assert.equal(event.prevented, true)
  assert.equal(frame.innerHTML, '<p>Previous results</p>')
  assert.equal(controller.retryButtonTarget.hidden, false)
})

test('offline submissions show recovery without starting a request', () => {
  const { controller, frame } = setup('Dune')
  window.navigator = { onLine: false }
  const event = action(controller.formTarget)
  controller.submit(event)
  assert.equal(event.prevented, true)
  assert.equal(controller.isLoading, false)
  assert.equal(frame.innerHTML, '<p>Previous results</p>')
  assert.equal(controller.feedbackTarget.textContent, "You're offline. Reconnect, then retry your search.")
})

test('rate limits block Enter and retry buttons until the server deadline, then enable them', context => {
  context.mock.timers.enable({ apis: ['setInterval', 'Date'], now: 1000 })
  const { controller, frame } = setup('Dune')
  const retry = node()
  const countdown = node()
  frame.querySelector = selector => selector === '[data-search-response]'
    ? { dataset: { retryAt: new Date(4000).toISOString() } } : countdown
  frame.querySelectorAll = () => [retry]
  controller.readRecovery()
  const event = action(controller.formTarget)
  controller.submit(event)
  assert.equal(event.prevented, true)
  assert.equal(retry.disabled, true)
  assert.equal(countdown.textContent, 'You can retry in 3 seconds.')
  context.mock.timers.tick(3000)
  assert.equal(retry.disabled, false)
  assert.equal(controller.submitButtonTarget.disabled, false)
  assert.equal(countdown.textContent, 'You can retry now.')
  assert.equal(countdown.getAttribute('aria-live'), 'polite')
})

test('previous results are retained only when the failed query and scope still match', () => {
  for (const [query, scope, retained] of [['Dune', 'title', true], ['Hobbit', 'title', false], ['Dune', 'author', false]]) {
    const { controller, frame } = setup('Dune')
    const gridCopy = {}
    const headerCopy = {}
    const detail = node()
    const appended = []
    const current = {
      dataset: { query: 'Dune', scope: 'title' },
      querySelector: selector => selector === '.search-results__grid'
        ? { children: [{}], cloneNode: () => gridCopy } : { cloneNode: () => headerCopy }
    }
    const incoming = {
      dataset: { query, scope, failed: 'true' },
      querySelectorAll: () => [], querySelector: () => detail,
      append: element => appended.push(element)
    }
    frame.querySelector = () => current
    const newFrame = { querySelector: () => incoming }
    controller.prepareResults(action(frame, { newFrame }))
    assert.deepEqual(appended, retained ? [headerCopy, gridCopy] : [])
    assert.equal(detail.textContent, retained ? 'Your previous results are still shown below.' : '')
  }
})
