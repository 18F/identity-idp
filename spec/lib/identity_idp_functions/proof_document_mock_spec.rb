require 'rails_helper'
require 'identity_idp_functions/proof_document_mock'

RSpec.describe IdentityIdpFunctions::ProofDocumentMock do
  let(:idp_api_auth_token) { SecureRandom.hex }
  let(:trace_id) { SecureRandom.uuid }
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

  let(:event) do
    {
      encryption_key: Base64.encode64(encryption_key),
      front_image_iv: Base64.encode64(front_image_iv),
      back_image_iv: Base64.encode64(back_image_iv),
      selfie_image_iv: Base64.encode64(selfie_image_iv),
      front_image_url: front_image_url,
      back_image_url: back_image_url,
      selfie_image_url: selfie_image_url,
      liveness_checking_enabled: true,
      trace_id: trace_id,
    }
  end

  let(:encryption_key) { '12345678901234567890123456789012' }
  let(:front_image_iv) { SecureRandom.random_bytes(12) }
  let(:back_image_iv) { SecureRandom.random_bytes(12) }
  let(:selfie_image_iv) { SecureRandom.random_bytes(12) }
  let(:front_image_url) { 'http://bucket.s3.amazonaws.com/bar1' }
  let(:back_image_url) { 'http://bucket.s3.amazonaws.com/bar2' }
  let(:selfie_image_url) { 'http://bucket.s3.amazonaws.com/bar3' }

  before do
    body = { document: applicant_pii }.to_json
    encrypt_and_stub_s3(body: body, url: front_image_url, iv: front_image_iv, key: encryption_key)
    encrypt_and_stub_s3(body: body, url: back_image_url, iv: back_image_iv, key: encryption_key)
    encrypt_and_stub_s3(body: body, url: selfie_image_url, iv: selfie_image_iv, key: encryption_key)
  end

  let(:logger) { Logger.new('/dev/null') }

  describe '#proof' do
    subject(:function) do
      IdentityIdpFunctions::ProofDocumentMock.new(
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
      it 'returns a response' do
        expect(function.proof).to eq(
          document_result: {
            billed: true,
            errors: {},
            exception: nil,
            pii_from_doc: applicant_pii,
            result: 'Passed',
            success: true,
          },
        )
      end

      it 'logs the trace_id and timing info' do
        expect(logger).to receive(:info).with(hash_including(:timing, trace_id: trace_id))

        function.proof
      end
    end

    context 'with local image URLs instead of S3 URLs' do
      let(:front_image_url) { 'http://example.com/bar1' }
      let(:back_image_url) { 'http://example.com/bar2' }
      let(:selfie_image_url) { 'http://example.com/bar3' }

      before do
        data = { document: applicant_pii }.to_json
        encryption_helper = IdentityIdpFunctions::EncryptionHelper.new

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
        function.proof

        expect(a_request(:get, front_image_url)).to have_been_made
        expect(a_request(:get, back_image_url)).to have_been_made
        expect(a_request(:get, selfie_image_url)).to have_been_made
      end
    end
  end
end
