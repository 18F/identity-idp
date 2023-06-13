require 'rails_helper'

RSpec.describe Proofing::LexisNexis::PhoneFinder::Proofer do
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

  it_behaves_like 'a lexisnexis rdp proofer'

  subject do
    described_class.new(**LexisNexisFixtures.example_config.to_h)
  end

  describe '#proof' do
    context 'when the response is a success' do
      it 'is a successful rdp1 result' do
        stub_request(:post, verification_request.url).
          to_return(body: LexisNexisFixtures.phone_finder_rdp1_success_response_json, status: 200)

        result = subject.proof(applicant)

        expect(result.success?).to eq(true)
        expect(result.errors).to eq({})
        expect(result.vendor_workflow).to(
          eq(LexisNexisFixtures.example_config.phone_finder_workflow),
        )
      end

      it 'is a successful rdp2 result' do
        stub_request(:post, verification_request.url).
          to_return(body: LexisNexisFixtures.phone_finder_rdp2_success_response_json, status: 200)

        result = subject.proof(applicant)

        expect(result.success?).to eq(true)
        expect(result.errors).to include(
          Execute_PhoneFinder: include(a_kind_of(Hash)),
        )
        expect(result.vendor_workflow).to(
          eq(LexisNexisFixtures.example_config.phone_finder_workflow),
        )
      end
    end

    context 'when the rdp1 response is a failure' do
      it 'is a failure result' do
        stub_request(
          :post,
          verification_request.url,
        ).to_return(
          body: LexisNexisFixtures.phone_finder_rdp1_fail_response_json,
          status: 200,
        )

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to include(
          PhoneFinder: include(a_kind_of(Hash)),
        )
        expect(result.transaction_id).to eq('31000000000000')
        expect(result.reference).to eq('Reference1')
        expect(result.vendor_workflow).to(
          eq(LexisNexisFixtures.example_config.phone_finder_workflow),
        )
      end
    end

    context 'when the rdp2 response is a failure' do
      it 'is a failure result' do
        stub_request(:post, verification_request.url).
          to_return(body: LexisNexisFixtures.phone_finder_rdp2_fail_response_json, status: 200)

        result = subject.proof(applicant)
        result_json_hash = result.errors[:PhoneFinder].first

        expect(result.success?).to eq(false)
        expect(result_json_hash['ProductStatus']).to eq('fail')
        expect(result_json_hash['Items'].class).to eq(Array)
        # check that key contaning PII is removed and not logged
        expect(result_json_hash['ParameterDetails']).to eq(nil)
      end
    end

    context 'when the request times out' do
      it 'retuns a timeout result' do
        stub_request(:post, verification_request.url).to_timeout

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({})
        expect(result.exception).to be_a(Proofing::TimeoutError)
        expect(result.timed_out?).to eq(true)
      end
    end

    context 'when an error is raised' do
      it 'returns a result with an exception' do
        stub_request(:post, verification_request.url).to_raise(RuntimeError.new('fancy test error'))

        result = subject.proof(applicant)

        expect(result.success?).to eq(false)
        expect(result.errors).to eq({})
        expect(result.exception).to be_a(RuntimeError)
        expect(result.exception.message).to eq('fancy test error')
        expect(result.timed_out?).to eq(false)
      end
    end
  end
end
