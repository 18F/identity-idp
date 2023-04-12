require 'rails_helper'

describe Idv::DataUrlImage do
  let(:data) { 'abc def' }
  let(:data_url) { "data:image/jpeg,#{Addressable::URI.encode(data)}" }
  subject(:data_url_image) { described_class.new(data_url) }

  describe '#initialize' do
    context 'with bad data' do
      let(:data_url) { 'not_a_url' }

      it 'raises an error' do
        expect { data_url_image }.to raise_error Idv::DataUrlImage::InvalidUrlFormatError
      end
    end
  end

  describe '#content_type' do
    it 'returns the content type' do
      expect(data_url_image.content_type).to eq('image/jpeg')
    end
  end

  describe '#read' do
    it 'returns the data associated with the image' do
      expect(data_url_image.read).to eq(data)
    end

    context 'with base64-encoded content' do
      let(:data_url) { "data:image/jpeg;base64,#{Base64.encode64(data)}" }

      it 'returns the data associated with the image' do
        expect(data_url_image.read).to eq(data)
      end
    end
  end
end
