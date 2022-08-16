require 'barby'
require 'barby/barcode/code_128'
require 'barby/outputter/png_outputter'

class BarcodeOutputter
  attr_reader :code

  def initialize(code:)
    @code = code
  end

  def image_data
    Barby::Code128C.new(code).to_png(margin: 10, xdim: 2)
  end
end
