require 'barby'
require 'barby/barcode/code_128'
require 'barby/outputter/html_outputter'

class BarcodeComponent < BaseComponent
  attr_reader :barcode_data, :label, :label_formatter, :tag_options

  def initialize(barcode_data:, label:, label_formatter: nil, **tag_options)
    @barcode_data = barcode_data
    @label = label
    @label_formatter = label_formatter
    @tag_options = tag_options
  end

  def formatted_data
    formatted_data = barcode_data
    formatted_data = label_formatter.call(formatted_data) if label_formatter
    formatted_data
  end

  def barcode_html
    html = Barby::Code128.new(barcode_data).to_html(class_name: 'barcode')
    # The Barby gem doesn't provide much control over rendered output, so we need to manually slice
    # in accessibility features (label as substitute to illegible inner content).
    html.gsub(
      '><tbody>',
      %( aria-label="#{t('components.barcode.table_label')}"><tbody aria-hidden="true">),
    )
  end

  def barcode_caption_id
    "barcode-caption-#{unique_id}"
  end

  def css_class
    [*tag_options[:class], 'display-inline-block margin-0']
  end
end
