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
                  to_return(body: LexisNexisFixtures.instant_verify_success_response_json, status: 200)

        verification_request.send

        expect(request).to have_been_requested.once
      end
    end
  end

  subject(:instance) do
    Proofing::LexisNexis::InstantVerify::Proofer.new(**LexisNexisFixtures.example_config.to_h)
  end

  describe '#proof' do
    subject(:result) { instance.proof(applicant) }
    let(:applicant) { super().merge(dob_year_only: dob_year_only) }

    before do
      stub_request(:post, verification_request.url).
        to_return(body: response_body, status: 200)
    end

    context 'when dob_year_only is false' do
      let(:dob_year_only) { false }

      context 'when the response is a full match' do
        let(:response_body) { LexisNexisFixtures.instant_verify_success_response_json }

        it 'is a successful result' do
          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
        end
      end

      context 'when the response is a year-of-birth failure only' do
        let(:response_body) { LexisNexisFixtures.instant_verify_year_of_birth_fail_response_json }

        it 'is a failure result' do
          expect(result.success?).to eq(false)
          expect(result.errors).to include(
            base: include(a_kind_of(String)),
            'Execute Instant Verify': include(a_kind_of(Hash)),
          )
        end
      end

      context 'when the response is a year-of-birth failure and a date-of-birth failure' do
        let(:response_body) do
          LexisNexisFixtures.instant_verify_date_of_birth_full_fail_response_json
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

    context 'when dob_year_only is true' do
      let(:dob_year_only) { true }

      context 'when the response is a full match' do
        let(:response_body) { LexisNexisFixtures.instant_verify_success_response_json }

        it 'is a successful result' do
          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
        end
      end

      context 'when the response is a year-of-birth failure only' do
        let(:response_body) { LexisNexisFixtures.instant_verify_year_of_birth_fail_response_json }

        it 'is a successful result' do
          expect(result.errors).to be_empty
          expect(result.success?).to eq(true)
        end
      end

      context 'when the response is a year-of-birth failure and a date-of-birth failure' do
        let(:response_body) do
          LexisNexisFixtures.instant_verify_date_of_birth_full_fail_response_json
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
end
