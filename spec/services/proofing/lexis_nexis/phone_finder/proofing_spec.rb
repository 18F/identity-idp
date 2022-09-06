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

  subject(:instance) do
    Proofing::LexisNexis::PhoneFinder::Proofer.new(**LexisNexisFixtures.example_config.to_h)
  end

  describe '#proof' do
    subject(:result) { instance.proof(applicant) }

    before do
      stub_request(:post, verification_request.url).
        to_return(body: response_body, status: 200)
    end

    context 'when the response is a failure' do
      let(:response_body) do
        LexisNexisFixtures.instant_verify_date_of_birth_fail_response_json
      end

      it 'is a failure result' do
        expect(result.success?).to eq(false)
        expect(result.errors).to include(
          base: include(a_kind_of(String)),
          'Execute Instant Verify': include(a_kind_of(Hash)),
        )
      end
    end
  end
end
