require 'rails_helper'

RSpec.describe Proofing::Socure::IdPlus::Responses::KycResponse do
  let(:response_reason_codes) do
    [
      'I919',
      'I914',
      'I905',
    ]
  end

  let(:field_validation_overrides) { {} }

  let(:response_body) do
    {
      'referenceId' => 'a1234b56-e789-0123-4fga-56b7c890d123',
      'kyc' => {
        'reasonCodes' => response_reason_codes,
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
        }.merge(field_validation_overrides),
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

  describe '#reason_codes' do
    it 'returns the correct reason codes' do
      expect(subject.reason_codes).to contain_exactly(
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
          subject.reason_codes
        end.to raise_error(RuntimeError)
      end
    end
  end

  describe '#has_autofail_reason_codes?' do
    let(:idv_socure_kyc_auto_failure_reason_codes) { [] }

    before do
      allow(IdentityConfig.store).to receive(:idv_socure_kyc_auto_failure_reason_codes)
        .and_return(idv_socure_kyc_auto_failure_reason_codes)
    end

    context 'when response includes a configured autofail reason code' do
      let(:idv_socure_kyc_auto_failure_reason_codes) { ['R995', 'R111'] }
      let(:response_reason_codes) { ['R995'] }

      it 'returns true' do
        expect(subject.has_autofail_reason_codes?).to eql(true)
      end
    end

    context 'when response does not include a configured autofail reason code' do
      let(:idv_socure_kyc_auto_failure_reason_codes) { ['R995'] }

      it 'returns false' do
        expect(subject.has_autofail_reason_codes?).to eql(false)
      end
    end

    context 'when response includes a mix of normal and autofail reason codes' do
      let(:idv_socure_kyc_auto_failure_reason_codes) { ['R995'] }
      let(:response_reason_codes) do
        ['I919', 'R995', 'I905']
      end

      it 'returns true' do
        expect(subject.has_autofail_reason_codes?).to eql(true)
      end
    end
  end

  describe '#field_validations' do
    it 'returns an object with actual booleans' do
      expect(subject.field_validations).to eql(
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
          subject.field_validations
        end.to raise_error(RuntimeError)
      end
    end
  end

  # The base fixture fails city, state, and zip, so address is the only unverified
  # required attribute unless a context overrides more fields.
  describe '#attributes_requiring_additional_verification' do
    it 'reports the unverified address' do
      expect(subject.attributes_requiring_additional_verification).to eq([:address])
    end

    context 'when every required attribute is verified' do
      let(:field_validation_overrides) { { 'city' => 0.99, 'state' => 0.99, 'zip' => 0.99 } }

      it 'reports nothing' do
        expect(subject.attributes_requiring_additional_verification).to eq([])
      end
    end

    context 'when dob is not verified' do
      let(:field_validation_overrides) { { 'dob' => 0.01 } }

      it 'reports address and dob' do
        expect(subject.attributes_requiring_additional_verification).to eq([:address, :dob])
      end
    end

    context 'when ssn is not verified' do
      let(:field_validation_overrides) { { 'ssn' => 0.01 } }

      it 'reports address and ssn' do
        expect(subject.attributes_requiring_additional_verification).to eq([:address, :ssn])
      end
    end

    context 'when a name is not verified' do
      let(:field_validation_overrides) do
        { 'city' => 0.99, 'state' => 0.99, 'zip' => 0.99, 'firstName' => 0.01 }
      end

      it 'reports the name as unknown, since AAMVA coverage cannot be claimed for it' do
        expect(subject.attributes_requiring_additional_verification).to eq([:unknown])
      end
    end

    context 'when both names are not verified' do
      let(:field_validation_overrides) do
        {
          'city' => 0.99,
          'state' => 0.99,
          'zip' => 0.99,
          'firstName' => 0.01,
          'surName' => 0.01,
        }
      end

      it 'reports a single unknown entry' do
        expect(subject.attributes_requiring_additional_verification).to eq([:unknown])
      end
    end

    context 'when a reportable attribute and a name are both unverified' do
      let(:field_validation_overrides) { { 'firstName' => 0.01 } }

      it 'reports the attribute alongside unknown' do
        expect(subject.attributes_requiring_additional_verification)
          .to eq([:address, :unknown])
      end
    end

    context 'when only phone is not verified' do
      let(:field_validation_overrides) do
        { 'city' => 0.99, 'state' => 0.99, 'zip' => 0.99, 'mobileNumber' => 0.01 }
      end

      it 'reports nothing, since phone is not a required attribute' do
        expect(subject.attributes_requiring_additional_verification).to eq([])
      end
    end
  end

  describe '#failed_result_can_pass_with_additional_verification?' do
    before do
      allow(IdentityConfig.store).to receive(:idv_socure_kyc_auto_failure_reason_codes)
        .and_return(['R995'])
    end

    it 'is true when the result failed on a reportable attribute' do
      expect(subject.failed_result_can_pass_with_additional_verification?).to eq(true)
    end

    context 'when the result was successful' do
      let(:field_validation_overrides) { { 'city' => 0.99, 'state' => 0.99, 'zip' => 0.99 } }

      it 'is false' do
        expect(subject.failed_result_can_pass_with_additional_verification?).to eq(false)
      end
    end

    context 'when the result has an autofail reason code' do
      let(:response_reason_codes) { ['R995'] }

      it 'is false, since the failure is not about attributes' do
        expect(subject.failed_result_can_pass_with_additional_verification?).to eq(false)
      end
    end

    context 'when the only unverified attribute is a name' do
      let(:field_validation_overrides) do
        { 'city' => 0.99, 'state' => 0.99, 'zip' => 0.99, 'firstName' => 0.01 }
      end

      it 'is true, and the reported unknown attribute prevents the rescue downstream' do
        expect(subject.failed_result_can_pass_with_additional_verification?).to eq(true)
        expect(subject.attributes_requiring_additional_verification).to eq([:unknown])
      end
    end
  end
end
