require 'rails_helper'

RSpec.describe Proofing::Resolution::Attempt do
  subject(:attempt) { described_class.new(vendor:, result:) }

  let(:vendor) { :instant_verify_ddp }
  let(:result) do
    Proofing::Resolution::Result.new(
      success: false,
      vendor_name: 'lexisnexis:instant_verify_ddp',
      transaction_id: 'transaction-id',
    )
  end

  describe '#to_h' do
    it 'adds orchestration details to the serialized result' do
      expect(attempt.to_h(attempt_number: 2)).to include(
        attempt: 2,
        vendor: :instant_verify_ddp,
        vendor_name: 'lexisnexis:instant_verify_ddp',
        transaction_id: 'transaction-id',
      )
    end
  end

  describe 'PII_LIKE_KEYPATHS' do
    it 'covers sensitive fields from every future resolution attempt' do
      expect(described_class::PII_LIKE_KEYPATHS).to contain_exactly(
        [:proofing_results, :context, :stages, :resolution_attempts, :errors, :ssn],
        [:proofing_results, :context, :stages, :resolution_attempts, :errors, :zipcode],
        [:proofing_results, :context, :stages, :resolution_attempts, :reason_codes],
      )
    end
  end
end
