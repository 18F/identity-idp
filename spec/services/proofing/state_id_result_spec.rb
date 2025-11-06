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

  describe '#to_doc_auth_response' do
    context 'when the state ID result does not have errors' do
      it 'returns a doc auth response instance' do
        expect(subject.to_doc_auth_response).to be_instance_of(DocAuth::Response)
      end

      it 'returns a successful doc auth response' do
        expect(subject.to_doc_auth_response).to have_attributes(
          success?: success,
          errors: {},
          exception:,
        )
      end
    end

    context 'when the state ID result has errors' do
      let(:success) { false }
      let(:errors) { { state_id_number: 'I am error' } }

      it 'returns a doc auth response instance' do
        expect(subject.to_doc_auth_response).to be_instance_of(DocAuth::Response)
      end

      it 'returns a unsucessful doc auth response with a verification error' do
        expect(subject.to_doc_auth_response).to have_attributes(
          success?: success,
          errors: { verification: 'Document could not be verified.' },
          exception:,
        )
      end
    end
  end
end
