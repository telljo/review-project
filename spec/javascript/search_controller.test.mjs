import test from 'node:test'
import assert from 'node:assert/strict'
import SearchController from '../../app/javascript/controllers/search_controller.js'

function node() {
  const attributes = new Map()
  const classes = new Set()
  return {
    value: '', hidden: false, disabled: false, maxLength: 500, textContent: '',
    innerHTML: '', focused: false,
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
  controller.loadingTemplateTarget.innerHTML = '<p>Loading</p>'
  controller.frameIdValue = frame.id
  controller.clearUrlValue = '/'
  controller.connect()
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
  const submission = {}
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
