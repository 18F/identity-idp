require 'rails_helper'

describe Proofing::LexisNexis::PhoneFinder::Proofer do
  let(:applicant) do
    {
      uuid_prefix: '0987',
      uuid: '1234-abcd',
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123-45-6789',
      dob: '1980-01-01',
      phone: '5551231234',
    }
  end

  let(:verification_request) do
    Proofing::LexisNexis::PhoneFinder::VerificationRequest.new(
      applicant: applicant,
      config: LexisNexisFixtures.example_config,
    )
  end

  it_behaves_like 'a lexisnexis proofer'

  describe '#send' do
    context 'when the request times out' do
      it 'raises a timeout error' do
        stub_request(:post, verification_request.url).to_timeout

        expect { verification_request.send }.to raise_error(
          Proofing::TimeoutError,
          'LexisNexis timed out waiting for verification response',
        )
      end
    end

    context 'when the request is made' do
      it 'it looks like the right request' do
        request = stub_request(:post, verification_request.url).
          with(body: verification_request.body, headers: verification_request.headers).
          to_return(body: LexisNexisFixtures.phone_finder_success_response_json, status: 200)

        verification_request.send

        expect(request).to have_been_requested.once
      end
    end
  end

  subject(:instance) do
    Proofing::LexisNexis::PhoneFinder::Proofer.new(**LexisNexisFixtures.example_config.to_h)
  end

  describe '#proof' do
    before do
      stub_request(:post, verification_request.url).
        to_return(body: response_body, status: 200)
    end

    context 'when the response is a success' do
      let(:response_body) { LexisNexisFixtures.phone_finder_success_response_json }

      it 'is a successful result' do
        result = instance.proof(applicant)

        expect(result.success?).to eq(true)
        expect(result.errors).to eq({})
      end
    end

    context 'when the response is a failure' do
      let(:response_body) { LexisNexisFixtures.phone_finder_fail_response_json }

      it 'is a failure result' do
        result = instance.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to include(
          base: include(a_kind_of(String)),
          'PhoneFinder Checks': include(a_kind_of(Hash)),
        )
      end
    end

    context 'when proofing fails' do
      let(:verification_status) { 'failed' }
      let(:verification_errors) do
        { base: 'test error', Discovery: 'another test error' }
      end
      let(:response_body) { LexisNexisFixtures.phone_finder_fail_response_json }

      it 'results in an unsuccessful result' do
        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq(
          base: ['test error'],
          Discovery: ['another test error'],
        )
        expect(result.transaction_id).to eq(conversation_id)
        expect(result.reference).to eq(reference)
      end
    end
  end
end
