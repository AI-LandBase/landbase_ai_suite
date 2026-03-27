require "prawn"
require "prawn/table"
require "nokogiri"

class MonthlyReportPdfService
  FONT_PATH = Rails.root.join("app/assets/fonts")

  def initialize(report:)
    @report = report
    @client = report.client
  end

  def call
    pdf = Prawn::Document.new(
      page_size: "A4",
      margin: [ 40, 40, 40, 40 ],
      info: {
        Title: "#{@report.display_year_month} Monthly Report",
        Author: "LandBase AI Suite",
        Creator: "LandBase AI Suite",
        CreationDate: @report.generated_at || Time.current
      }
    )

    @japanese_available = register_fonts(pdf)
    render_header(pdf)
    render_html_body(pdf)
    render_footer(pdf)

    pdf.render
  end

  private

  # === フォント登録 ===

  JAPANESE_FONT_PATHS = %w[
    /usr/share/fonts/opentype/ipafont-gothic/ipag.ttf
    /usr/share/fonts/truetype/fonts-japanese-gothic.ttf
    /usr/share/fonts/ipa-gothic/ipag.ttf
  ].freeze

  def register_fonts(pdf)
    if FONT_PATH.exist? && FONT_PATH.join("NotoSansJP-Regular.ttf").exist?
      pdf.font_families.update(
        "NotoSansJP" => {
          normal: FONT_PATH.join("NotoSansJP-Regular.ttf").to_s,
          bold: FONT_PATH.join("NotoSansJP-Bold.ttf").to_s
        }
      )
      pdf.font "NotoSansJP"
      return true
    end

    ipa_path = JAPANESE_FONT_PATHS.find { |path| File.exist?(path) }
    if ipa_path
      pdf.font_families.update(
        "IPAGothic" => { normal: ipa_path, bold: ipa_path }
      )
      pdf.font "IPAGothic"
      return true
    end

    false
  rescue Prawn::Errors::UnknownFont, ArgumentError
    false
  end

  # === Markdown → HTML → PDF（Web画面と同一パイプライン）===

  def markdown_to_html(text)
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer,
      tables: true,
      fenced_code_blocks: true,
      autolink: true,
      strikethrough: true,
      highlight: true
    )
    markdown.render(text)
  end

  def render_html_body(pdf)
    html = markdown_to_html(@report.content)
    doc = Nokogiri::HTML.fragment(html)

    doc.children.each do |node|
      render_node(pdf, node)
    end
  end

  def render_node(pdf, node)
    case node.name
    when "h1"
      pdf.move_down 10
      safe_text pdf, node.text.strip, size: 16, style: :bold
      pdf.move_down 2
      pdf.stroke_horizontal_rule
      pdf.move_down 8
    when "h2"
      pdf.move_down 10
      safe_text pdf, node.text.strip, size: 14, style: :bold
      pdf.move_down 2
      pdf.stroke_horizontal_rule
      pdf.move_down 6
    when "h3"
      pdf.move_down 8
      safe_text pdf, node.text.strip, size: 12, style: :bold
      pdf.move_down 4
    when "h4", "h5", "h6"
      pdf.move_down 6
      safe_text pdf, node.text.strip, size: 11, style: :bold
      pdf.move_down 4
    when "p"
      text = node.text.strip
      safe_text(pdf, text, size: 10, leading: 4) if text.present?
      pdf.move_down 4
    when "ul"
      render_unordered_list(pdf, node)
    when "ol"
      render_ordered_list(pdf, node)
    when "table"
      render_table(pdf, node)
    when "hr"
      pdf.move_down 6
      pdf.stroke_horizontal_rule
      pdf.move_down 6
    when "blockquote"
      render_blockquote(pdf, node)
    when "pre"
      render_code_block(pdf, node)
    when "text"
      # テキストノードはスキップ（親ノードで処理済み）
    else
      # div等のコンテナは子要素を再帰処理
      node.children.each { |child| render_node(pdf, child) }
    end
  end

  # === 各HTML要素のPDF描画 ===

  def render_unordered_list(pdf, node)
    node.css("> li").each do |li|
      pdf.indent(16) do
        safe_text pdf, "\u2022  #{li.text.strip}", size: 10, leading: 4
      end
    end
    pdf.move_down 4
  end

  def render_ordered_list(pdf, node)
    node.css("> li").each_with_index do |li, idx|
      pdf.indent(16) do
        safe_text pdf, "#{idx + 1}.  #{li.text.strip}", size: 10, leading: 4
      end
    end
    pdf.move_down 4
  end

  def render_table(pdf, node)
    rows = []

    node.css("thead tr").each do |tr|
      rows << tr.css("th").map { |cell| cell.text.strip }
    end

    node.css("tbody tr").each do |tr|
      rows << tr.css("td").map { |cell| cell.text.strip }
    end

    # thead/tbody がない場合（シンプルなテーブル）
    if rows.empty?
      node.css("tr").each do |tr|
        cells = tr.css("th, td").map { |cell| cell.text.strip }
        rows << cells if cells.any?
      end
    end

    return if rows.empty? || rows.first.empty?

    pdf.move_down 4

    begin
      pdf.table(rows, width: pdf.bounds.width, cell_style: { size: 9, padding: [ 4, 8 ] }) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = "EEEEEE"
        t.cells.border_width = 0.5
        t.cells.border_color = "CCCCCC"
      end
    rescue StandardError
      rows.each do |row|
        safe_text pdf, row.join("  |  "), size: 9
      end
    end

    pdf.move_down 8
  end

  def render_blockquote(pdf, node)
    pdf.indent(12) do
      pdf.stroke_color = "5eead4"
      pdf.stroke_vertical_line(pdf.cursor, pdf.cursor - 14, at: -6)
      pdf.stroke_color = "000000"
      safe_text pdf, node.text.strip, size: 9, color: "888888", leading: 3
    end
    pdf.move_down 6
  end

  def render_code_block(pdf, node)
    pdf.fill_color "F5F5F5"
    code_text = node.text.strip
    height = [ code_text.lines.count * 12 + 16, 20 ].max
    pdf.fill_rectangle [ 0, pdf.cursor ], pdf.bounds.width, height
    pdf.fill_color "000000"

    pdf.move_down 8
    pdf.indent(12) do
      safe_text pdf, code_text, size: 8, color: "333333"
    end
    pdf.move_down 8
  end

  # === ヘッダー・フッター ===

  def render_header(pdf)
    if @japanese_available
      safe_text pdf, "月次オペレーション分析レポート", size: 18, style: :bold
      pdf.move_down 8
      safe_text pdf, "#{@client.name}（#{@client.code}）", size: 12
      safe_text pdf, "対象期間: #{@report.display_year_month}", size: 10, color: "666666"
      safe_text pdf, "生成日時: #{@report.generated_at&.strftime('%Y/%m/%d %H:%M')}", size: 10, color: "666666"
    else
      safe_text pdf, "Monthly Operation Report", size: 18, style: :bold
      pdf.move_down 8
      safe_text pdf, @client.code.to_s, size: 12
      safe_text pdf, "Period: #{@report.year_month}", size: 10, color: "666666"
      safe_text pdf, "Generated: #{@report.generated_at&.strftime('%Y/%m/%d %H:%M')}", size: 10, color: "666666"
    end

    pdf.move_down 4
    pdf.stroke_horizontal_rule
    pdf.move_down 12
  end

  def render_footer(pdf)
    footer_text = "LandBase AI Suite - #{@client.code} - #{@report.year_month}"
    pdf.repeat(:all) do
      pdf.bounding_box([ 0, 20 ], width: pdf.bounds.width, height: 20) do
        pdf.text footer_text, size: 8, color: "999999", align: :center
      end
    end

    pdf.number_pages "<page> / <total>",
                     at: [ pdf.bounds.right - 50, -5 ],
                     size: 8, color: "999999"
  end

  # === ユーティリティ ===

  def safe_text(pdf, text, **opts)
    pdf.text(text, **opts)
  rescue Prawn::Errors::IncompatibleStringEncoding
    ascii_text = text.encode("ASCII", undef: :replace, replace: "?")
    pdf.text(ascii_text, **opts)
  end
end
