require 'rails_helper'

describe Idv::Acuant::FacialMatch do
  let(:subject) { Idv::Acuant::FacialMatch.new }
  let(:acuant_facial_match_url) { 'https://example.com' }

  describe '#call' do
    let(:path) { '/FacialMatch' }
    let(:id_image) { '123' }
    let(:image) { 'abc' }

    it 'returns a good status' do
      stub_request(:post, acuant_facial_match_url + path).to_return(status: 200, body: '{}')

      result = subject.call(id_image, image)

      expect(result).to eq([true, {}])
    end

    it 'returns a bad status' do
      stub_request(:post, acuant_facial_match_url + path).to_return(status: 441, body: '')

      result = subject.call(id_image, image)

      expect(result).to eq([false, ''])
    end
  end
end
