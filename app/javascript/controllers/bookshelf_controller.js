import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bookshelf"
export default class extends Controller {
  connect() {
    this.outer = this.element.closest(".books__outer_grid_layout")
    if (!this.outer) return

    this.plankContainer = this.outer.querySelector(".books__shelf_plank")
    this.shadowContainer = this.outer.querySelector(".books__shelf_shadow")
    if (!this.plankContainer || !this.shadowContainer) return

    this.scheduleLayout = this.scheduleLayout.bind(this)

    this.resizeObserver = new ResizeObserver(this.scheduleLayout)
    this.resizeObserver.observe(this.element)
    this.resizeObserver.observe(this.outer)

    this.mutationObserver = new MutationObserver(this.scheduleLayout)
    this.mutationObserver.observe(this.element, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["class", "style", "aria-hidden"]
    })

    window.addEventListener("resize", this.scheduleLayout)
    this.scheduleLayout()
  }

  disconnect() {
    window.removeEventListener("resize", this.scheduleLayout)
    if (this.resizeObserver) this.resizeObserver.disconnect()
    if (this.mutationObserver) this.mutationObserver.disconnect()
  }

  scheduleLayout() {
    if (this.layoutFrame) cancelAnimationFrame(this.layoutFrame)
    this.layoutFrame = requestAnimationFrame(() => this.layoutShelves())
  }

  layoutShelves() {
    if (!this.outer || !this.plankContainer || !this.shadowContainer) return

    const items = Array.from(this.element.querySelectorAll(".books__item"))
    const rowBottoms = []

    if (items.length > 0) {
      const rows = new Map()

      items.forEach((item) => {
        const rowKey = Math.round(item.offsetTop)
        const itemBottom = item.offsetTop + item.offsetHeight
        const previousBottom = rows.get(rowKey) || 0
        rows.set(rowKey, Math.max(previousBottom, itemBottom))
      })

      rowBottoms.push(...Array.from(rows.entries()).sort((a, b) => a[0] - b[0]).map(([, bottom]) => bottom))
    } else {
      const computed = getComputedStyle(this.element)
      const paddingBottom = parseFloat(computed.paddingBottom) || 0
      const outerHeight = this.outer.clientHeight
      rowBottoms.push(Math.max(0, outerHeight - paddingBottom))
    }

    this.renderRows(rowBottoms)
  }

  renderRows(rowBottoms) {
    this.plankContainer.replaceChildren()
    this.shadowContainer.replaceChildren()

    rowBottoms.forEach((bottom) => {
      const plank = document.createElement("div")
      plank.className = "books__shelf_row"
      plank.style.top = `${bottom}px`
      this.plankContainer.appendChild(plank)

      const shadow = document.createElement("div")
      shadow.className = "books__shelf_shadow_row"
      shadow.style.top = `${bottom}px`
      this.shadowContainer.appendChild(shadow)
    })
  }
}
