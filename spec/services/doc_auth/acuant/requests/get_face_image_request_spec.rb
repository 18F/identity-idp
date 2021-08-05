require 'rails_helper'

RSpec.describe DocAuth::Acuant::Requests::GetFaceImageRequest do
  let(:assure_id_url) { 'https://acuant.assureid.example.com' }
  let(:config) do
    DocAuth::Acuant::Config.new(
      assure_id_url: assure_id_url,
    )
  end

  describe '#fetch' do
    let(:instance_id) { '123abc' }
    let(:url) do
      URI.join(
        assure_id_url,
        "/AssureIDService/Document/#{instance_id}/Field/Image?key=Photo",
      )
    end
    let(:response_body) { AcuantFixtures.get_face_image_response }

    it 'returns a response with the image' do
      request_stub = stub_request(:get, url).to_return(body: response_body)

      response = described_class.new(config: config, instance_id: instance_id).fetch

      expect(response.success?).to eq(true)
      expect(response.image).to eq(AcuantFixtures.get_face_image_response)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      expect(request_stub).to have_been_requested
    end
  end
end
