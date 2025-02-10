require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::Response do
  let(:response_body) do
    {
      'referenceId' => 'a1234b56-e789-0123-4fga-56b7c890d123',
      'kyc' => {
        'reasonCodes' => [
          'I919',
          'I914',
          'I905',
        ],
        'fieldValidations' => {
          'firstName' => 0.99,
          'surName' => 0.99,
          'streetAddress' => 0.99,
          'city' => 0.01,
          'state' => 0.01,
          'zip' => 0.01,
          'mobileNumber' => 0.99,
          'dob' => 0.99,
          'ssn' => 0.99,
        },
      },
    }
  end

  let(:http_response) do
    instance_double(Faraday::Response).tap do |r|
      allow(r).to receive(:body).and_return(response_body)
    end
  end

  subject do
    described_class.new(http_response)
  end

  describe '#reference_id' do
    it 'returns referenceId' do
      expect(subject.reference_id).to eql('a1234b56-e789-0123-4fga-56b7c890d123')
    end
  end

  describe '#kyc_reason_codes' do
    it 'returns the correct reason codes' do
      expect(subject.kyc_reason_codes).to contain_exactly(
        'I919',
        'I914',
        'I905',
      )
    end

    context 'no kyc section on response' do
      let(:response_body) do
        {}
      end

      it 'raises an error' do
        expect do
          subject.kyc_reason_codes
        end.to raise_error(RuntimeError)
      end
    end
  end

  describe '#kyc_field_validations' do
    it 'returns an object with actual booleans' do
      expect(subject.kyc_field_validations).to eql(
        {
          firstName: true,
          surName: true,
          streetAddress: true,
          city: false,
          state: false,
          zip: false,
          mobileNumber: true,
          dob: true,
          ssn: true,
        },
      )
    end

    context 'no kyc section on response' do
      let(:response_body) do
        {}
      end

      it 'raises an error' do
        expect do
          subject.kyc_field_validations
        end.to raise_error(RuntimeError)
      end
    end
  end
end
