import { Controller } from "@hotwired/stimulus";
import Sortable from 'sortablejs';
import { patch } from "@rails/request.js"

export default class extends Controller {
  connect() {
    const sourceId = this.data.get("source-id");
    const sourceList = document.getElementById(sourceId);

    if (!sourceList) return;

    this.sourceList = sourceList;
    this.updateEmptyState(sourceList);

    this.sortable = Sortable.create(sourceList, {
      animation: 180,
      draggable: ".books__item",
      filter: ".books__menu, .books__menu *",
      fallbackTolerance: 4,
      delay: 150,
      delayOnTouchOnly: true,
      preventOnFilter: false,
      sort: true,
      scroll: true,
      bubbleScroll: true,
      scrollSensitivity: 80,
      scrollSpeed: 18,
      ghostClass: "books__item--ghost",
      chosenClass: "books__item--chosen",
      dragClass: "books__item--dragging",
      group: {
        name:  "shared",
      },
      onStart: this.start.bind(this),
      onMove: this.move.bind(this),
      onEnd: this.end.bind(this)
    })
  }

  disconnect() {
    this.clearDropHover();
    if (this.sortable) this.sortable.destroy();
  }

  start() {
    document.body.dataset.sortingBooks = "true";
    if (this.sourceList) this.sourceList.dataset.dragging = "true";
    this.clearDropHover();
  }

  move(event) {
    this.setDropHover(event.to);
    return true;
  }

  end(event) {
    delete document.body.dataset.sortingBooks;
    if (event.from) delete event.from.dataset.dragging;
    if (event.to) delete event.to.dataset.dragging;
    this.clearDropHover();
    this.updateEmptyState(event.from);
    this.updateEmptyState(event.to);

    const destination = event.to.dataset.sortableSourceId;
    let slug = "";

    switch(destination) {
      case "toReadList":
        slug = "want_to_read"
        break;
      case "currentlyReadingList":
        slug = "reading"
        break;
      case "readList":
        slug = "read"
    }

    let id = event.item.dataset.id
    let data = new FormData()

    data.append("position", event.newIndex + 1);
    data.append("slug", slug);

    patch(this.data.get("url").replace(":id", id),{
      body: data,
    })
  }

  updateEmptyState(list) {
    if (!list) return;

    const hasBooks = list.querySelector(".books__item") !== null;
    list.classList.toggle("books__grid_layout--empty", !hasBooks);

    const placeholder = list.querySelector(".books__empty_placeholder");
    if (placeholder) placeholder.setAttribute("aria-hidden", hasBooks ? "true" : "false");
  }

  setDropHover(list) {
    this.clearDropHover();

    if (!list || !list.classList.contains("books__grid_layout--empty")) return;

    list.dataset.dropHover = "true";
  }

  clearDropHover() {
    document
      .querySelectorAll(".books__grid_layout[data-drop-hover='true']")
      .forEach((list) => delete list.dataset.dropHover);
  }
}
