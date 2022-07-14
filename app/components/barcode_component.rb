require 'barby'
require 'barby/barcode/code_128'
require 'barby/outputter/html_outputter'

class BarcodeComponent < BaseComponent
  attr_reader :data, :accessible_label, :data_formatter, :tag_options

  def initialize(data:, accessible_label:, data_formatter: nil, **tag_options)
    @data = data
    @accessible_label = accessible_label
    @tag_options = tag_options
    @data_formatter = data_formatter
  end

  def formatted_data
    formatted_data = data
    formatted_data = data_formatter.call(formatted_data) if data_formatter
    formatted_data
  end

  def barcode_html
    Barby::Code128.new(data).to_html(class_name: 'barcode')
  end
end
