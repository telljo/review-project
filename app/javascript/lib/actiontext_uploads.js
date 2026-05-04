// This app does not support file/image attachments inside the rich text editor.
// Prevent Trix from accepting them so Action Text never needs direct uploads.
addEventListener("trix-file-accept", (event) => {
  event.preventDefault()
}, true)
