import { Controller } from "@hotwired/stimulus";
import Sortable from 'sortablejs';
import { patch } from "@rails/request.js"

export default class extends Controller {
  connect() {

    const sourceId = this.data.get("source-id");
    const sourceList = document.getElementById(sourceId);

    this.sortable = Sortable.create(sourceList, {
      animation: 150,
      sort: false,
      group: {
        name:  "shared",
      },
      onEnd: this.end.bind(this)
    })
  }

  end(event) {;
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
}