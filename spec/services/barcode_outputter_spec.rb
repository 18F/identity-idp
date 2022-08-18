require 'rails_helper'

RSpec.describe BarcodeOutputter do
  let(:code) { '1234' }
  subject(:outputter) { BarcodeOutputter.new(code: code) }

  describe '#image_data' do
    subject(:image_data) { outputter.image_data }

    it 'returns image data' do
      # See: https://en.wikipedia.org/wiki/List_of_file_signatures
      png_signature = "\x89\x50\x4e\x47\x0d\x0a\x1a\x0a".force_encoding(Encoding::ASCII_8BIT)
      expect(image_data).to start_with(png_signature)
    end
  end
end
