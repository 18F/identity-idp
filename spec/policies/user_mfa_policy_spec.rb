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
    context 'with multi mfa disabled returns true ' do
      before do
        allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return false
      end

      let(:user) { create(:user, :with_phone, :with_piv_or_cac) }

      it { expect(subject.multiple_non_restricted_factors_enabled?).to eq true }
    end
  end

  describe '#multiple_non_restricted_factors_enabled?' do
    context 'with multi mfa enabled returns false ' do
      before do
        allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return true
      end

      let(:user) { create(:user, :with_phone, :with_piv_or_cac) }

      it { expect(subject.multiple_non_restricted_factors_enabled?).to eq false }
    end
  end
end
