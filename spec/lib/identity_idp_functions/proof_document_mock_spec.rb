require 'spec_helper'
require 'securerandom'
require 'identity-idp-functions/proof_document_mock'

RSpec.describe IdentityIdpFunctions::ProofDocumentMock do
  let(:idp_api_auth_token) { SecureRandom.hex }
  let(:callback_url) { 'https://example.login.gov/api/callbacks/proof-document/:token' }
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
      callback_url: callback_url,
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

  describe '.handle' do
    before do
      stub_const(
        'ENV',
        'IDP_API_AUTH_TOKEN' => idp_api_auth_token,
      )

      stub_request(:post, callback_url).
        with(
          headers: {
            'Content-Type' => 'application/json',
            'X-API-AUTH-TOKEN' => idp_api_auth_token,
          },
        ) do |request|
        expect(JSON.parse(request.body, symbolize_names: true)).to eq(
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
    end

    it 'runs' do
      IdentityIdpFunctions::ProofDocumentMock.handle(event: event, context: nil)
    end

    context 'when called with a block' do
      it 'gives the results to the block instead of posting to the callback URL' do
        yielded_result = nil
        IdentityIdpFunctions::ProofDocumentMock.handle(
          event: event,
          context: nil,
        ) do |result|
          yielded_result = result
        end

        expect(yielded_result).to eq(
          document_result: {
            billed: true,
            errors: {},
            exception: nil,
            pii_from_doc: applicant_pii,
            result: 'Passed',
            success: true,
          },
        )

        expect(a_request(:post, callback_url)).to_not have_been_made
      end
    end
  end

  describe '#proof' do
    subject(:function) do
      IdentityIdpFunctions::ProofDocumentMock.new(
        callback_url: callback_url,
        encryption_key: Base64.encode64(encryption_key),
        front_image_iv: Base64.encode64(front_image_iv),
        back_image_iv: Base64.encode64(back_image_iv),
        selfie_image_iv: Base64.encode64(selfie_image_iv),
        front_image_url: front_image_url,
        back_image_url: back_image_url,
        selfie_image_url: selfie_image_url,
        liveness_checking_enabled: true,
        trace_id: trace_id,
      )
    end

    before do
      stub_request(:post, callback_url).
        with(headers: { 'X-API-AUTH-TOKEN' => idp_api_auth_token })

      stub_const(
        'ENV',
        'IDP_API_AUTH_TOKEN' => idp_api_auth_token,
      )
    end

    context 'with a successful response from the proofer' do
      it 'posts back to the callback url' do
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end

      it_behaves_like 'callback url behavior'

      it 'logs the trace_id and timing info' do
        expect(function).to receive(:log_event).with(hash_including(:timing, trace_id: trace_id))

        function.proof
      end
    end

    context 'with an unsuccessful response from the proofer' do
      it 'posts back to the callback url' do
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'with a connection error talking to the proofer' do
      before do
        allow(function.doc_auth_client).to receive(:proof).
          and_raise(Faraday::ConnectionFailed.new('error')).
          and_raise(Faraday::ConnectionFailed.new('error')).
          and_raise(Faraday::ConnectionFailed.new('error'))
      end

      it 'retries 3 times then errors' do
        expect(WebMock).to_not have_requested(:post, callback_url)
      end
    end

    context 'with a connection error posting to the callback url' do
      before do
        stub_request(:post, callback_url).
          to_timeout.
          to_timeout.
          to_timeout
      end

      it 'retries 3 then errors' do
        expect { function.proof }.to raise_error(Faraday::ConnectionFailed)

        expect(a_request(:post, callback_url)).to have_been_made.times(3)
      end
    end

    context 'when there are no params in the ENV' do
      before do
        ENV.clear
      end

      it 'loads secrets from SSM' do
        expect(function.ssm_helper).to receive(:load).with('document_proof_result_token').
          and_return(idp_api_auth_token)

        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
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

        expect(a_request(:post, callback_url)).to have_been_made
      end
    end
  end
end
