import test from 'node:test'
import assert from 'node:assert/strict'
import ShelfFormController from '../../app/javascript/controllers/shelf_form_controller.js'

function formController() {
  const attributes = new Map()
  const form = {
    setAttribute: (name, value) => attributes.set(name, value),
    removeAttribute: name => attributes.delete(name)
  }
  const status = { textContent: '', setAttribute: (name, value) => attributes.set(`status-${name}`, value) }
  const controller = new ShelfFormController({ scope: { element: form } })
  Object.defineProperty(controller, 'statusTarget', { value: status })
  return { controller, status, attributes }
}

test('a network failure ends the busy state and offers a retry', () => {
  const { controller, status, attributes } = formController()
  controller.start()
  assert.equal(attributes.get('aria-busy'), 'true')
  controller.finish({ detail: { error: new TypeError('Failed to fetch') } })
  assert.equal(attributes.has('aria-busy'), false)
  assert.equal(attributes.get('status-role'), 'alert')
  assert.match(status.textContent, /choice is still selected\. Try again/)
})

test('retry replaces the error with pending feedback and clears it on a response', () => {
  const { controller, status, attributes } = formController()
  controller.finish({ detail: { error: new TypeError('Failed to fetch') } })
  controller.start()
  assert.equal(attributes.get('status-role'), 'status')
  assert.match(status.textContent, /Saving/)
  controller.finish({ detail: { success: false, fetchResponse: { statusCode: 422 } } })
  assert.equal(status.textContent, '')
  assert.equal(attributes.has('aria-busy'), false)
})
