require 'barby'
require 'barby/barcode/code_128'
require 'barby/outputter/html_outputter'

class BarcodeComponent < BaseComponent
  attr_reader :data, :data_label, :data_formatter, :tag_options

  def initialize(data:, data_label:, data_formatter: nil, **tag_options)
    @data = data
    @data_label = data_label
    @tag_options = tag_options
    @data_formatter = data_formatter
  end

  def formatted_data
    formatted_data = data
    formatted_data = data_formatter.call(formatted_data) if data_formatter
    formatted_data
  end

  def barcode_html
    Barby::Code128.new(data).to_html(class_name: barcode_table_class_name_aria_label)
  end

  def barcode_caption_id
    "barcode-caption-#{unique_id}"
  end

  private

  def barcode_table_class_name_aria_label
    # Unfortunately, Barby doesn't support additional attributes on the table element. Fortunately,
    # it also doesn't sanitize its attribute values.
    %(barcode" aria-label="#{t('components.barcode.table_label')})
  end
end
