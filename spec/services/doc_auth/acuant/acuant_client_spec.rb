require 'rails_helper'

RSpec.describe DocAuth::Acuant::AcuantClient do
  let(:assure_id_url) { 'https://acuant.assure.example.com' }
  let(:facial_match_url) { 'https://acuant.facial.example.com' }
  let(:passlive_url) { 'https://acuant.passlive.example.com' }
  let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }

  subject(:client) do
    DocAuth::Acuant::AcuantClient.new(
      assure_id_url: assure_id_url,
      facial_match_url: facial_match_url,
      passlive_url: passlive_url,
    )
  end

  describe '#create_document' do
    it 'sends a create document request with cropping mode' do
      url = URI.join(assure_id_url, '/AssureIDService/Document/Instance')
      stub_request(:post, url).
        with(body: hash_including(ImageCroppingMode: DocAuth::Acuant::CroppingModes::NONE)).
        to_return(body: AcuantFixtures.create_document_response)

      result = subject.create_document(image_source: image_source)

      expect(result.success?).to eq(true)
      expect(result.instance_id).to eq('this-is-a-test-instance-id') # instance ID from fixture
    end

    context 'invalid cropping mode' do
      let(:image_source) { 'invalid' }

      it 'raises an error' do
        message = 'unknown image_source=invalid'
        expect { subject.create_document(image_source: image_source) }.to raise_error(message)
      end
    end
  end

  describe '#post_front_image' do
    it 'sends an upload image request for the front image' do
      instance_id = 'this-is-a-test-instance-id'
      url = URI.join(
        assure_id_url, "/AssureIDService/Document/#{instance_id}/Image"
      )
      stub_request(:post, url).with(query: { side: 0, light: 0 }).to_return(body: '', status: 201)

      result = subject.post_front_image(
        instance_id: instance_id,
        image: DocAuthImageFixtures.document_front_image,
      )

      expect(result.success?).to eq(true)
    end
  end

  describe '#post_back_image' do
    it 'sends an upload image request for the back image' do
      instance_id = 'this-is-a-test-instance-id'
      url = URI.join(
        assure_id_url, "/AssureIDService/Document/#{instance_id}/Image"
      )
      stub_request(:post, url).with(query: { side: 1, light: 0 }).to_return(body: '', status: 201)

      result = subject.post_back_image(
        instance_id: instance_id,
        image: DocAuthImageFixtures.document_back_image,
      )

      expect(result.success?).to eq(true)
    end
  end

  describe '#post_images' do
    let(:instance_id) { 'this-is-a-test-instance-id' }
    let(:image_upload_url) do
      URI.join(
        assure_id_url, "/AssureIDService/Document/#{instance_id}/Image"
      )
    end
    let(:front_image_query) { { query: { side: 0, light: 0 } } }
    let(:back_image_query)  { { query: { side: 1, light: 0 } } }
    let(:results_url) do
      URI.join(
        assure_id_url, "/AssureIDService/Document/#{instance_id}"
      )
    end

    before do
      # DL image upload stubs
      stub_request(:post, image_upload_url).with(front_image_query).to_return(body: '', status: 201)
      stub_request(:post, image_upload_url).with(back_image_query).to_return(body: '', status: 201)
      stub_request(:get, results_url).to_return(body: AcuantFixtures.get_results_response_success)

      allow(subject).to receive(:create_document).and_return(
        OpenStruct.new('success?' => true, instance_id: instance_id),
      )
    end

    context 'when results pass' do
      it 'sends an upload image request for the front and back DL images' do
        result = subject.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: DocAuthImageFixtures.selfie_image,
          image_source: image_source,
        )

        extra_expected_hash = {
          processed_alerts: a_hash_including(:failed, :passed),
          alert_failure_count: 2,
          image_metrics: a_hash_including(:back, :front),
        }

        expect(result.success?).to eq(true)
        expect(result.class).to eq(DocAuth::Acuant::Responses::GetResultsResponse)
        expect(result.extra).to include(extra_expected_hash)
      end
    end

    context 'when the results return failure' do
      it 'returns a FormResponse with failure' do
        url = URI.join(assure_id_url, "/AssureIDService/Document/#{instance_id}")
        stub_request(:get, url).to_return(body: AcuantFixtures.get_results_response_failure)

        result = subject.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: DocAuthImageFixtures.selfie_image,
          image_source: image_source,
        )

        expect(result.success?).to eq(false)
      end
    end
  end

  describe '#get_results' do
    context 'when the result is a pass' do
      it 'sends a request to get the results and returns success' do
        instance_id = 'this-is-a-test-instance-id'
        url = URI.join(assure_id_url, "/AssureIDService/Document/#{instance_id}")
        stub_request(:get, url).to_return(body: AcuantFixtures.get_results_response_success)

        result = subject.get_results(instance_id: instance_id)

        expect(result.success?).to eq(true)
      end
    end

    context 'when the result is a failure' do
      it 'sends a request to get the results and returns failure' do
        instance_id = 'this-is-a-test-instance-id'
        url = URI.join(assure_id_url, "/AssureIDService/Document/#{instance_id}")
        stub_request(:get, url).to_return(body: AcuantFixtures.get_results_response_failure)

        result = subject.get_results(instance_id: instance_id)

        expect(result.success?).to eq(false)
      end
    end
  end

  context 'when the request is not successful' do
    it 'returns a response with an exception' do
      url = URI.join(assure_id_url, '/AssureIDService/Document/Instance')
      stub_request(:post, url).to_return(body: '', status: 500)

      expect(NewRelic::Agent).to receive(:notice_error)

      result = subject.create_document(image_source: image_source)

      expect(result.success?).to eq(false)
      expect(result.errors).to eq(network: true)
      expect(result.exception.message).to eq(
        'DocAuth::Acuant::Requests::CreateDocumentRequest Unexpected HTTP response 500',
      )
    end
  end

  context 'when there is a networking error' do
    it 'returns a response with an exception' do
      url = URI.join(assure_id_url, '/AssureIDService/Document/Instance')
      stub_request(:post, url).to_raise(Faraday::TimeoutError.new('Connection failed'))

      expect(NewRelic::Agent).to receive(:notice_error)

      result = subject.create_document(image_source: image_source)

      expect(result.success?).to eq(false)
      expect(result.errors).to eq(network: true)
      expect(result.exception.message).to eq(
        'Connection failed',
      )
    end
  end
end
