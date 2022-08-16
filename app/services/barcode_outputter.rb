require 'barby'
require 'barby/barcode/code_128'
require 'barby/outputter/png_outputter'

class BarcodeOutputter
  attr_reader :code

  def initialize(code:)
    @code = code
  end

  def image_data
    # Based on requirements, this currently only supports Code 128C barcodes, but could be enhanced
    # to support others as needed.
    Barby::Code128C.new(code).to_png(margin: 10, xdim: 2)
  end
end
