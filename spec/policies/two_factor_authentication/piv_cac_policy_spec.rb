require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PivCacPolicy do
  let(:subject) { described_class.new(user) }

  describe '#configured?' do
    context 'without a piv configured' do
      let(:user) { build(:user) }

      it { expect(subject.configured?).to be_falsey }
    end

    context 'with a piv configured' do
      let(:user) { build(:user, :with_piv_or_cac) }

      it { expect(subject.configured?).to be_truthy }
    end
  end

  describe '#enabled?' do
    context 'without a piv configured' do
      let(:user) { build(:user) }

      it { expect(subject.configured?).to be_falsey }
    end

    context 'with a piv configured' do
      let(:user) { build(:user, :with_piv_or_cac) }

      it { expect(subject.configured?).to be_truthy }
    end
  end
end
