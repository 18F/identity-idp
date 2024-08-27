require 'rails_helper'

RSpec.describe Proofing::StateIdResult do
  let(:success) { true }
  let(:errors) { {} }
  let(:exception) { nil }
  let(:vendor_name) { 'aamva' }
  let(:transaction_id) { 'ABCD1234' }
  let(:requested_attributes) { { dob: 1, first_name: 1 } }
  let(:verified_attributes) { [:dob, :first_name] }
  let(:jurisdiction_in_maintenance_window) { false }

  subject do
    described_class.new(
      success:,
      errors:,
      exception:,
      vendor_name:,
      transaction_id:,
      requested_attributes:,
      verified_attributes:,
      jurisdiction_in_maintenance_window:,
    )
  end

  describe '#to_h' do
    it 'includes the right attributes' do
      expect(subject.to_h).to eql(
        {
          success: true,
          errors: {},
          exception: nil,
          mva_exception: nil,
          vendor_name: 'aamva',
          timed_out: false,
          transaction_id: 'ABCD1234',
          requested_attributes: { dob: 1, first_name: 1 },
          verified_attributes: [:dob, :first_name],
          jurisdiction_in_maintenance_window: false,
        },
      )
    end
  end
end
