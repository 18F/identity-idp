require 'rails_helper'

RSpec.describe MfaPolicy do
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
      let(:user) { create(:user, :fully_registered) }

      it { expect(subject.unphishable?).to eq false }
    end
  end
end
