require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::LexisNexisClient do
  let(:image_source) { nil }
  let(:workflow) { 'NOLIVENESS.CROPPING.WORKFLOW' }
  let(:image_upload_url) do
    URI.join(
      'https://lexis.nexis.example.com',
      "/restws/identity/v3/accounts/test_account/workflows/#{workflow}/conversations",
    )
  end

  subject(:client) do
    DocAuth::LexisNexis::LexisNexisClient.new(
      base_url: 'https://lexis.nexis.example.com',
      locale: 'en',
      trueid_account_id: 'test_account',
      trueid_noliveness_cropping_workflow: 'NOLIVENESS.CROPPING.WORKFLOW',
      trueid_noliveness_nocropping_workflow: 'NOLIVENESS.NOCROPPING.WORKFLOW',
    )
  end

  describe '#create_document' do
    it 'raises a NotImplemented error' do
      expect { client.create_document }.to raise_error(NotImplementedError)
    end
  end

  describe '#post_front_image' do
    it 'raises a NotImplemented error' do
      expect do
        client.post_front_image(
          instance_id: 123,
          image: DocAuthImageFixtures.document_front_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_back_image' do
    it 'raises a NotImplemented error' do
      expect do
        client.post_back_image(
          instance_id: 123,
          image: DocAuthImageFixtures.document_back_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#get_results' do
    it 'raises a NotImplemented error' do
      expect do
        client.get_results(
          instance_id: 123,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_images' do
    before do
      stub_request(:post, image_upload_url).to_return(
        body: LexisNexisFixtures.true_id_response_success,
      )
    end

    context 'with acuant image source' do
      let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }
      let(:workflow) { 'NOLIVENESS.NOCROPPING.WORKFLOW' }

      it 'sends an upload image request for the front and back DL images' do
        result = client.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          image_source: image_source,
        )

        expect(result.success?).to eq(true)
        expect(result.class).to eq(DocAuth::LexisNexis::Responses::TrueIdResponse)
      end
    end

    context 'with unknown image source' do
      let(:image_source) { DocAuth::ImageSources::UNKNOWN }
      let(:workflow) { 'NOLIVENESS.CROPPING.WORKFLOW' }

      it 'sends an upload image request for the front and back DL images' do
        result = client.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          image_source: image_source,
        )

        expect(result.success?).to eq(true)
        expect(result.class).to eq(DocAuth::LexisNexis::Responses::TrueIdResponse)
      end
    end

    context 'when the results return failure' do
      it 'returns a FormResponse with failure' do
        stub_request(:post, image_upload_url).to_return(
          body: LexisNexisFixtures.true_id_response_failure_no_liveness,
        )

        result = client.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          image_source: image_source,
        )

        expect(result.success?).to eq(false)
      end
    end
  end

  context 'when the request is not successful' do
    it 'returns a response with an exception' do
      stub_request(:post, image_upload_url).to_return(body: '', status: 500)

      result = client.post_images(
        front_image: DocAuthImageFixtures.document_front_image,
        back_image: DocAuthImageFixtures.document_back_image,
        image_source: image_source,
      )

      expect(result.success?).to eq(false)
      expect(result.errors).to eq(network: true)
      expect(result.exception.message).to eq(
        'DocAuth::LexisNexis::Requests::TrueIdRequest Unexpected HTTP response 500',
      )
    end
  end

  context 'when there is a networking error' do
    it 'returns a response with an exception' do
      stub_request(:post, image_upload_url).to_raise(Faraday::TimeoutError.new('Connection failed'))

      result = client.post_images(
        front_image: DocAuthImageFixtures.document_front_image,
        back_image: DocAuthImageFixtures.document_back_image,
        image_source: image_source,
      )

      expect(result.success?).to eq(false)
      expect(result.errors).to eq(network: true)
      expect(result.exception.message).to eq(
        'Connection failed',
      )
    end
  end
end
