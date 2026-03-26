import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["staffName", "submitButton", "error", "errorMessage"]
  static values = { clientCode: String, manualId: Number }

  async start() {
    const staffName = this.staffNameTarget.value.trim()
    if (!staffName) {
      this.showError("担当者名を入力してください。")
      return
    }

    this.hideError()
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "開始中..."

    try {
      const formData = new FormData()
      formData.append("staff_name", staffName)
      formData.append("client_code", this.clientCodeValue)

      const response = await fetch(
        `/api/v1/cleaning_manuals/${this.manualIdValue}/cleaning_sessions?client_code=${encodeURIComponent(this.clientCodeValue)}`,
        {
          method: "POST",
          body: formData,
          headers: {
            "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
          }
        }
      )

      const data = await response.json()

      if (!response.ok) {
        this.showError(data.error || "セッションの開始に失敗しました。")
        return
      }

      window.location.href = `/cleaning_sessions/${data.id}?client_code=${encodeURIComponent(this.clientCodeValue)}`
    } catch (error) {
      this.showError(`通信エラー: ${error.message}`)
    } finally {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = "清掃を開始する"
    }
  }

  showError(message) {
    this.errorMessageTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    this.errorTarget.classList.add("hidden")
  }
}
