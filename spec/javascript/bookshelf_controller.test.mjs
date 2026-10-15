import test from 'node:test'
import assert from 'node:assert/strict'
import BookshelfController from '../../app/javascript/controllers/bookshelf_controller.js'

function layout(items) {
  const controller = new BookshelfController({ scope: { element: { querySelectorAll: () => items } } })
  controller.outer = { clientHeight: 200 }
  controller.plankContainer = {}
  controller.shadowContainer = {}
  let rows
  controller.renderRows = bottoms => { rows = bottoms }
  controller.layoutShelves()
  return rows
}

function book(top, coverHeight, totalHeight) {
  return { offsetTop: top, offsetHeight: totalHeight, querySelector: () => ({ offsetHeight: coverHeight }) }
}

test('wood stays beneath covers when title and author heights vary', () => {
  assert.deepEqual(layout([book(4, 180, 260), book(4, 180, 320)]), [184])
})

test('wrapping creates one plank per row in visual order', () => {
  assert.deepEqual(layout([book(400, 160, 250), book(4, 160, 290), book(4, 160, 250)]), [164, 560])
})

test('each row follows its resized covers instead of the previous width', () => {
  assert.deepEqual(layout([book(4, 220, 320), book(360, 220, 300)]), [224, 580])
  assert.deepEqual(layout([book(4, 150, 250), book(4, 150, 230)]), [154])
})
