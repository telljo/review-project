import test from 'node:test'
import assert from 'node:assert/strict'
import BookshelfController from '../../app/javascript/controllers/bookshelf_controller.js'

function layout(items, { outerTop = 0, gridTop = 0, gridHeight = 200 } = {}) {
  const element = {
    clientHeight: gridHeight,
    querySelectorAll: () => items,
    getBoundingClientRect: () => ({ top: outerTop + gridTop })
  }
  const controller = new BookshelfController({ scope: { element } })
  controller.outer = { clientHeight: 200, getBoundingClientRect: () => ({ top: outerTop }) }
  controller.plankContainer = {}
  controller.shadowContainer = {}
  let rows
  controller.renderRows = bottoms => { rows = bottoms }
  controller.layoutShelves()
  return rows
}

function book(top, coverHeight, totalHeight, { coverOffset = 0, lift = 0, pageTop = 0 } = {}) {
  const renderedTop = pageTop + top - lift
  return {
    offsetTop: top,
    getBoundingClientRect: () => ({ top: renderedTop, bottom: renderedTop + totalHeight }),
    querySelector: () => ({ getBoundingClientRect: () => ({ bottom: renderedTop + coverOffset + coverHeight }) })
  }
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

test('owner controls above a cover do not leave the plank crossing through it', () => {
  assert.deepEqual(layout([book(4, 180, 320, { coverOffset: 44 })]), [228])
})

test('page position, grid inset, and hover lift do not detach a cover from its shelf', () => {
  assert.deepEqual(layout([
    book(4, 180, 300, { pageTop: 732, lift: 4 }),
    book(360, 180, 310, { pageTop: 732 })
  ], { outerTop: 700, gridTop: 32 }), [216, 572])
})

test('an empty shelf rests under its content inside the padded bookcase caps', () => {
  const originalGetComputedStyle = globalThis.getComputedStyle
  globalThis.getComputedStyle = () => ({ paddingBottom: '32px' })
  try {
    assert.deepEqual(layout([], { outerTop: 700, gridTop: 52, gridHeight: 260 }), [280])
  } finally {
    if (originalGetComputedStyle) globalThis.getComputedStyle = originalGetComputedStyle
    else delete globalThis.getComputedStyle
  }
})
