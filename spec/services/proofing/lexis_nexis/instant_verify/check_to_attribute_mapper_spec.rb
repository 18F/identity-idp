require 'rails_helper'

RSpec.describe Proofing::LexisNexis::InstantVerify::CheckToAttributeMapper do
  describe '#map_failed_checks_to_attributes' do
    let(:instant_verify_checks) do
      [
        { 'ItemName' => 'Addr1Zip_StateMatch', 'ItemStatus' => 'pass' },
      ]
    end
    let(:instant_verify_errors) { { 'Items' => instant_verify_checks } }

    subject { described_class.new(instant_verify_errors) }

    context 'when all of the checks pass' do
      it 'returns an empty array' do
        result = subject.map_failed_checks_to_attributes

        expect(result).to eq([])
      end
    end

    context 'when date of birth checks fail' do
      let(:instant_verify_checks) do
        super().push('ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail')
      end

      it 'returns an array that includes the dob attribute' do
        result = subject.map_failed_checks_to_attributes

        expect(result).to eq([:dob])
      end
    end

    context 'when SSN checks fail' do
      let(:instant_verify_checks) do
        super().push('ItemName' => 'SsnFullNameMatch', 'ItemStatus' => 'fail')
      end

      it 'returns an array that includes the ssn attribute' do
        result = subject.map_failed_checks_to_attributes

        expect(result).to eq([:ssn])
      end
    end

    context 'when address checks fail' do
      let(:instant_verify_checks) do
        super().push('ItemName' => 'IdentityOccupancyVerified', 'ItemStatus' => 'fail')
      end

      it 'returns an array that includes the ssn attribute' do
        result = subject.map_failed_checks_to_attributes

        expect(result).to eq([:address])
      end
    end

    context 'when checks for multiple attributes fail' do
      let(:instant_verify_checks) do
        super().push('ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail')
        super().push('ItemName' => 'IdentityOccupancyVerified', 'ItemStatus' => 'fail')
      end

      it 'returns an array that includes the failed attribute' do
        result = subject.map_failed_checks_to_attributes

        expect(result).to eq([:address, :dob])
      end
    end

    context 'when a check that is unknown fails' do
      let(:instant_verify_checks) do
        super().push('ItemName' => 'MadeUpCheckThatDoesNotExist', 'ItemStatus' => 'fail')
      end

      it 'returns an array that includes the unknown attribute' do
        result = subject.map_failed_checks_to_attributes

        expect(result).to eq([:unknown])
      end
    end

    context 'when multiple checks for the same attribute fail' do
      let(:instant_verify_checks) do
        super().push('ItemName' => 'DOBFullVerified', 'ItemStatus' => 'fail')
        super().push('ItemName' => 'DOBYearVerified', 'ItemStatus' => 'fail')
      end

      it 'returns an array that includes the attribute once' do
        result = subject.map_failed_checks_to_attributes

        expect(result).to eq([:dob])
      end
    end
  end
end
