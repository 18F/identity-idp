require 'rails_helper'

RSpec.describe DocAuth::Acuant::Requests::UploadImageRequest do
  let(:instance_id) { '123abc' }
  let(:url) do
    URI.join(assure_id_url, "/AssureIDService/Document/#{instance_id}/Image")
  end

  let(:assure_id_url) { 'https://acuant.assureid.example.com' }
  let(:config) { DocAuth::Acuant::Config.new(assure_id_url: assure_id_url) }

  context 'with a front image' do
    it 'uploads the image and returns a successful result' do
      request_stub = stub_request(:post, url).with(
        query: { side: 0, light: 0 },
        body: DocAuthImageFixtures.document_front_image,
      ).to_return(body: '', status: 201)

      request = described_class.new(
        config: config,
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

    context 'when http status is 4xx' do
      shared_examples 'http expected 4xx status' do |http_status, general_failure, side_failure|
        it "generate errors for #{http_status}" do
          request_stub = stub_request(:post, url).with(
            query: { side: 0, light: 0 },
            body: DocAuthImageFixtures.document_front_image,
          ).to_return(body: '', status: http_status)

          request = described_class.new(
            config: config,
            image_data: DocAuthImageFixtures.document_front_image,
            instance_id: instance_id,
            side: :front,
          )
          response = request.fetch
          expect(response.success?).to eq(false)
          expect(response.errors).to eq({ front: [side_failure], general: [general_failure] })
          expect(response.exception).not_to be_nil
          expect(request_stub).to have_been_requested
        end
      end

      it_should_behave_like 'http expected 4xx status', 440, 'image_size_failure',
                            'image_size_failure_field'
      it_should_behave_like 'http expected 4xx status', 438, 'image_load_failure',
                            'image_load_failure_field'
      it_should_behave_like 'http expected 4xx status', 439, 'pixel_depth_failure',
                            'pixel_depth_failure_field'
    end
  end

  context 'with a back image' do
    it 'uploads the image and returns a successful result' do
      request_stub = stub_request(:post, url).with(
        query: { side: 1, light: 0 },
        body: DocAuthImageFixtures.document_back_image,
      ).to_return(body: '', status: 201)

      request = described_class.new(
        config: config,
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
