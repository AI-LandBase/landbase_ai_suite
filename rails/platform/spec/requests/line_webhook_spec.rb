require "rails_helper"

RSpec.describe "LineWebhook", type: :request do
  let(:channel_secret) { "test_channel_secret" }
  let(:channel_token) { "test_channel_token" }
  let(:default_client_code) { "parijona" }
  let(:client) { create(:client, code: default_client_code, name: "Parijona") }
  let(:follower_user_id) { "U1234567890abcdef1234567890abcdef" }
  let!(:follower) { create(:line_follower, client: client, line_user_id: follower_user_id) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("LINE_CHANNEL_SECRET").and_return(channel_secret)
    allow(ENV).to receive(:fetch).with("LINE_CHANNEL_TOKEN").and_return(channel_token)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("LINE_DEFAULT_CLIENT_CODE").and_return(default_client_code)
  end

  def sign_body(body)
    digest = OpenSSL::HMAC.digest("SHA256", channel_secret, body)
    Base64.strict_encode64(digest)
  end

  def post_webhook(body_hash)
    body = body_hash.to_json
    signature = sign_body(body)
    post "/webhook/line", params: body, headers: {
      "Content-Type" => "application/json",
      "X-Line-Signature" => signature
    }
  end

  def image_event(user_id: follower_user_id, message_id: "msg_001", reply_token: "reply_token_001")
    {
      "type" => "message",
      "replyToken" => reply_token,
      "source" => { "type" => "user", "userId" => user_id },
      "message" => { "type" => "image", "id" => message_id }
    }
  end

  def follow_event(user_id: follower_user_id, reply_token: "reply_token_002")
    {
      "type" => "follow",
      "replyToken" => reply_token,
      "source" => { "type" => "user", "userId" => user_id }
    }
  end

  describe "POST /webhook/line" do
    describe "署名検証" do
      it "正しい署名で200を返すこと" do
        post_webhook({ "events" => [] })
        expect(response).to have_http_status(:ok)
      end

      it "署名なしで401を返すこと" do
        post "/webhook/line",
             params: { "events" => [] }.to_json,
             headers: { "Content-Type" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "不正な署名で401を返すこと" do
        post "/webhook/line",
             params: { "events" => [] }.to_json,
             headers: {
               "Content-Type" => "application/json",
               "X-Line-Signature" => "invalid_signature"
             }
        expect(response).to have_http_status(:unauthorized)
      end

      it "不正なJSONボディで400を返すこと" do
        invalid_body = "not json"
        signature = sign_body(invalid_body)
        post "/webhook/line",
             params: invalid_body,
             headers: {
               "Content-Type" => "application/json",
               "X-Line-Signature" => signature
             }
        expect(response).to have_http_status(:bad_request)
      end
    end

    describe "画像メッセージ処理" do
      it "登録済みフォロワーからの画像でジョブをエンキューすること" do
        allow(ReceiptLineProcessJob).to receive(:perform_later)

        post_webhook({ "events" => [image_event] })

        expect(response).to have_http_status(:ok)
        expect(ReceiptLineProcessJob).to have_received(:perform_later).with(
          client_id: client.id,
          message_id: "msg_001",
          line_user_id: follower_user_id
        )
      end

      it "未登録ユーザーからの画像でエラーメッセージを返信すること" do
        allow(ReceiptLineProcessJob).to receive(:perform_later)
        line_response = instance_double(Net::HTTPSuccess, is_a?: true, code: "200", body: "{}")
        allow(Net::HTTP).to receive(:start).and_return(line_response)

        post_webhook({ "events" => [image_event(user_id: "U_unknown_user")] })

        expect(response).to have_http_status(:ok)
        expect(ReceiptLineProcessJob).not_to have_received(:perform_later)
      end

      it "テキストメッセージは無視されること" do
        allow(ReceiptLineProcessJob).to receive(:perform_later)

        text_event = {
          "type" => "message",
          "replyToken" => "reply_token_003",
          "source" => { "type" => "user", "userId" => follower_user_id },
          "message" => { "type" => "text", "text" => "こんにちは" }
        }
        post_webhook({ "events" => [text_event] })

        expect(response).to have_http_status(:ok)
        expect(ReceiptLineProcessJob).not_to have_received(:perform_later)
      end
    end

    describe "Follow Event処理" do
      let(:line_response) { instance_double(Net::HTTPSuccess, is_a?: true, code: "200", body: "{}") }

      before do
        allow(Net::HTTP).to receive(:start).and_return(line_response)
      end

      it "新規ユーザーのフォローでLineFollowerが自動作成され、ウェルカムメッセージが返信されること" do
        new_user_id = "U_brand_new_follower" + "0" * 12

        expect {
          post_webhook({ "events" => [follow_event(user_id: new_user_id)] })
        }.to change(LineFollower, :count).by(1)

        expect(response).to have_http_status(:ok)
        created = LineFollower.find_by(line_user_id: new_user_id)
        expect(created.client).to eq(client)
      end

      it "既存ユーザーのフォローでは新規作成されない（idempotent）" do
        expect {
          post_webhook({ "events" => [follow_event] })
        }.not_to change(LineFollower, :count)

        expect(response).to have_http_status(:ok)
      end

      it "LINE_DEFAULT_CLIENT_CODEのClientが存在しない場合は登録せず案内メッセージを返信" do
        allow(ENV).to receive(:[]).with("LINE_DEFAULT_CLIENT_CODE").and_return("nonexistent")

        expect {
          post_webhook({ "events" => [follow_event(user_id: "U_unmapped" + "0" * 24)] })
        }.not_to change(LineFollower, :count)

        expect(response).to have_http_status(:ok)
      end

      it "LINE_DEFAULT_CLIENT_CODE未設定の場合は登録しないこと" do
        allow(ENV).to receive(:[]).with("LINE_DEFAULT_CLIENT_CODE").and_return(nil)

        expect {
          post_webhook({ "events" => [follow_event(user_id: "U_no_default" + "0" * 21)] })
        }.not_to change(LineFollower, :count)

        expect(response).to have_http_status(:ok)
      end
    end

    describe "複数イベント" do
      it "複数イベントを順に処理すること" do
        allow(ReceiptLineProcessJob).to receive(:perform_later)
        line_response = instance_double(Net::HTTPSuccess, is_a?: true, code: "200", body: "{}")
        allow(Net::HTTP).to receive(:start).and_return(line_response)
        new_follower_id = "U_new_follower" + "0" * 18

        post_webhook({
          "events" => [
            image_event(message_id: "msg_001", reply_token: "rt_001"),
            follow_event(user_id: new_follower_id, reply_token: "rt_002")
          ]
        })

        expect(response).to have_http_status(:ok)
        expect(ReceiptLineProcessJob).to have_received(:perform_later).once
        expect(LineFollower.find_by(line_user_id: new_follower_id)).to be_present
      end
    end
  end
end
