require 'rails_helper'

RSpec.describe Proofing::LexisNexis::VerificationErrorParser do
  let(:response_body) do
    JSON.parse(LexisNexisFixtures.instant_verify_identity_not_found_response_json)
  end
  subject(:error_parser) { described_class.new(response_body) }

  describe '#initialize' do
    let(:response_body) do
      JSON.parse(LexisNexisFixtures.instant_verify_date_of_birth_fail_response_json)
    end
  end

  describe '#parsed_errors' do
    subject(:errors) { error_parser.parsed_errors }

    it 'should return an array of errors from the response' do
      expect(errors[:base]).to start_with('Verification failed with code:')
      expect(errors[:Discovery]).to eq(nil) # This should be absent since it passed
      expect(errors[:SomeOtherProduct]).to eq(response_body['Products'][1])
      expect(errors[:InstantVerify]).to eq(response_body['Products'][2])
    end
  end
end
