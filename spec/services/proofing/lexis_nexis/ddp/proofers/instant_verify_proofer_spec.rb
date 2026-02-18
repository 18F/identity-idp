require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Ddp::Proofers::InstantVerifyProofer do
  let(:proofing_applicant) do
    {
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123456789',
      dob: '01/01/1980',
      address1: '123 Main St',
      address2: 'Ste 3',
      city: 'Baton Rouge',
      state: 'LA',
      zipcode: '70802-12345',
      state_id_number: '12345678',
      state_id_jurisdiction: 'LA',
      phone: '5551231234',
      uuid_prefix: 'ABCD',
    }
  end

  let(:proofing_verification_request) do
    Proofing::LexisNexis::Ddp::Requests::InstantVerifyRequest.new(
      applicant: proofing_applicant,
      config: LexisNexisFixtures.example_ddp_proofing_config,
    )
  end

  let(:issuer) { 'fake-issuer' }
  let(:friendly_name) { 'fake-name' }
  let(:app_id) { 'fake-app-id' }

  describe '#send' do
    context 'when the request times out' do
      it 'raises a timeout error' do
        stub_request(
          :post,
          proofing_verification_request.url,
        ).to_timeout

        expect { proofing_verification_request.send_request }.to raise_error(
          Proofing::TimeoutError,
          'LexisNexis timed out waiting for verification response',
        )
      end
    end

    context 'when the request is made' do
      it 'it looks like the right request' do
        request =
          stub_request(
            :post,
            proofing_verification_request.url,
          ).with(
            body: proofing_verification_request.body,
            headers: proofing_verification_request.headers,
          ).to_return(
            body: LexisNexisFixtures.ddp_instant_verify_success_response_json,
            status: 200,
          )

        proofing_verification_request.send_request

        expect(request).to have_been_requested.once
      end
    end
  end

  subject(:proofer) do
    described_class.new(LexisNexisFixtures.example_ddp_proofing_config.to_h)
  end

  describe '#proof' do
    before do
      ServiceProvider.create(
        issuer: issuer,
        friendly_name: friendly_name,
        app_id: app_id,
      )
      stub_request(
        :post,
        proofing_verification_request.url,
      ).to_return(
        body: response_body,
        status: 200,
      )
    end

    context 'when user is going through Idv' do
      context 'when the response is a full match' do
        let(:response_body) { LexisNexisFixtures.ddp_instant_verify_success_response_json }

        it 'is a successful result' do
          result = proofer.proof(proofing_applicant)

          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
          expect(result.review_status).to eq('pass')
          expect(result.session_id).to eq('super-cool-test-session-id')
          expect(result.account_lex_id).to eq('super-cool-test-lex-id')
        end
      end

      context 'when the response raises an exception' do
        let(:response_body) { '' }

        it 'returns an exception result' do
          error = RuntimeError.new('hi')

          expect(NewRelic::Agent).to receive(:notice_error).with(error)

          stub_request(
            :post,
            proofing_verification_request.url,
          ).to_raise(error)

          result = proofer.proof(proofing_applicant)

          expect(result.success?).to eq(false)
          expect(result.errors).to be_empty
          expect(result.exception).to eq(error)
        end
      end
    end
  end
end
