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
  let(:source) { nil }
  let(:front_image_metadata) { { mimeType: 'image/png', source: source } }
  let(:back_image_metadata) { { mimeType: 'image/png', source: source } }
  let(:image_metadata) { { front: front_image_metadata, back: back_image_metadata } }
  let(:liveness_checking_enabled) { true }

  let(:applicant_pii) do
    {
      first_name: 'Johnny',
      last_name: 'Appleseed',
      uuid: SecureRandom.hex,
      dob: '01/01/1970',
      ssn: '123456789',
      phone: '18888675309',
      state: 'MT',
      state_id_type: 'drivers_license',
    }
  end

  before do
    body = { document: applicant_pii }.to_json
    encrypt_and_stub_s3(body: body, url: front_image_url, iv: front_image_iv, key: encryption_key)
    encrypt_and_stub_s3(body: body, url: back_image_url, iv: back_image_iv, key: encryption_key)
    encrypt_and_stub_s3(body: body, url: selfie_image_url, iv: selfie_image_iv, key: encryption_key)
  end

  let(:encrypted_arguments) do
    Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
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

  let(:user) { create(:user) }
  let(:analytics) { FakeAnalytics.new }
  let(:document_capture_session) do
    DocumentCaptureSession.create(user_id: user.id, result_id: SecureRandom.hex)
  end

  describe '.perform_later' do
    it 'stores results' do
      DocumentProofingJob.perform_later(
        result_id: document_capture_session.result_id,
        liveness_checking_enabled: liveness_checking_enabled,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        image_metadata: image_metadata,
        analytics_data: {},
        flow_path: 'standard',
      )

      result = document_capture_session.load_doc_auth_async_result
      expect(result).to be_present
    end
  end

  describe '#perform' do
    let(:job_analytics) { FakeAnalytics.new }
    let(:instance) { DocumentProofingJob.new }
    subject(:perform) do
      instance.perform(
        result_id: document_capture_session.result_id,
        liveness_checking_enabled: liveness_checking_enabled,
        encrypted_arguments: encrypted_arguments,
        trace_id: trace_id,
        image_metadata: image_metadata,
        analytics_data: {},
        flow_path: 'standard',
      )
    end

    before do
      allow(instance).to receive(:build_analytics).
        with(document_capture_session).and_return(job_analytics)
    end

    context 'with a successful response from the proofer' do
      before do
        expect(DocAuthRouter).to receive(:doc_auth_vendor).and_return('acuant')

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

        allow_any_instance_of(DocAuth::Acuant::Responses::GetResultsResponse).
          to receive(:pii_from_doc).and_return(applicant_pii)
      end

      context 'liveness checking disabled' do
        let(:liveness_checking_enabled) { false }

        it 'returns a response' do
          perform

          result = document_capture_session.load_doc_auth_async_result

          expect(result.result).to eq(
            alert_failure_count: 0,
            vendor: 'Acuant',
            doc_auth_result: 'Passed',
            billed: true,
            errors: {},
            image_metrics: {},
            processed_alerts: { failed: [], passed: [] },
            success: true,
            exception: nil,
            tamper_result: nil,
          )

          expect(job_analytics).to have_logged_event(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
            success: true,
            errors: {},
            exception: nil,
            vendor: 'Acuant',
            billed: true,
            doc_auth_result: 'Passed',
            processed_alerts: { failed: [], passed: [] },
            alert_failure_count: 0,
            image_metrics: {},
            state: 'MT',
            state_id_type: 'drivers_license',
            async: true,
            attempts: 0,
            remaining_attempts: IdentityConfig.store.doc_auth_max_attempts,
            client_image_metrics: {
              front: front_image_metadata,
              back: back_image_metadata,
            },
            tamper_result: nil,
          )

          expect(result.pii_from_doc).to eq(applicant_pii)
        end
      end

      context 'liveness checking enabled' do
        let(:liveness_checking_enabled) { true }

        it 'returns a response' do
          perform

          result = document_capture_session.load_doc_auth_async_result

          expect(result.result).to eq(
            alert_failure_count: 0,
            vendor: 'Acuant',
            billed: true,
            errors: {},
            face_match_results: { is_match: true, match_score: nil },
            image_metrics: {},
            processed_alerts: { failed: [], passed: [] },
            doc_auth_result: 'Passed',
            selfie_liveness_results: {
              acuant_error: { code: nil, message: nil },
              liveness_assessment: 'Live',
              liveness_score: nil,
            },
            success: true,
            exception: nil,
            tamper_result: nil,
          )

          expect(job_analytics).to have_logged_event(
            Analytics::IDV_DOC_AUTH_SUBMITTED_IMAGE_UPLOAD_VENDOR,
            success: true,
            errors: {},
            exception: nil,
            vendor: 'Acuant',
            billed: true,
            doc_auth_result: 'Passed',
            processed_alerts: { failed: [], passed: [] },
            alert_failure_count: 0,
            image_metrics: {},
            state: 'MT',
            state_id_type: 'drivers_license',
            async: true,
            attempts: 0,
            remaining_attempts: IdentityConfig.store.doc_auth_max_attempts,
            face_match_results: { is_match: true, match_score: nil },
            selfie_liveness_results: {
              acuant_error: { code: nil, message: nil },
              liveness_assessment: 'Live',
              liveness_score: nil,
            },
            client_image_metrics: {
              front: front_image_metadata,
              back: back_image_metadata,
            },
            tamper_result: nil,
          )

          expect(result.pii_from_doc).to eq(applicant_pii)
        end
      end

      it 'logs the trace_id and timing info' do
        expect(instance.logger).to receive(:info) do |message|
          expect(JSON.parse(message, symbolize_names: true)).to include(
            trace_id: trace_id,
            timing: hash_including(
              'decrypt.back': kind_of(Float),
              'decrypt.front': kind_of(Float),
              'decrypt.selfie': kind_of(Float),
              'download.back': kind_of(Float),
              'download.front': kind_of(Float),
              'download.selfie': kind_of(Float),
            ),
          )
        end

        perform
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

    describe 'image source' do
      let(:source) { nil }
      let(:front_image_metadata) { { mimeType: 'image/png', source: source } }
      let(:back_image_metadata) { { mimeType: 'image/png', source: source } }
      let(:image_source) { nil }

      before do
        expect_any_instance_of(DocAuth::Mock::DocAuthMockClient).
          to receive(:post_images).
          with(hash_including(image_source: image_source)).
          and_call_original
      end

      context 'manual uploads' do
        let(:source) { 'upload' }
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }

        it 'sets image source to unknown' do
          perform
        end
      end

      context 'mixed sources' do
        let(:source) { 'upload' }
        let(:back_image_metadata) do
          { width: 20, height: 20, mimeType: 'image/png', source: 'acuant' }.to_json
        end
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }

        it 'sets image source to unknown' do
          perform
        end
      end

      context 'acuant images' do
        let(:source) { 'acuant' }
        let(:image_source) { DocAuth::ImageSources::ACUANT_SDK }

        it 'sets image source to acuant sdk' do
          perform
        end
      end

      context 'malformed image metadata' do
        let(:source) { 'upload' }
        let(:front_image_metadata) { nil }
        let(:image_source) { DocAuth::ImageSources::UNKNOWN }

        it 'sets image source to unknown' do
          perform
        end
      end
    end

    context 'a stale job' do
      before { instance.enqueued_at = 10.minutes.ago }

      it 'bails and does not do any proofing' do
        expect(DocAuthRouter).to_not receive(:doc_auth_vendor)

        expect { perform }.to raise_error(JobHelpers::StaleJobHelper::StaleJobError)
      end
    end
  end
end
