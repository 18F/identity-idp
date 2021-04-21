require 'securerandom'
require 'identity-idp-functions/proof_address'

RSpec.describe IdentityIdpFunctions::ProofAddress do
  let(:idp_api_auth_token) { SecureRandom.hex }
  let(:callback_url) { 'https://example.login.gov/api/callbacks/proof-address/:token' }
  let(:trace_id) { SecureRandom.uuid }
  let(:conversation_id) { SecureRandom.hex }
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
    stub_const(
      'ENV',
      'IDP_API_AUTH_TOKEN' => idp_api_auth_token,
    )
  end

  describe '.handle' do
    before do
      stub_request(
        :post,
        'https://lexisnexis.example.com/restws/identity/v2/abc123/aaa/conversation',
      ).to_return(
        body: {
          Status: {
            ConversationId: conversation_id,
            TransactionStatus: 'passed',
          },
        }.to_json,
      )

      stub_ssm(
        'lexisnexis_account_id' => 'abc123',
        'lexisnexis_request_mode' => 'aaa',
        'lexisnexis_username' => 'aaa',
        'lexisnexis_password' => 'aaa',
        'lexisnexis_base_url' => 'https://lexisnexis.example.com/',
        'lexisnexis_phone_finder_workflow' => 'aaa',
      )

      stub_request(:post, callback_url).
        with(
          headers: {
            'Content-Type' => 'application/json',
            'X-API-AUTH-TOKEN' => idp_api_auth_token,
          },
        ) do |request|
          expect(JSON.parse(request.body, symbolize_names: true)).to eq(
            address_result: {
              exception: nil,
              errors: {},
              messages: [],
              success: true,
              timed_out: false,
              transaction_id: conversation_id,
              context: { stages: [
                { address: 'lexisnexis:phone_finder' },
              ] },
            },
          )
        end
    end

    let(:event) do
      {
        callback_url: callback_url,
        applicant_pii: applicant_pii,
        trace_id: trace_id,
      }
    end

    it 'runs' do
      IdentityIdpFunctions::ProofAddress.handle(event: event, context: nil)
    end

    context 'when called with a block' do
      subject(:yielded_result) do
        yielded_result = nil
        IdentityIdpFunctions::ProofAddress.handle(
          event: event,
          context: nil,
        ) do |result|
          yielded_result = result
        end
      end

      it 'gives the results to the block instead of posting to the callback URL' do
        expect(yielded_result).to eq(
          address_result: {
            exception: nil,
            errors: {},
            messages: [],
            success: true,
            timed_out: false,
            transaction_id: conversation_id,
            context: { stages: [
              { address: 'lexisnexis:phone_finder' },
            ] },
          },
        )

        expect(a_request(:post, callback_url)).to_not have_been_made
      end

      context 'with lexisnexis configs' do
        let(:event) do
          super().merge(
            lexisnexis_config: {
              username: 'overridden value',
              password: 'overridden value',
              request_timeout: '50',
            },
          )
        end

        it 'passes lexisnexis params to the lexisnexis gem' do
          expect(LexisNexis::PhoneFinder::Proofer).to receive(:new).
            with(
              hash_including(
                username: 'overridden value',
                password: 'overridden value',
                request_timeout: '50',
              ),
            ).and_call_original

          expect(yielded_result).to be
        end
      end
    end
  end

  describe '#proof' do
    subject(:function) do
      IdentityIdpFunctions::ProofAddress.new(
        callback_url: callback_url,
        applicant_pii: applicant_pii,
        trace_id: trace_id,
      )
    end

    let(:lexisnexis_proofer) { instance_double(LexisNexis::PhoneFinder::Proofer) }

    before do
      allow(function).to receive(:lexisnexis_proofer).and_return(lexisnexis_proofer)

      stub_request(:post, callback_url).
        with(headers: { 'X-API-AUTH-TOKEN' => idp_api_auth_token })
    end

    context 'with a successful response from the proofer' do
      before do
        expect(lexisnexis_proofer).to receive(:proof).
          and_return(Proofer::Result.new)
      end

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
      before do
        expect(lexisnexis_proofer).to receive(:proof).
          and_return(Proofer::Result.new(exception: RuntimeError.new))
      end

      it 'posts back to the callback url' do
        function.proof

        expect(WebMock).to have_requested(:post, callback_url)
      end
    end

    context 'with a connection error talking to the proofer' do
      before do
        allow(lexisnexis_proofer).to receive(:proof).
          and_raise(Faraday::ConnectionFailed.new('error')).
          and_raise(Faraday::ConnectionFailed.new('error')).
          and_raise(Faraday::ConnectionFailed.new('error'))
      end

      it 'retries 3 times then errors' do
        expect { function.proof }.to raise_error(Faraday::ConnectionFailed)

        expect(WebMock).to_not have_requested(:post, callback_url)
      end
    end

    context 'when IDP auth token is blank' do
      it_behaves_like 'misconfigured proofer'
    end
  end
end
