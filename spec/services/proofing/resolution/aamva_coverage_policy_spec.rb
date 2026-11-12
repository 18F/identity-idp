require 'rails_helper'

RSpec.describe Proofing::Resolution::AamvaCoveragePolicy do
  subject(:policy) do
    described_class.new(
      aamva_verified_attributes:,
      address_edited:,
    )
  end

  let(:aamva_verified_attributes) { %i[address dob] }
  let(:address_edited) { false }

  describe '.from_applicant_pii' do
    subject(:policy) { described_class.from_applicant_pii(applicant_pii) }

    context 'when the applicant has AAMVA results' do
      let(:applicant_pii) do
        {
          aamva_verified_attributes: %i[address dob],
          address_edited: true,
        }.with_indifferent_access
      end

      it 'uses the applicant values to determine usable attributes' do
        expect(policy.usable_verified_attributes).to eq([:dob])
      end
    end

    context 'when the applicant has no AAMVA results' do
      let(:applicant_pii) { {} }

      it 'builds a policy with no usable attributes' do
        expect(policy.usable_verified_attributes).to be_empty
      end
    end
  end

  describe '#covers?' do
    subject(:covers?) do
      policy.covers?(resolution_result:, proofing_vendor:)
    end

    let(:proofing_vendor) { :instant_verify_ddp }
    let(:get_to_yes_enabled_vendors) { ['instant_verify_ddp'] }
    let(:failed_result_can_pass_with_additional_verification) { true }
    let(:attributes_requiring_additional_verification) { [:address] }
    let(:resolution_result) do
      Proofing::Resolution::Result.new(
        success: false,
        failed_result_can_pass_with_additional_verification:
          failed_result_can_pass_with_additional_verification,
        attributes_requiring_additional_verification:
          attributes_requiring_additional_verification,
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:idv_aamva_get_to_yes_enabled_vendors)
        .and_return(get_to_yes_enabled_vendors)
    end

    it { is_expected.to be(true) }

    context 'when get-to-yes is not enabled for the proofing vendor' do
      let(:get_to_yes_enabled_vendors) { ['socure_kyc'] }

      it { is_expected.to be(false) }
    end

    context 'when the proofing vendor is unknown' do
      let(:proofing_vendor) { nil }

      it { is_expected.to be(false) }
    end

    context 'when the result cannot pass with additional verification' do
      let(:failed_result_can_pass_with_additional_verification) { false }

      it { is_expected.to be(false) }
    end

    context 'when the vendor uses the default additional-verification values' do
      let(:resolution_result) { Proofing::Resolution::Result.new(success: false) }

      it { is_expected.to be(false) }
    end

    context 'when AAMVA did not verify every failed attribute' do
      let(:attributes_requiring_additional_verification) { %i[address ssn] }

      it { is_expected.to be(false) }
    end

    context 'when the vendor reports an unknown failed attribute' do
      let(:attributes_requiring_additional_verification) { %i[address unknown] }

      it { is_expected.to be(false) }
    end

    context 'when AAMVA verified every failed attribute' do
      let(:aamva_verified_attributes) { %i[address ssn] }
      let(:attributes_requiring_additional_verification) { %i[address ssn] }

      it { is_expected.to be(true) }
    end

    context 'when AAMVA verified more attributes than the vendor failed' do
      let(:attributes_requiring_additional_verification) { [:dob] }

      it { is_expected.to be(true) }
    end

    context 'when the address was edited after AAMVA verification' do
      let(:address_edited) { true }

      it { is_expected.to be(false) }

      context 'when resolution failed on a different verified attribute' do
        let(:attributes_requiring_additional_verification) { [:dob] }

        it { is_expected.to be(true) }
      end
    end

    context 'when AAMVA verified no attributes' do
      let(:aamva_verified_attributes) { nil }

      it { is_expected.to be(false) }
    end

    context 'when the AAMVA attributes came from the in-person session as strings' do
      let(:aamva_verified_attributes) { %w[address dob] }

      it { is_expected.to be(true) }
    end
  end

  describe '#usable_verified_attributes' do
    subject(:usable_verified_attributes) { policy.usable_verified_attributes }

    it { is_expected.to eq(%i[address dob]) }

    context 'when AAMVA verified no attributes' do
      let(:aamva_verified_attributes) { nil }

      it { is_expected.to be_empty }
    end

    context 'when AAMVA verified attributes are strings from the in-person session' do
      let(:aamva_verified_attributes) { %w[address dob] }
      let(:expected_attributes) { %i[address dob] }

      it 'normalizes the attributes to symbols' do
        expect(usable_verified_attributes).to eq(expected_attributes)
      end
    end

    context 'when AAMVA verified attributes are a Set' do
      let(:aamva_verified_attributes) { Set[:address, :dob] }

      it 'returns the attributes as an array' do
        expect(usable_verified_attributes).to eq(%i[address dob])
      end
    end

    context 'when the address was edited after AAMVA verification' do
      let(:address_edited) { true }

      it 'excludes the verified document address' do
        expect(usable_verified_attributes).to eq([:dob])
      end

      context 'when the verified attributes are strings from the in-person session' do
        let(:aamva_verified_attributes) { %w[address dob] }

        it 'normalizes the attributes and excludes the address' do
          expect(usable_verified_attributes).to eq([:dob])
        end
      end

      context 'when AAMVA verified only the address' do
        let(:aamva_verified_attributes) { [:address] }

        it { is_expected.to be_empty }
      end

      it 'does not modify the source attributes' do
        expect { usable_verified_attributes }
          .not_to change { aamva_verified_attributes }
      end
    end
  end
end
