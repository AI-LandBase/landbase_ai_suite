import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form", "dropZone", "fileInput", "fileName",
    "submitButton", "loading", "error", "errorMessage",
    "clientCode"
  ]

  // --- サブクラスでオーバーライド ---
  get uploadUrl() { throw new Error("implement uploadUrl in subclass") }
  get sourceType() { throw new Error("implement sourceType in subclass") }
  get documentLabel() { return "明細" }

  connect() {
    this.file = null
  }

  openFileDialog() {
    this.fileInputTarget.click()
  }

  fileSelected(event) {
    const files = event.target.files
    if (files.length > 0) {
      this.setFile(files[0])
    }
  }

  dragOver(event) {
    event.preventDefault()
  }

  dragEnter(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.add("border-blue-500", "bg-blue-50")
  }

  dragLeave(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove("border-blue-500", "bg-blue-50")
  }

  drop(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove("border-blue-500", "bg-blue-50")
    const files = Array.from(event.dataTransfer.files).filter(f =>
      f.type === "application/pdf"
    )
    if (files.length > 0) {
      this.setFile(files[0])
    } else {
      this.showError("PDF形式のファイルのみ対応しています。")
    }
  }

  setFile(file) {
    if (file.type !== "application/pdf") {
      this.showError("PDF形式のファイルのみ対応しています。")
      return
    }
    if (file.size > 20 * 1024 * 1024) {
      this.showError("PDFファイルは20MB以下にしてください。")
      return
    }
    this.file = file
    this.fileNameTarget.textContent = file.name
    this.fileNameTarget.classList.remove("hidden")
    this.submitButtonTarget.disabled = false
    this.hideError()
  }

  async submit(event) {
    event.preventDefault()

    const clientCode = this.clientCodeTarget.value.trim()
    if (!clientCode) {
      this.showError("クライアントコードは必須です。")
      return
    }

    if (!this.file) {
      this.showError("PDFファイルを選択してください。")
      return
    }

    this.hideError()
    this.showLoading()
    this.submitButtonTarget.disabled = true

    const formData = new FormData()
    formData.append("pdf", this.file)
    formData.append("client_code", clientCode)
    try {
      const response = await fetch(this.uploadUrl, {
        method: "POST",
        body: formData,
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        }
      })

      const data = await response.json()

      if (response.status === 409 && data.duplicate) {
        this.showDuplicateError(data, formData)
        return
      }

      if (!response.ok) {
        this.showError(data.error || `${this.documentLabel}の処理に失敗しました。`)
        return
      }

      this.navigateToBatch(data.id)
    } catch (error) {
      this.showError(`通信エラー: ${error.message}`)
    } finally {
      this.hideLoading()
      this.submitButtonTarget.disabled = false
    }
  }

  async submitWithForce(formData) {
    this.hideError()
    this.showLoading()
    this.submitButtonTarget.disabled = true

    formData.set("force", "true")

    try {
      const response = await fetch(this.uploadUrl, {
        method: "POST",
        body: formData,
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        }
      })

      const data = await response.json()

      if (!response.ok) {
        this.showError(data.error || `${this.documentLabel}の処理に失敗しました。`)
        return
      }

      this.navigateToBatch(data.id)
    } catch (error) {
      this.showError(`通信エラー: ${error.message}`)
    } finally {
      this.hideLoading()
      this.submitButtonTarget.disabled = false
    }
  }

  navigateToBatch(batchId) {
    window.location.href = `/statement_batches/${batchId}`
  }

  showLoading() {
    this.loadingTarget.classList.remove("hidden")
  }

  hideLoading() {
    this.loadingTarget.classList.add("hidden")
  }

  showError(message) {
    this.clearDuplicateActions()
    this.errorMessageTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  // 409 重複時: メッセージに加えて「処理済みバッチを開く」リンクと「再処理する」操作を提示する。
  showDuplicateError(data, formData) {
    this.errorMessageTarget.textContent =
      `このファイルは既に処理済みです（バッチID ${data.existing_batch_id}）。`

    this.clearDuplicateActions()

    const actions = document.createElement("div")
    actions.dataset.duplicateActions = ""
    actions.className = "mt-3 flex items-center gap-4"

    if (data.existing_batch_url) {
      const link = document.createElement("a")
      link.href = data.existing_batch_url
      link.target = "_blank"
      link.rel = "noopener"
      link.textContent = "処理済みバッチを開く"
      link.className = "text-teal-400 hover:underline text-sm font-medium"
      actions.appendChild(link)
    }

    const reprocess = document.createElement("button")
    reprocess.type = "button"
    reprocess.textContent = "再処理する"
    reprocess.className = "text-sm text-gray-300 hover:text-white underline"
    reprocess.addEventListener("click", () => {
      this.hideError()
      this.submitWithForce(formData)
    })
    actions.appendChild(reprocess)

    this.errorTarget.appendChild(actions)
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    this.clearDuplicateActions()
    this.errorTarget.classList.add("hidden")
  }

  clearDuplicateActions() {
    this.errorTarget.querySelector("[data-duplicate-actions]")?.remove()
  }
}
