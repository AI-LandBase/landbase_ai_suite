import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "progressBar", "progressText", "progressPercent",
    "stepArea", "areaName", "stepTask", "stepDescription", "stepCheckpoint", "stepTime",
    "cameraInput", "cameraButton", "photoPreview", "photoGrid",
    "judgeButton", "skipButton", "suspendButton",
    "loading", "judgeResult", "judgeResultCard", "judgeResultBadge", "judgeResultLabel", "judgeResultFeedback",
    "completedArea", "reportLink",
    "error", "errorMessage", "retryButton"
  ]

  static values = { sessionId: Number, clientCode: String, manualName: String }

  connect() {
    this.files = []
    this.objectURLs = []
    this.abortController = null
    this.loadCurrentStep()
  }

  disconnect() {
    this.revokeObjectURLs()
    if (this.abortController) this.abortController.abort()
  }

  async loadCurrentStep() {
    try {
      // 中断中セッションの場合は自動再開
      const sessionRes = await this.apiFetch(`/api/v1/cleaning_sessions/${this.sessionIdValue}`)
      const session = await sessionRes.json()

      if (session.status === "suspended") {
        if (!confirm("中断中のセッションがあります。再開しますか？")) {
          window.location.href = `/cleaning_manuals?client_code=${encodeURIComponent(this.clientCodeValue)}`
          return
        }
        const resumeRes = await this.apiFetch(
          `/api/v1/cleaning_sessions/${this.sessionIdValue}/resume`,
          { method: "PATCH" }
        )
        if (!resumeRes.ok) {
          const err = await resumeRes.json()
          this.showError(err.error || "再開に失敗しました。")
          return
        }
      }

      const response = await this.apiFetch(`/api/v1/cleaning_sessions/${this.sessionIdValue}/current_step`)
      const data = await response.json()

      if (data.message) {
        this.showCompleted()
        return
      }

      this.updateStepDisplay(data)
      this.updateProgress(data.completed_steps, data.total_steps)
    } catch (error) {
      this.showError(`読み込みエラー: ${error.message}`)
    }
  }

  updateStepDisplay(step) {
    this.areaNameTarget.textContent = step.area_name
    this.stepTaskTarget.textContent = step.task
    this.stepDescriptionTarget.textContent = step.description || ""
    this.stepCheckpointTarget.textContent = step.checkpoint || ""
    this.stepTimeTarget.textContent = step.estimated_minutes ? `推定 ${step.estimated_minutes}分` : ""

    this.resetPhotoState()
    this.hideJudgeResult()
    this.hideError()
    this.stepAreaTarget.classList.remove("hidden")
    this.completedAreaTarget.classList.add("hidden")
  }

  updateProgress(completed, total) {
    const percent = total > 0 ? Math.round((completed / total) * 100) : 0
    this.progressTextTarget.textContent = `${completed} / ${total} ステップ完了`
    this.progressPercentTarget.textContent = `${percent}%`
    this.progressBarTarget.style.width = `${percent}%`
  }

  openCamera() {
    this.cameraInputTarget.click()
  }

  photosSelected(event) {
    const newFiles = Array.from(event.target.files)
    if (newFiles.length === 0) return

    this.files = [...this.files, ...newFiles]
    this.updatePhotoPreview()
    this.judgeButtonTarget.disabled = false
    this.cameraInputTarget.value = ""
  }

  updatePhotoPreview() {
    if (this.files.length === 0) {
      this.photoPreviewTarget.classList.add("hidden")
      return
    }

    this.photoPreviewTarget.classList.remove("hidden")
    this.revokeObjectURLs()
    this.photoGridTarget.innerHTML = ""

    this.files.forEach((file, index) => {
      const div = document.createElement("div")
      div.className = "relative group"

      const img = document.createElement("img")
      img.className = "w-full h-20 object-cover rounded-lg"
      const url = URL.createObjectURL(file)
      this.objectURLs.push(url)
      img.src = url

      const removeBtn = document.createElement("button")
      removeBtn.type = "button"
      removeBtn.className = "absolute top-0.5 right-0.5 bg-red-500 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs"
      removeBtn.textContent = "\u00d7"
      removeBtn.addEventListener("click", () => this.removePhoto(index))

      div.appendChild(img)
      div.appendChild(removeBtn)
      this.photoGridTarget.appendChild(div)
    })
  }

  removePhoto(index) {
    this.files.splice(index, 1)
    this.updatePhotoPreview()
    this.judgeButtonTarget.disabled = this.files.length === 0
  }

  resetPhotoState() {
    this.files = []
    this.revokeObjectURLs()
    this.photoPreviewTarget.classList.add("hidden")
    this.photoGridTarget.innerHTML = ""
    this.judgeButtonTarget.disabled = true
    this.cameraInputTarget.value = ""
  }

  revokeObjectURLs() {
    this.objectURLs.forEach(url => URL.revokeObjectURL(url))
    this.objectURLs = []
  }

  async judgeStep() {
    if (this.files.length === 0) return

    this.hideError()
    this.hideJudgeResult()
    this.showLoading()
    this.setButtonsEnabled(false)

    const formData = new FormData()
    formData.append("client_code", this.clientCodeValue)
    this.files.forEach(file => formData.append("photos[]", file))

    this.abortController = new AbortController()
    const timeoutId = setTimeout(() => this.abortController.abort(), 60000)

    try {
      const response = await fetch(
        `/api/v1/cleaning_sessions/${this.sessionIdValue}/judge?client_code=${encodeURIComponent(this.clientCodeValue)}`,
        {
          method: "POST",
          body: formData,
          headers: {
            "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
          },
          signal: this.abortController.signal
        }
      )

      const data = await response.json()

      if (!response.ok) {
        this.showError(data.error || "判定に失敗しました。")
        this.showRetryButton()
        this.setButtonsEnabled(true)
        return
      }

      this.showJudgeResult(data)
      this.updateProgress(data.completed_steps, data.total_steps)

      if (data.session_status === "completed") {
        setTimeout(() => this.showCompleted(), 2000)
      } else if (data.result === "ok" && data.next_step) {
        setTimeout(() => this.updateStepDisplay(data.next_step), 2000)
      } else if (data.result === "ng") {
        setTimeout(() => this.resetPhotoState(), 2000)
      }
    } catch (error) {
      if (error.name === "AbortError") {
        this.showError("判定がタイムアウトしました。再試行してください。")
      } else {
        this.showError(`通信エラー: ${error.message}`)
      }
      this.showRetryButton()
    } finally {
      clearTimeout(timeoutId)
      this.hideLoading()
      this.setButtonsEnabled(true)
      this.abortController = null
    }
  }

  cancelJudge() {
    if (this.abortController) {
      this.abortController.abort()
    }
  }

  retryJudge() {
    if (this.files.length === 0) {
      this.showError("写真を撮影してから再試行してください。")
      return
    }
    this.hideError()
    this.judgeStep()
  }

  async skipStep() {
    this.hideError()
    this.setButtonsEnabled(false)

    try {
      const response = await this.apiFetch(
        `/api/v1/cleaning_sessions/${this.sessionIdValue}/skip`,
        { method: "PATCH" }
      )

      const data = await response.json()

      if (!response.ok) {
        this.showError(data.error || "スキップに失敗しました。")
        return
      }

      this.updateProgress(data.completed_steps, data.total_steps)

      if (data.warning) {
        this.showError(data.warning)
      } else if (data.session_status === "completed") {
        this.showCompleted()
      } else if (data.next_step) {
        this.updateStepDisplay(data.next_step)
      } else {
        this.showCompleted()
      }
    } catch (error) {
      this.showError(`通信エラー: ${error.message}`)
    } finally {
      this.setButtonsEnabled(true)
    }
  }

  async suspend() {
    if (!confirm("清掃を中断しますか？後で再開できます。")) return

    try {
      const response = await this.apiFetch(
        `/api/v1/cleaning_sessions/${this.sessionIdValue}/suspend`,
        { method: "PATCH" }
      )

      if (response.ok) {
        window.location.href = `/cleaning_manuals?client_code=${encodeURIComponent(this.clientCodeValue)}`
      } else {
        const data = await response.json()
        this.showError(data.error || "中断に失敗しました。")
      }
    } catch (error) {
      this.showError(`通信エラー: ${error.message}`)
    }
  }

  showLoading() {
    this.loadingTarget.classList.remove("hidden")
  }

  hideLoading() {
    this.loadingTarget.classList.add("hidden")
  }

  showJudgeResult(data) {
    this.judgeResultTarget.classList.remove("hidden")

    if (data.result === "ok") {
      this.judgeResultCardTarget.className = "bg-green-950 border border-green-700 shadow rounded-lg p-4"
      this.judgeResultBadgeTarget.className = "text-sm font-medium px-2.5 py-0.5 rounded-full bg-green-900 text-green-400"
      this.judgeResultBadgeTarget.textContent = "OK"
      this.judgeResultLabelTarget.className = "text-sm font-medium text-green-400"
      this.judgeResultLabelTarget.textContent = "合格"
      this.judgeResultFeedbackTarget.className = "text-sm text-green-300"
    } else {
      this.judgeResultCardTarget.className = "bg-red-950 border border-red-700 shadow rounded-lg p-4"
      this.judgeResultBadgeTarget.className = "text-sm font-medium px-2.5 py-0.5 rounded-full bg-red-900 text-red-400"
      this.judgeResultBadgeTarget.textContent = "NG"
      this.judgeResultLabelTarget.className = "text-sm font-medium text-red-400"
      this.judgeResultLabelTarget.textContent = "修正が必要です"
      this.judgeResultFeedbackTarget.className = "text-sm text-red-300"
    }

    this.judgeResultFeedbackTarget.textContent = data.feedback || ""
  }

  hideJudgeResult() {
    this.judgeResultTarget.classList.add("hidden")
  }

  showCompleted() {
    this.stepAreaTarget.classList.add("hidden")
    this.completedAreaTarget.classList.remove("hidden")
    this.reportLinkTarget.href = `/cleaning_sessions/${this.sessionIdValue}/report?client_code=${encodeURIComponent(this.clientCodeValue)}`
  }

  showError(message) {
    this.errorMessageTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    this.errorTarget.classList.add("hidden")
    this.retryButtonTarget.classList.add("hidden")
  }

  showRetryButton() {
    this.retryButtonTarget.classList.remove("hidden")
  }

  setButtonsEnabled(enabled) {
    this.judgeButtonTarget.disabled = !enabled || this.files.length === 0
    this.skipButtonTarget.disabled = !enabled
    this.cameraButtonTarget.disabled = !enabled
    this.suspendButtonTarget.disabled = !enabled
  }

  async apiFetch(url, options = {}) {
    const separator = url.includes("?") ? "&" : "?"
    const fullUrl = `${url}${separator}client_code=${encodeURIComponent(this.clientCodeValue)}`

    return fetch(fullUrl, {
      ...options,
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
        ...(options.headers || {})
      }
    })
  }
}
