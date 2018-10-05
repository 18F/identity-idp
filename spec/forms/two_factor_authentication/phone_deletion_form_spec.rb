require 'rails_helper'

describe TwoFactorAuthentication::PhoneDeletionForm do
  let(:form) { described_class.new(user, configuration) }

  describe '#submit' do
    let!(:result) { form.submit }
    let(:configuration) { user.phone_configurations.first }

    context 'with only a single mfa method' do
      let(:user) { create(:user, :signed_up) }

      it 'returns failure' do
        expect(result.success?).to eq false
      end

      it 'leaves the phone alone' do
        expect(user.phone_configurations.reload).to_not be_empty
      end
    end

    context 'with multiple mfa methods available' do
      let(:user) { create(:user, :signed_up, :with_piv_or_cac) }

      it 'returns success' do
        expect(result.success?).to eq true
      end

      it 'removes the phone' do
        expect(user.phone_configurations.reload).to be_empty
      end
    end

    context 'with no phone configuration' do
      let(:user) { create(:user, :signed_up, :with_piv_or_cac) }
      let(:configuration) { nil }

      it 'returns success' do
        expect(result.success?).to eq true
      end

      it 'leaves the phone alone' do
        expect(user.phone_configurations.reload).to_not be_empty
      end
    end
  end
end
