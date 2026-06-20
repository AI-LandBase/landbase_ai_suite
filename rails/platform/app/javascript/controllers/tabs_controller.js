import { Controller } from "@hotwired/stimulus"

// 詳細ページ内のタブ切り替え（仕訳詳細 / 編集履歴）。
// data-controller="tabs" 下に data-tabs-target="tab"（data-tab-name 付き）と
// data-tabs-target="panel"（data-tab-name 付き）を配置する。
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.showTab(this.tabTargets[0]?.dataset.tabName)
  }

  switch(event) {
    event.preventDefault()
    this.showTab(event.currentTarget.dataset.tabName)
  }

  showTab(name) {
    if (!name) return

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.tabName !== name)
    })

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tabName === name
      tab.classList.toggle("border-teal-500", active)
      tab.classList.toggle("text-teal-400", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("text-gray-400", !active)
    })
  }
}
