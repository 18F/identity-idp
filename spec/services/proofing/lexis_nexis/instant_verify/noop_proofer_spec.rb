# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Proofing::LexisNexis::InstantVerify::NoopProofer do
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

  before do
    # Do nothing
  end

  after do
    # Do nothing
  end

  context 'Proof result' do
    it 'Get a success response' do
      resp = subject.proof(applicant)
      expect(resp.success?).to eq(true)
      expect(resp.transaction_id).not_to eq(nil)
    end

    it 'Get a failure response' do
      applicant[:last_name] = 'IVFailure'
      resp = subject.proof(applicant)
      expect(resp.success?).to eq(false)
      expect(resp.transaction_id).not_to eq(nil)
    end

    it 'Get a failure response with aamva' do
      applicant[:last_name] = 'IVFailureWithAAMVA'
      resp = subject.proof(applicant)
      expect(resp.success?).to eq(false)
      expect(resp.transaction_id).not_to eq(nil)
      expect(resp.failed_result_can_pass_with_additional_verification?).to be(true)
    end

    it 'Get a failure response without aamva' do
      applicant[:last_name] = 'IVFailureWithoutAAMVA'
      resp = subject.proof(applicant)
      expect(resp.success?).to eq(false)
      expect(resp.transaction_id).not_to eq(nil)
      expect(resp.failed_result_can_pass_with_additional_verification?).to be(true)
    end

  end
end
