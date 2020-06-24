require 'rails_helper'

describe Idv::Acuant::AssureId do
  let(:instance_id) { '123' }
  let(:good_acuant_status) { [true, '{"Result":1}'] }
  let(:bad_acuant_status) { [false, ''] }
  let(:good_http_status) { { status: 200, body: '{"Result":1}' } }
  let(:bad_http_status) { { status: 441, body: '' } }
  let(:acuant_base_url) { 'https://example.com' }

  describe '#face_image' do
    let(:path) { "/AssureIDService/Document/#{subject.instance_id}/Field/Image?key=Photo" }

    before do
      subject.instance_id = instance_id
    end

    it 'returns a good status' do
      stub_request(:get, acuant_base_url + path).to_return(good_http_status)

      result = subject.face_image

      expect(result).to eq(good_acuant_status)
    end

    it 'returns a bad status' do
      stub_request(:get, acuant_base_url + path).to_return(bad_http_status)

      result = subject.face_image

      expect(result).to eq(bad_acuant_status)
    end
  end
end
