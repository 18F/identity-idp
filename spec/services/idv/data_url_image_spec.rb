require 'rails_helper'

describe Idv::DataUrlImage do
  let(:data) { 'abcdef' }
  let(:data_url) { "data:image/jpeg;base64,#{Base64.encode64(data)}" }
  subject(:data_url_image) { described_class.new(data_url) }

  describe '#content_type' do
    it 'returns the content type from the header' do
      expect(data_url_image.content_type).to eq('image/jpeg')
    end

    context 'with bad data' do
      let(:data_url) { 'not_a_url' }

      it 'is the empty string' do
        expect(data_url_image.content_type).to eq('')
      end
    end

    context 'with a character encoding' do
      let(:data_url) { 'data:text/plain;charset=US-ASCII;base64,SGVsbG8gd29ybGQ=' }

      it 'returns just the content type' do
        expect(data_url_image.content_type).to eq('text/plain')
      end
    end
  end

  describe '#read' do
    it 'returns the data associated with the image' do
      expect(data_url_image.read).to eq(data)
    end

    context 'when data is not base64-encoded' do
      let(:data_url) { 'data:image/png,a%20+%20b' }

      it 'URI component unescapes the data' do
        expect(data_url_image.read).to eq('a + b')
      end
    end

    context 'with bad data' do
      let(:data_url) { 'not_a_url' }

      it 'is the empty string' do
        expect(data_url_image.read).to eq('')
      end
    end
  end
end
