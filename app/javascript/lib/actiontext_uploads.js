import { DirectUpload } from "@rails/activestorage"

function isEventTarget(value) {
  return value && typeof value.addEventListener === "function" && typeof value.dispatchEvent === "function"
}

function resolveEditorElement(event) {
  if (isEventTarget(event.target) && event.target.dataset?.directUploadUrl) {
    return event.target
  }

  if (typeof event.composedPath === "function") {
    return event.composedPath().find((node) => isEventTarget(node) && node.dataset?.directUploadUrl)
  }

  return null
}

function dispatchUploadEvent(element, type, detail = {}) {
  const event = new CustomEvent(type, {
    bubbles: true,
    cancelable: true,
    detail
  })

  if (!isEventTarget(element)) {
    return event
  }

  const disabled = "disabled" in element ? element.disabled : undefined

  try {
    if ("disabled" in element) {
      element.disabled = false
    }

    element.dispatchEvent(event)
  } finally {
    if ("disabled" in element) {
      element.disabled = disabled
    }
  }

  return event
}

class AttachmentUpload {
  constructor(attachment, element, file = attachment.file) {
    this.attachment = attachment
    this.element = element
    this.file = file
    this.directUpload = new DirectUpload(file, this.directUploadUrl, this)
  }

  start() {
    return new Promise((resolve, reject) => {
      this.directUpload.create((error, attributes) => {
        this.directUploadDidComplete(error, attributes, resolve, reject)
      })

      this.dispatch("start")
    })
  }

  directUploadWillStoreFileWithXHR(xhr) {
    xhr.upload.addEventListener("progress", (event) => {
      const progress = (event.loaded / event.total) * 90

      if (progress) {
        this.dispatch("progress", { progress })
      }
    })
  }

  directUploadDidComplete(error, attributes, resolve, reject) {
    if (error) {
      this.dispatchError(error, reject)
      return
    }

    resolve({
      sgid: attributes.attachable_sgid,
      url: this.blobUrlTemplate
        .replace(":signed_id", attributes.signed_id)
        .replace(":filename", encodeURIComponent(attributes.filename))
    })

    this.dispatch("end")
  }

  dispatch(name, detail = {}) {
    detail.attachment = this.attachment
    return dispatchUploadEvent(this.element, `direct-upload:${name}`, detail)
  }

  dispatchError(error, reject) {
    const event = this.dispatch("error", { error })

    if (!event.defaultPrevented) {
      reject(error)
    }
  }

  get directUploadUrl() {
    return this.element.dataset.directUploadUrl
  }

  get blobUrlTemplate() {
    return this.element.dataset.blobUrlTemplate
  }
}

// Rails' default Action Text listener assumes event.target is always a dispatchable
// editor element. In this app/runtime combination that is not consistently true,
// so we normalize the target and short-circuit the brittle upstream handler.
addEventListener("trix-attachment-add", (event) => {
  const { attachment } = event

  if (!(attachment?.file instanceof File)) {
    return
  }

  const element = resolveEditorElement(event)

  if (!element) {
    return
  }

  event.stopImmediatePropagation()

  const upload = new AttachmentUpload(attachment, element, attachment.file)
  const onProgress = (progressEvent) => {
    attachment.setUploadProgress(progressEvent.detail.progress)
  }

  element.addEventListener("direct-upload:progress", onProgress)

  upload
    .start()
    .then((attributes) => attachment.setAttributes(attributes))
    .catch((error) => alert(error))
    .finally(() => element.removeEventListener("direct-upload:progress", onProgress))
}, true)
