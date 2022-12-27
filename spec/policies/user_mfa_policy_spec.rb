require 'rails_helper'

describe MfaPolicy do
  let(:subject) { described_class.new(user) }

  context 'no mfa configurations' do
    let(:user) { create(:user) }

    it { expect(subject.two_factor_enabled?).to eq false }
    it { expect(subject.multiple_factors_enabled?).to eq false }
  end

  context 'one mfa configuration' do
    let(:user) { create(:user, :with_phone) }

    it { expect(subject.two_factor_enabled?).to eq true }
    it { expect(subject.multiple_factors_enabled?).to eq false }
  end

  context 'two mfa configuration' do
    let(:user) { create(:user, :with_phone, :with_piv_or_cac) }

    it { expect(subject.two_factor_enabled?).to eq true }
    it { expect(subject.multiple_factors_enabled?).to eq true }
  end

  describe '#unphishable?' do
    context 'with unphishable configuration' do
      let(:user) { create(:user, :with_piv_or_cac, :with_webauthn) }

      it { expect(subject.unphishable?).to eq true }
    end

    context 'with phishable configuration' do
      let(:user) { create(:user, :signed_up) }

      it { expect(subject.unphishable?).to eq false }
    end
  end

  describe '#multiple_non_restricted_factors_enabled?' do
    context 'with kantara phone restriction disabled' do
      context 'with single mfa method' do
        let(:user) { create(:user, :with_phone) }

        it { expect(subject.multiple_non_restricted_factors_enabled?).to eq false }
      end

      context 'with multiple mfa methods' do
        let(:user) { create(:user, :with_phone) }

        before do
          user.phone_configurations << build(:phone_configuration, delivery_preference: :sms)
        end

        it { expect(subject.multiple_non_restricted_factors_enabled?).to eq true }
      end
    end
  end
end
