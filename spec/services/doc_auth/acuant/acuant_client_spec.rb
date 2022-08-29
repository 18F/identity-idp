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
    let(:liveness_enabled) { false }
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

    context 'with liveness checking enabled' do
      let(:get_face_image_url) do
        URI.join(
          assure_id_url,
          "/AssureIDService/Document/#{instance_id}/Field/Image?key=Photo",
        )
      end
      let(:full_facial_match_url) { URI.join(facial_match_url, '/api/v1/facematch') }
      let(:liveness_url) { URI.join(passlive_url, '/api/v1/liveness') }
      let(:liveness_enabled) { true }

      it 'sends an upload image request for the front, back, and selfie images' do
        # Selfie stubs
        stub_request(:get, get_face_image_url).
          to_return(body: AcuantFixtures.get_face_image_response)
        stub_request(:post, full_facial_match_url).
          to_return(body: AcuantFixtures.facial_match_response_success)
        stub_request(:post, liveness_url).
          to_return(body: AcuantFixtures.liveness_response_success)

        result = subject.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: DocAuthImageFixtures.selfie_image,
          liveness_checking_enabled: liveness_enabled,
          image_source: image_source,
        )

        extra_expected_hash = {
          processed_alerts: a_hash_including(:failed, :passed),
          alert_failure_count: 2,
          image_metrics: a_hash_including(:back, :front),
          face_match_results: a_hash_including(:match_score, :is_match),
          selfie_liveness_results: a_hash_including(
            :liveness_score,
            :liveness_assessment,
            :acuant_error,
          ),
        }

        expect(result.success?).to eq(true)
        expect(result.pii_from_doc).to_not be_empty
        expect(result.extra).to include(extra_expected_hash)
      end
    end

    context 'with liveness checking disabled' do
      it 'sends an upload image request for the front and back DL images' do
        result = subject.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: DocAuthImageFixtures.selfie_image,
          liveness_checking_enabled: liveness_enabled,
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
          liveness_checking_enabled: liveness_enabled,
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

  describe '#post_selfie' do
    let(:instance_id) { 'this-is-a-test-instance-id' }
    let(:get_face_image_url) do
      URI.join(
        assure_id_url,
        "/AssureIDService/Document/#{instance_id}/Field/Image?key=Photo",
      )
    end
    let(:full_facial_match_url) { URI.join(facial_match_url, '/api/v1/facematch') }
    let(:full_liveness_url) { URI.join(passlive_url, '/api/v1/liveness') }

    context 'when the result is a pass' do
      it 'sends the requests and returns success' do
        get_face_stub = stub_request(:get, get_face_image_url).
          to_return(body: AcuantFixtures.get_face_image_response)
        facial_match_stub = stub_request(:post, full_facial_match_url).
          to_return(body: AcuantFixtures.facial_match_response_success)
        liveness_stub = stub_request(:post, full_liveness_url).
          to_return(body: AcuantFixtures.liveness_response_success)

        result = subject.post_selfie(
          instance_id: instance_id,
          image: DocAuthImageFixtures.selfie_image,
        )

        expect(result.success?).to eq(true)
        expect(result.errors).to eq({})
        expect(result).to be_kind_of(DocAuth::Response)
        expect(get_face_stub).to have_been_requested
        expect(facial_match_stub).to have_been_requested
        expect(liveness_stub).to have_been_requested
      end
    end

    context 'when the get face image request fails' do
      it 'returns a failure' do
        stub_request(:get, get_face_image_url).to_return(status: 404)

        expect(NewRelic::Agent).to receive(:notice_error).at_least(:once)

        result = subject.post_selfie(
          instance_id: instance_id,
          image: DocAuthImageFixtures.selfie_image,
        )

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(network: true)
      end
    end

    context 'when the facial match request fails' do
      it 'returns a failure' do
        stub_request(:get, get_face_image_url).
          to_return(body: AcuantFixtures.get_face_image_response)
        stub_request(:post, full_facial_match_url).
          to_return(body: AcuantFixtures.facial_match_response_failure)
        stub_request(:post, full_liveness_url).
          to_return(body: AcuantFixtures.liveness_response_success)

        result = subject.post_selfie(
          instance_id: instance_id,
          image: DocAuthImageFixtures.selfie_image,
        )

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(selfie: true)
      end
    end

    context 'when the liveness request fails' do
      it 'returns a failure' do
        stub_request(:get, get_face_image_url).
          to_return(body: AcuantFixtures.get_face_image_response)
        stub_request(:post, full_facial_match_url).
          to_return(body: AcuantFixtures.facial_match_response_success)
        stub_request(:post, full_liveness_url).
          to_return(body: AcuantFixtures.liveness_response_failure)

        result = subject.post_selfie(
          instance_id: instance_id,
          image: DocAuthImageFixtures.selfie_image,
        )

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(selfie: true)
      end
    end
  end
end
