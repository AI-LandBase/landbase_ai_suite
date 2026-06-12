import { Controller } from "@hotwired/stimulus"

// 削除など破壊的操作の前に2段階の confirm を挟む。
// どちらかキャンセルされた時点で submit を中断する。
//
// 使い方:
//   <%= button_to "削除", path, method: :delete,
//       form: {
//         data: {
//           controller: "double-confirm",
//           action: "submit->double-confirm#confirm",
//           double_confirm_first_message_value: "削除してよろしいですか？",
//           double_confirm_second_message_value: "本当に削除しますか？元に戻せません。"
//         }
//       } %>
export default class extends Controller {
  static values = {
    firstMessage: { type: String, default: "削除してよろしいですか？" },
    secondMessage: { type: String, default: "本当に削除しますか？元に戻せません。" }
  }

  confirm(event) {
    if (window.confirm(this.firstMessageValue) && window.confirm(this.secondMessageValue)) {
      return
    }
    event.preventDefault()
    event.stopPropagation()
  }
}
