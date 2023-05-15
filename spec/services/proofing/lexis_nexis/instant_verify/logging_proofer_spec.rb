# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Proofing::LexisNexis::InstantVerify::LoggingProofer do
  let(:config) { LexisNexisFixtures.example_config }
  let(:subject) { described_class.new(config.to_h, 'residential') }
  let(:applicant) do
    {
      uuid_prefix: '0987',
      uuid: '1234-abcd',
      first_name: 'Testy',
      last_name: 'IVSuccess',
      ssn: '123-45-6789',
      dob: '1977-01-01',
      address1: '123 Main St',
      address2: 'Ste 3',
      city: 'Baton Rouge',
      state: 'LA',
      zipcode: '70802-12345',
      state_id_number: '132465879',
      state_id_jurisdiction: 'LA',
      state_id_type: 'drivers_license',
    }
  end

  let(:verification_request) do
    Proofing::LexisNexis::InstantVerify::VerificationRequest.new(
      applicant: applicant,
      config: LexisNexisFixtures.example_config,
    )
  end

  it_behaves_like 'a lexisnexis rdp proofer'

  context 'Proof result' do
    it 'Get a success response' do
      stub_request(
        :post,
        verification_request.url,
      ).to_return(
        body: LexisNexisFixtures.instant_verify_success_response_json,
        status: 200,
      )
      resp = subject.proof(applicant)
      expect(resp.success?).to eq(true)
      expect(resp.transaction_id).not_to eq(nil)
    end
  end
end
