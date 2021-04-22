require 'rails_helper'

RSpec.describe DocumentProofingJob, type: :job do
  let(:front_image_url) { 'http://bucket.s3.amazonaws.com/bar1' }
  let(:back_image_url) { 'http://bucket.s3.amazonaws.com/bar2' }
  let(:selfie_image_url) { 'http://bucket.s3.amazonaws.com/bar3' }
  let(:encryption_key) { SecureRandom.random_bytes(32) }
  let(:front_image_iv) { SecureRandom.random_bytes(12) }
  let(:back_image_iv) { SecureRandom.random_bytes(12) }
  let(:selfie_image_iv) { SecureRandom.random_bytes(12) }
  let(:trace_id) { SecureRandom.uuid }
  let(:liveness_checking_enabled) { true }

  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      dob: '01/01/1970',
      ssn: '123456789',
      phone: '18888675309',
    }
  end

  before do
    body = { document: applicant_pii }.to_json
    encrypt_and_stub_s3(body: body, url: front_image_url, iv: front_image_iv, key: encryption_key)
    encrypt_and_stub_s3(body: body, url: back_image_url, iv: back_image_iv, key: encryption_key)
    encrypt_and_stub_s3(body: body, url: selfie_image_url, iv: selfie_image_iv, key: encryption_key)
  end

  let(:encrypted_arguments) do
    Encryption::Encryptors::SessionEncryptor.new.encrypt(
      {
        document_arguments: {
          encryption_key: Base64.encode64(encryption_key),
          front_image_iv: Base64.encode64(front_image_iv),
          back_image_iv: Base64.encode64(back_image_iv),
          selfie_image_iv: Base64.encode64(selfie_image_iv),
          front_image_url: front_image_url,
          back_image_url: back_image_url,
          selfie_image_url: selfie_image_url,
        },
      }.to_json,
    )
  end

  let(:document_capture_session) { DocumentCaptureSession.new(result_id: SecureRandom.hex) }

  describe '.perform_later' do
    it 'stores results' do
      DocumentProofingJob.perform_later(
        result_id: document_capture_session.result_id,
        liveness_checking_enabled: liveness_checking_enabled,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
      )

      result = document_capture_session.load_doc_auth_async_result
      expect(result).to be_present
    end
  end

  describe '#perform' do
    let(:instance) { DocumentProofingJob.new }
    subject(:perform) do
      instance.perform(
        result_id: document_capture_session.result_id,
        liveness_checking_enabled: liveness_checking_enabled,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
      )
    end

    context 'with a successful response from the proofer' do
      before do
        expect(DocAuthRouter).to receive('doc_auth_vendor').and_return('acuant')

        url = URI.join('https://example.com', '/AssureIDService/Document/Instance')
        stub_request(:post, url).to_return(body: '"this-is-a-test-instance-id"')
        doc_url = 'https://example.com/AssureIDService/Document/this-is-a-test-instance-id'
        stub_request(:post, "#{doc_url}/Image?light=0&side=0").to_return(body: '')
        stub_request(:post, "#{doc_url}/Image?light=0&side=1").to_return(body: '')
        stub_request(:get, doc_url).to_return(body: '{"Result":1}')
        stub_request(:get, "#{doc_url}/Field/Image?key=Photo").to_return(body: '')
        stub_request(:post, 'https://facial_match.example.com/api/v1/facematch').
          to_return(body: '{"IsMatch":true}')
        stub_request(:post, 'https://liveness.example.com/api/v1/liveness').
          to_return(body: '{"LivenessResult":{"LivenessAssessment": "Live"}}')
        stub_request(:post, 'https://example.login.gov/api/callbacks/proof-document/:token').
          to_return(body: '')

        allow_any_instance_of(IdentityDocAuth::Acuant::Responses::GetResultsResponse).
          to receive(:pii_from_doc).and_return(applicant_pii)
      end

      it 'returns a response' do
        perform

        result = document_capture_session.load_doc_auth_async_result

        expect(result.result).to eq(
          alert_failure_count: 0,
          billed: true,
          errors: {},
          face_match_results: { is_match: true, match_score: nil },
          image_metrics: {},
          processed_alerts: { failed: [], passed: [] },
          raw_alerts: [],
          raw_regions: [],
          result: 'Passed',
          selfie_liveness_results: {
            acuant_error: { code: nil, message: nil },
            liveness_assessment: 'Live',
            liveness_score: nil,
          },
          success: true,
          exception: nil,
        )

        expect(result.pii_from_doc).to eq(applicant_pii)
      end

      it 'logs the trace_id and timing info' do
        expect(instance.logger).to receive(:info).with(
          hash_including(
            trace_id: trace_id,
            timing: hash_including(
              'decrypt.back' => kind_of(Float),
              'decrypt.front' => kind_of(Float),
              'decrypt.selfie' => kind_of(Float),
              'download.back' => kind_of(Float),
              'download.front' => kind_of(Float),
              'download.selfie' => kind_of(Float),
            ),
          ),
        )

        perform
      end
    end

    context 'with an unsuccessful response from the proofer' do
      let(:doc_auth_client) { IdentityDocAuth::Acuant::AcuantClient }

      before do
        allow(instance).to receive(:doc_auth_client).and_return(doc_auth_client)

        expect(doc_auth_client).to receive(:post_images).
          and_return(IdentityDocAuth::Response.new(success: false, exception: RuntimeError.new))
      end

      it 'returns a response' do
        perform

        result = document_capture_session.load_doc_auth_async_result

        expect(result.result[:success]).to eq(false)
      end
    end

    context 'with local image URLs instead of S3 URLs' do
      let(:front_image_url) { 'http://example.com/bar1' }
      let(:back_image_url) { 'http://example.com/bar2' }
      let(:selfie_image_url) { 'http://example.com/bar3' }

      before do
        data = { document: applicant_pii }.to_json
        encryption_helper = JobHelpers::EncryptionHelper.new

        stub_request(:get, front_image_url).to_return(
          body: encryption_helper.encrypt(data: data, key: encryption_key, iv: front_image_iv),
        )
        stub_request(:get, back_image_url).to_return(
          body: encryption_helper.encrypt(data: data, key: encryption_key, iv: back_image_iv),
        )
        stub_request(:get, selfie_image_url).to_return(
          body: encryption_helper.encrypt(data: data, key: encryption_key, iv: selfie_image_iv),
        )
      end

      it 'still downloads and decrypts the content' do
        perform

        expect(a_request(:get, front_image_url)).to have_been_made
        expect(a_request(:get, back_image_url)).to have_been_made
        expect(a_request(:get, selfie_image_url)).to have_been_made
      end
    end
  end
end
