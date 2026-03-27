class MonthlyReportsController < ApplicationController
  include ActionView::Helpers::SanitizeHelper

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  before_action :set_client
  before_action :set_report, only: [ :show, :destroy ]

  def index
    @reports = if @client
                 MonthlyReport.for_client(@client_code).recent
               else
                 MonthlyReport.none
               end
  end

  def show
    @rendered_content = render_markdown(@report.content)
  end

  def generate
    year_month = params[:year_month]
    if year_month.blank?
      redirect_to monthly_reports_path(client_code: @client_code), alert: "対象年月を指定してください"
      return
    end

    unless @client
      redirect_to monthly_reports_path(client_code: @client_code), alert: "クライアントが見つかりません"
      return
    end

    service = MonthlyReportGeneratorService.new(client: @client, year_month: year_month)
    result = service.call

    if result.success?
      redirect_to monthly_report_path(result.data, client_code: @client_code), notice: "#{year_month} のレポートを生成しました"
    else
      redirect_to monthly_reports_path(client_code: @client_code), alert: "レポート生成に失敗しました: #{result.error}"
    end
  end

  def destroy
    @report.destroy!
    redirect_to monthly_reports_path(client_code: @client_code), notice: "レポートを削除しました"
  end

  private

  def set_client
    @client_code = params[:client_code] || ""
    @client = Client.find_by(code: @client_code)
  end

  def set_report
    @report = MonthlyReport.for_client(@client_code).find(params[:id])
  end

  def record_not_found
    redirect_to monthly_reports_path(client_code: @client_code), alert: "レポートが見つかりません"
  end

  ALLOWED_TAGS = %w[h1 h2 h3 h4 h5 h6 p a ul ol li table thead tbody tr th td
                    strong em del code pre blockquote br hr mark sup sub].freeze
  ALLOWED_ATTRIBUTES = %w[href target rel class].freeze

  def render_markdown(text)
    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener" }
    )
    markdown = Redcarpet::Markdown.new(renderer,
      tables: true,
      fenced_code_blocks: true,
      autolink: true,
      strikethrough: true,
      highlight: true
    )
    raw_html = markdown.render(text)
    sanitize(raw_html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
  end
end
