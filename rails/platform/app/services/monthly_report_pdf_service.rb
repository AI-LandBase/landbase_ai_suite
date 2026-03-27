require "prawn"
require "prawn/table"

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
        Title: "#{@report.display_year_month} 月次オペレーション分析レポート",
        Author: "LandBase AI Suite",
        Creator: "LandBase AI Suite",
        CreationDate: @report.generated_at || Time.current
      }
    )

    @japanese_available = register_fonts(pdf)
    render_header(pdf)
    render_body(pdf)
    render_footer(pdf)

    pdf.render
  end

  private

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

    ipa_path = find_japanese_font
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

  def safe_text(pdf, text, **opts)
    pdf.text(text, **opts)
  rescue Prawn::Errors::IncompatibleStringEncoding
    ascii_text = text.encode("ASCII", undef: :replace, replace: "?")
    pdf.text(ascii_text, **opts)
  end

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
      safe_text pdf, "#{@client.code}", size: 12
      safe_text pdf, "Period: #{@report.year_month}", size: 10, color: "666666"
      safe_text pdf, "Generated: #{@report.generated_at&.strftime('%Y/%m/%d %H:%M')}", size: 10, color: "666666"
    end

    pdf.move_down 4
    pdf.stroke_horizontal_rule
    pdf.move_down 12
  end

  def render_body(pdf)
    lines = @report.content.split("\n")
    i = 0

    while i < lines.length
      line = lines[i]

      case line
      when /\A\#{2,6}\s+(.+)/
        level = line[/\A(#+)/, 1].length
        text = $1.strip
        render_heading(pdf, text, level)
      when /\A\|(.+)\|/
        table_lines = []
        while i < lines.length && lines[i] =~ /\A\|/
          table_lines << lines[i] unless lines[i] =~ /\A\|[-:|\s]+\|\s*\z/
          i += 1
        end
        render_table(pdf, table_lines)
        next
      when /\A[-*]\s+(.+)/
        list_items = []
        while i < lines.length && lines[i] =~ /\A[-*]\s+(.+)/
          list_items << $1.strip
          i += 1
        end
        render_list(pdf, list_items)
        next
      when /\A\d+\.\s+(.+)/
        list_items = []
        while i < lines.length && lines[i] =~ /\A\d+\.\s+(.+)/
          list_items << $1.strip
          i += 1
        end
        render_ordered_list(pdf, list_items)
        next
      when /\A---\s*\z/
        pdf.move_down 4
        pdf.stroke_horizontal_rule
        pdf.move_down 8
      when /\A\s*\z/
        pdf.move_down 4
      else
        render_paragraph(pdf, line.strip)
      end

      i += 1
    end
  end

  def render_heading(pdf, text, level)
    sizes = { 2 => 14, 3 => 12, 4 => 11, 5 => 10, 6 => 10 }
    size = sizes.fetch(level, 14)

    pdf.move_down 8
    safe_text pdf, strip_markdown(text), size: size, style: :bold
    pdf.move_down 4
  end

  def render_paragraph(pdf, text)
    safe_text pdf, strip_markdown(text), size: 10, leading: 4
  end

  def render_list(pdf, items)
    items.each do |item|
      pdf.indent(16) do
        safe_text pdf, "- #{strip_markdown(item)}", size: 10, leading: 4
      end
    end
    pdf.move_down 4
  end

  def render_ordered_list(pdf, items)
    items.each_with_index do |item, idx|
      pdf.indent(16) do
        safe_text pdf, "#{idx + 1}. #{strip_markdown(item)}", size: 10, leading: 4
      end
    end
    pdf.move_down 4
  end

  def render_table(pdf, table_lines)
    return if table_lines.empty?

    data = table_lines.map do |line|
      line.split("|").map(&:strip).reject(&:empty?)
    end

    return if data.empty? || data.first.empty?

    pdf.move_down 4

    begin
      pdf.table(data, width: pdf.bounds.width, cell_style: { size: 9, padding: [ 4, 8 ] }) do |t|
        t.row(0).font_style = :bold
        t.row(0).background_color = "EEEEEE"
        t.cells.border_width = 0.5
        t.cells.border_color = "CCCCCC"
      end
    rescue StandardError
      data.each do |row|
        pdf.text row.join(" | "), size: 9
      end
    end

    pdf.move_down 8
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

  JAPANESE_FONT_PATHS = %w[
    /usr/share/fonts/opentype/ipafont-gothic/ipag.ttf
    /usr/share/fonts/truetype/fonts-japanese-gothic.ttf
    /usr/share/fonts/ipa-gothic/ipag.ttf
  ].freeze

  def find_japanese_font
    JAPANESE_FONT_PATHS.find { |path| File.exist?(path) }
  end

  def strip_markdown(text)
    text
      .gsub(/\*\*(.+?)\*\*/, '\1')
      .gsub(/\*(.+?)\*/, '\1')
      .gsub(/`(.+?)`/, '\1')
      .gsub(/\[(.+?)\]\(.+?\)/, '\1')
      .gsub(/~~(.+?)~~/, '\1')
  end
end
