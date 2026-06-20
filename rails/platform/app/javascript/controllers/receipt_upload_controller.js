import { Controller } from "@hotwired/stimulus"

// 複数の領収書画像を1枚ずつ順次 /api/v1/receipts/process_receipt にPOSTする。
// 1画像 = 1 StatementBatch（LINE経由と同じ粒度）。各結果をリスト表示する。
export default class extends Controller {
  static targets = [
    "form", "dropZone", "fileInput", "preview", "fileCount",
    "submitButton", "loading", "loadingText", "error", "errorMessage",
    "result", "resultList", "clientCode"
  ]

  static ALLOWED = ["image/jpeg", "image/png", "image/webp"]
  static MAX_SIZE = 20 * 1024 * 1024

  connect() {
    this.files = []
    this.objectURLs = []
  }

  disconnect() {
    this.revokeURLs()
  }

  openFileDialog() {
    this.fileInputTarget.click()
  }

  filesSelected(event) {
    this.addFiles(Array.from(event.target.files))
  }

  dragOver(event) { event.preventDefault() }

  dragEnter(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.add("border-teal-500", "bg-gray-800")
  }

  dragLeave(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove("border-teal-500", "bg-gray-800")
  }

  drop(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove("border-teal-500", "bg-gray-800")
    const files = Array.from(event.dataTransfer.files).filter(f =>
      this.constructor.ALLOWED.includes(f.type)
    )
    if (files.length === 0) {
      this.showError("JPEG / PNG / WebP 形式の画像のみ対応しています。")
      return
    }
    this.addFiles(files)
  }

  addFiles(newFiles) {
    const valid = newFiles.filter(f => {
      if (!this.constructor.ALLOWED.includes(f.type)) return false
      if (f.size > this.constructor.MAX_SIZE) {
        this.showError(`${f.name} は20MBを超えています。`)
        return false
      }
      return true
    })
    this.files = [...this.files, ...valid]
    this.updatePreview()
    this.updateFileCount()
    this.submitButtonTarget.disabled = this.files.length === 0
  }

  removeFile(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.files.splice(index, 1)
    this.updatePreview()
    this.updateFileCount()
    this.submitButtonTarget.disabled = this.files.length === 0
  }

  updatePreview() {
    if (this.files.length === 0) {
      this.previewTarget.classList.add("hidden")
      this.previewTarget.innerHTML = ""
      return
    }

    this.previewTarget.classList.remove("hidden")
    this.revokeURLs()
    this.previewTarget.innerHTML = ""

    this.files.forEach((file, index) => {
      const div = document.createElement("div")
      div.className = "relative group"

      const img = document.createElement("img")
      img.className = "w-full h-24 object-cover rounded-lg"
      const objectURL = URL.createObjectURL(file)
      this.objectURLs.push(objectURL)
      img.src = objectURL

      const removeBtn = document.createElement("button")
      removeBtn.type = "button"
      removeBtn.className = "absolute top-1 right-1 bg-red-500 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity"
      removeBtn.textContent = "×"
      removeBtn.dataset.index = index
      removeBtn.dataset.action = "click->receipt-upload#removeFile"

      const label = document.createElement("p")
      label.className = "text-xs text-gray-400 mt-1 truncate"
      label.textContent = file.name

      div.appendChild(img)
      div.appendChild(removeBtn)
      div.appendChild(label)
      this.previewTarget.appendChild(div)
    })
  }

  updateFileCount() {
    this.fileCountTarget.textContent = this.files.length === 0
      ? "画像が選択されていません"
      : `${this.files.length}枚の画像が選択されています`
  }

  async submit(event) {
    event.preventDefault()

    const clientCode = this.clientCodeTarget.value.trim()
    if (!clientCode) {
      this.showError("クライアントコードは必須です。")
      return
    }
    if (this.files.length === 0) {
      this.showError("画像を1枚以上アップロードしてください。")
      return
    }

    this.hideError()
    this.showResultList()
    this.resultListTarget.innerHTML = ""
    this.showLoading()
    this.submitButtonTarget.disabled = true

    const total = this.files.length
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    for (let i = 0; i < total; i++) {
      const file = this.files[i]
      this.loadingTextTarget.textContent = `処理中... (${i + 1}/${total}) ${file.name}`
      await this.uploadOne(file, clientCode, csrfToken)
    }

    this.hideLoading()
    this.submitButtonTarget.disabled = false
    this.resetFiles()
  }

  async uploadOne(file, clientCode, csrfToken) {
    const formData = new FormData()
    formData.append("image", file)
    formData.append("client_code", clientCode)

    try {
      const response = await fetch("/api/v1/receipts/process_receipt", {
        method: "POST",
        body: formData,
        headers: { "X-CSRF-Token": csrfToken }
      })
      const data = await response.json()

      if (response.status === 409 && data.duplicate) {
        this.appendResult(file.name, "duplicate", "処理済み（重複）", data.existing_batch_id)
        return
      }
      if (!response.ok) {
        this.appendResult(file.name, "error", data.error || "処理に失敗しました")
        return
      }
      this.appendResult(file.name, "accepted", "受付完了・処理中", data.id)
    } catch (error) {
      this.appendResult(file.name, "error", `通信エラー: ${error.message}`)
    }
  }

  appendResult(fileName, kind, message, batchId) {
    const colors = {
      accepted: "text-teal-400",
      duplicate: "text-yellow-400",
      error: "text-red-400"
    }
    const li = document.createElement("li")
    li.className = "flex items-center justify-between gap-3 py-2 border-b border-gray-700 text-sm"

    const left = document.createElement("span")
    left.className = "truncate text-gray-300"
    left.textContent = fileName

    const right = document.createElement("span")
    right.className = `flex-shrink-0 ${colors[kind] || "text-gray-400"}`

    if (batchId && (kind === "accepted" || kind === "duplicate")) {
      const link = document.createElement("a")
      link.href = `/statement_batches/${batchId}`
      link.target = "_blank"
      link.rel = "noopener"
      link.className = "hover:underline"
      link.textContent = message + " →"
      right.appendChild(link)
    } else {
      right.textContent = message
    }

    li.appendChild(left)
    li.appendChild(right)
    this.resultListTarget.appendChild(li)
  }

  resetFiles() {
    this.files = []
    this.fileInputTarget.value = ""
    this.revokeURLs()
    this.previewTarget.classList.add("hidden")
    this.previewTarget.innerHTML = ""
    this.updateFileCount()
    this.submitButtonTarget.disabled = true
  }

  revokeURLs() {
    this.objectURLs.forEach(url => URL.revokeObjectURL(url))
    this.objectURLs = []
  }

  showLoading() { this.loadingTarget.classList.remove("hidden") }
  hideLoading() { this.loadingTarget.classList.add("hidden") }
  showResultList() { this.resultTarget.classList.remove("hidden") }
  showError(message) {
    this.errorMessageTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }
  hideError() { this.errorTarget.classList.add("hidden") }
}
