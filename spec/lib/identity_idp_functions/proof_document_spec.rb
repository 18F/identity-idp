require 'rails_helper'
require 'identity_idp_functions/proof_document'

RSpec.describe IdentityIdpFunctions::ProofDocument do
  let(:trace_id) { SecureRandom.uuid }

  let(:encryption_key) { '12345678901234567890123456789012' }
  let(:front_image_iv) { '123456789012' }
  let(:back_image_iv) { '123456789012' }
  let(:selfie_image_iv) { '123456789012' }
  let(:front_image_url) { 'http://bucket.s3.amazonaws.com/bar1' }
  let(:back_image_url) { 'http://bucket.s3.amazonaws.com/bar2' }
  let(:selfie_image_url) { 'http://bucket.s3.amazonaws.com/bar3' }
  let(:logger) { Logger.new('/dev/null') }

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

    body = { document: applicant_pii }.to_json
    encrypt_and_stub_s3(body: body, url: front_image_url, iv: front_image_iv, key: encryption_key)
    encrypt_and_stub_s3(body: body, url: back_image_url, iv: back_image_iv, key: encryption_key)
    encrypt_and_stub_s3(body: body, url: selfie_image_url, iv: selfie_image_iv, key: encryption_key)

    allow_any_instance_of(IdentityDocAuth::Acuant::Responses::GetResultsResponse).
      to receive(:pii_from_doc).and_return(applicant_pii)
  end

  describe '#proof' do
    subject(:function) do
      IdentityIdpFunctions::ProofDocument.new(
        encryption_key: Base64.encode64(encryption_key),
        front_image_iv: Base64.encode64(front_image_iv),
        back_image_iv: Base64.encode64(back_image_iv),
        selfie_image_iv: Base64.encode64(selfie_image_iv),
        front_image_url: front_image_url,
        back_image_url: back_image_url,
        selfie_image_url: selfie_image_url,
        liveness_checking_enabled: true,
        trace_id: trace_id,
        logger: logger,
      )
    end

    context 'with a successful response from the proofer' do
      before do
        expect(DocAuthRouter).to receive('doc_auth_vendor').and_return('acuant')
      end

      it 'returns a response' do
        result = function.proof

        expect(result).to eq(
          document_result: {
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
            pii_from_doc: applicant_pii,
          },
        )
      end

      it 'logs the trace_id and timing info' do
        expect(logger).to receive(:info).with(
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

        function.proof
      end
    end

    context 'with an unsuccessful response from the proofer' do
      let(:doc_auth_client) { IdentityDocAuth::Acuant::AcuantClient }

      before do
        allow(function).to receive(:doc_auth_client).and_return(doc_auth_client)
        expect(doc_auth_client).to receive(:post_images).
          and_return(IdentityDocAuth::Response.new(success: false, exception: RuntimeError.new))
      end

      it 'returns a response' do
        expect(function.proof).to match(document_result: hash_including(success: false))
      end
    end
  end
end
