require 'rails_helper'

describe Proofing::LexisNexis::InstantVerify::Proofer do
  let(:applicant) do
    {
      uuid_prefix: '0987',
      uuid: '1234-abcd',
      first_name: 'Testy',
      last_name: 'McTesterson',
      ssn: '123456789',
      dob: '01/01/1980',
      address1: '123 Main St',
      address2: 'Ste 3',
      city: 'Baton Rouge',
      state: 'LA',
      zipcode: '70802-12345',
    }
  end

  let(:verification_request) do
    Proofing::LexisNexis::InstantVerify::VerificationRequest.new(
      applicant: applicant,
      config: LexisNexisFixtures.example_config,
    )
  end

  it_behaves_like 'a lexisnexis proofer'

  subject(:instance) do
    Proofing::LexisNexis::InstantVerify::Proofer.new(**LexisNexisFixtures.example_config.to_h)
  end

  describe '#proof' do
    context 'when the response is a full match' do
      it 'is a successful result' do
        stub_request(:post, verification_request.url).
          to_return(body: LexisNexisFixtures.instant_verify_success_response_json, status: 200)

        result = instance.proof(applicant)

        expect(result.success?).to eq(true)
        expect(result.errors).to eq({})
      end
    end

    context 'when the response is a not a full match' do
      it 'is a failure result' do
        stub_request(
          :post, verification_request.url
        ).to_return(
          body: LexisNexisFixtures.instant_verify_date_of_birth_fail_response_json,
          status: 200,
        )

        result = instance.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to include(
          base: include(a_kind_of(String)),
          'Execute Instant Verify': include(a_kind_of(Hash)),
        )
        expect(result.transaction_id).to eq('123456')
        expect(result.reference).to eq('0987:1234-abcd')
      end
    end

    context 'when the request times out' do
      it 'retuns a timeout result' do
        stub_request(:post, verification_request.url).to_timeout

        result = instance.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({})
        expect(result.exception).to be_a(Proofing::TimeoutError)
        expect(result.timed_out?).to eq(true)
      end
    end

    context 'when an error is raised' do
      it 'returns a result with an exception' do
        stub_request(:post, verification_request.url).to_raise(RuntimeError.new('fancy test error'))

        result = instance.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({})
        expect(result.exception).to be_a(RuntimeError)
        expect(result.exception.message).to eq('fancy test error')
        expect(result.timed_out?).to eq(false)
      end
    end
  end
end
