require 'barby'
require 'barby/barcode/code_128'
require 'barby/outputter/html_outputter'

class BarcodeComponent < BaseComponent
  attr_reader :barcode_data, :label, :label_formatter, :tag_options

  def initialize(
    barcode_data:,
    label:,
    label_formatter: nil,
    barcode_image_url: nil,
    **tag_options
  )
    @barcode_data = barcode_data
    @label = label
    @label_formatter = label_formatter
    @barcode_image_url = barcode_image_url
    @tag_options = tag_options
  end

  def barcode_image_url
    @barcode_image_url.presence || barcode_data_url
  end

  def formatted_data
    formatted_data = barcode_data
    formatted_data = label_formatter.call(formatted_data) if label_formatter
    formatted_data
  end

  def barcode_caption_id
    "barcode-caption-#{unique_id}"
  end

  def css_class
    [*tag_options[:class], 'display-inline-block margin-0']
  end

  private

  def barcode_data_url
    "data:image/png;base64,#{Base64.strict_encode64(barcode_image_data)}"
  end

  def barcode_image_data
    BarcodeOutputter.new(code: barcode_data).image_data
  end
end
