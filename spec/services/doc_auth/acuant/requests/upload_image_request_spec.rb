require 'rails_helper'

describe DocAuth::Acuant::Requests::UploadImageRequest do
  let(:instance_id) { '123abc' }
  let(:url) do
    URI.join(Figaro.env.acuant_assure_id_url, "/AssureIDService/Document/#{instance_id}/Image")
  end

  context 'with a front image' do
    it 'uploads the image and returns a successful result' do
      request_stub = stub_request(:post, url).with(
        query: { side: 0, light: 0 },
        body: DocAuthImageFixtures.document_front_image,
      ).to_return(body: '', status: 201)

      request = described_class.new(
        image_data: DocAuthImageFixtures.document_front_image,
        instance_id: instance_id,
        side: :front,
      )
      response = request.fetch

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      expect(request_stub).to have_been_requested
    end
  end

  context 'with a back image' do
    it 'uploads the image and returns a successful result' do
      request_stub = stub_request(:post, url).with(
        query: { side: 1, light: 0 },
        body: DocAuthImageFixtures.document_back_image,
      ).to_return(body: '', status: 201)

      request = described_class.new(
        image_data: DocAuthImageFixtures.document_back_image,
        instance_id: instance_id,
        side: :back,
      )
      response = request.fetch

      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to be_nil
      expect(request_stub).to have_been_requested
    end
  end
end
